//
//  MarkerLaneDrag.swift
//  MusicMomentum
//

import CoreGraphics
import Foundation

/// The arithmetic behind dragging in the Mac lane: where a drag lands in song
/// time, what it snaps to, and how far an edge may be trimmed. Pure, so a
/// marker can't be misplaced by something a test could have caught.
nonisolated enum MarkerLaneDrag {
    enum Edge: Hashable {
        case start, end
    }

    /// How close, in points, an edge has to be to a marker to snap to it.
    static let snapTolerance: CGFloat = 6
    /// A drag shorter than this, in points, is a click.
    static let minimumDragWidth: CGFloat = 4

    /// Whole seconds, or tenths with ⌥.
    static func rounded(_ time: TimeInterval, fine: Bool) -> TimeInterval {
        fine ? (time * 10).rounded() / 10 : time.rounded()
    }

    /// The nearest of `points` within `tolerance` points of `time` at this
    /// scale, if any.
    static func snapped(
        _ time: TimeInterval,
        to points: [TimeInterval],
        pointsPerSecond: CGFloat,
        tolerance: CGFloat = snapTolerance
    ) -> TimeInterval? {
        guard pointsPerSecond > 0 else { return nil }
        let nearest = points.min { abs($0 - time) < abs($1 - time) }
        guard let nearest, abs(nearest - time) * pointsPerSecond <= tolerance else { return nil }
        return nearest
    }

    /// The song time under `x`: a nearby point if there is one, otherwise
    /// rounded; always inside the song.
    static func time(
        atX x: CGFloat,
        width: CGFloat,
        duration: TimeInterval,
        fine: Bool,
        snapTo points: [TimeInterval]
    ) -> TimeInterval {
        let raw = PlaybackScrubber.time(atX: x, width: width, duration: duration)
        guard width > 0, duration > 0 else { return raw }
        let target = snapped(raw, to: points, pointsPerSecond: width / duration)
            ?? rounded(raw, fine: fine)
        return min(max(target, 0), duration)
    }

    /// The clip a drag from `startX` to `endX` marks, whichever way it went.
    /// `nil` when it is too short to be anything but a click.
    static func clip(
        from startX: CGFloat,
        to endX: CGFloat,
        width: CGFloat,
        duration: TimeInterval,
        fine: Bool,
        snapTo points: [TimeInterval]
    ) -> (start: TimeInterval, end: TimeInterval)? {
        guard abs(endX - startX) >= minimumDragWidth else { return nil }
        let a = time(atX: min(startX, endX), width: width, duration: duration, fine: fine, snapTo: points)
        let b = time(atX: max(startX, endX), width: width, duration: duration, fine: fine, snapTo: points)
        guard b - a >= SongMarker.minimumClipLength else { return nil }
        return (a, b)
    }

    /// Moves one edge to `time`, held inside the song and short of the other
    /// edge by the shortest clip the player can loop.
    static func trim(
        _ edge: Edge,
        to time: TimeInterval,
        start: TimeInterval,
        end: TimeInterval,
        duration: TimeInterval
    ) -> (start: TimeInterval, end: TimeInterval) {
        let gap = SongMarker.minimumClipLength
        switch edge {
        case .start: return (min(max(time, 0), max(0, end - gap)), end)
        case .end: return (start, max(min(time, duration), min(start + gap, duration)))
        }
    }

    // MARK: Readouts

    /// "1:40 \u{2013} 2:04 \u{00B7} 0:24"; tenths only when something isn't whole.
    static func clipReadout(start: TimeInterval, end: TimeInterval) -> String {
        let length = end - start
        if [start, end].allSatisfy(isWhole) {
            return "\(PlaybackScrubber.timeLabel(start)) \u{2013} \(PlaybackScrubber.timeLabel(end)) \u{00B7} \(PlaybackScrubber.timeLabel(length))"
        }
        return "\(PreciseTime.format(start)) \u{2013} \(PreciseTime.format(end)) \u{00B7} \(PreciseTime.format(length))"
    }

    /// "Start 2:20.0 \u{00B7} 0:40": the edge in tenths, the clip's length.
    static func trimReadout(_ edge: Edge, start: TimeInterval, end: TimeInterval) -> String {
        let length = end - start
        let label = edge == .start ? "Start" : "End"
        let edgeTime = PreciseTime.format(edge == .start ? start : end)
        let lengthText = isWhole(length) ? PlaybackScrubber.timeLabel(length.rounded()) : PreciseTime.format(length)
        return "\(label) \(edgeTime) \u{00B7} \(lengthText)"
    }

    private static func isWhole(_ time: TimeInterval) -> Bool {
        abs(time - time.rounded()) < 0.05
    }
}
