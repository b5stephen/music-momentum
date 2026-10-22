//
//  ABLoop.swift
//  MusicMomentum
//

import Foundation
import SwiftData

/// The A·B button and the loop's nudge controls, as times. Pure and free of
/// the player and the store, so where a loop lands can be tested.
nonisolated enum ABLoop {
    /// What the A·B button shows and what tapping it does.
    enum Phase: Equatable {
        case idle
        /// A was tapped with the playhead here, before pre-roll.
        case aSet(tapped: TimeInterval)
        case looping
    }

    /// One end of a loop.
    enum End: Equatable {
        case start
        case end
    }

    /// A loop closed by tapping B, and where it needs new markers.
    struct Closing: Equatable {
        var start: TimeInterval
        var end: TimeInterval
        /// Ends with no marker within the snap threshold. The song's own
        /// start and end need none: a section already runs from or to them.
        var newMarkers: [TimeInterval]
    }

    /// What a ◀ or ▶ moves an end by. Fine enough to land on a beat at slow
    /// speeds; holding the button repeats it.
    static let nudgeStep: TimeInterval = 0.1

    /// A pending A wins: setting a loop clears it, so the two never overlap.
    static func phase(pendingA: TimeInterval?, isLooping: Bool) -> Phase {
        if let pendingA { return .aSet(tapped: pendingA) }
        return isLooping ? .looping : .idle
    }

    /// Where A shows while it waits for B.
    static func start(tapped: TimeInterval) -> TimeInterval {
        MarkerPlacement.compensatedStart(tapped)
    }

    /// `a` and `b` are the playhead when each was tapped. The earlier one is
    /// the start whichever came first, so a seek back between the taps loops
    /// the stretch between them rather than doing nothing. Each end snaps to
    /// a marker within the threshold, or to the song's start or end. `nil`
    /// when the two snap onto each other: A stays set.
    static func close(
        a: TimeInterval,
        b: TimeInterval,
        duration: TimeInterval,
        markers: [TimeInterval]
    ) -> Closing? {
        let start = snap(MarkerPlacement.compensatedStart(min(a, b)), songEnd: 0, markers: markers)
        let end = snap(
            MarkerPlacement.compensatedEnd(max(a, b), duration: duration),
            songEnd: duration,
            markers: markers
        )
        // Any closer and the end would snap onto a marker just made for the start.
        guard end.time - start.time >= MarkerPlacement.snapThreshold else { return nil }
        return Closing(
            start: start.time,
            end: end.time,
            newMarkers: [start, end].filter(\.isNew).map(\.time)
        )
    }

    private static func snap(
        _ time: TimeInterval,
        songEnd: TimeInterval,
        markers: [TimeInterval]
    ) -> (time: TimeInterval, isNew: Bool) {
        if let index = MarkerPlacement.snapIndex(for: time, in: markers) {
            return (markers[index], false)
        }
        if abs(time - songEnd) < MarkerPlacement.snapThreshold {
            return (songEnd, false)
        }
        return (time, true)
    }

    /// Where a nudge would take `end` of the loop, kept inside the song and
    /// short of the loop's other end. `nil` when it can't move that way.
    /// An end on a marker moves the marker, which its neighbours may hold
    /// shorter still.
    static func nudged(
        _ end: End,
        of loop: ClosedRange<TimeInterval>,
        by offset: TimeInterval,
        duration: TimeInterval
    ) -> TimeInterval? {
        let gap = MarkerPlacement.minimumNudgedSection
        let (current, target) = switch end {
        case .start: (loop.lowerBound, min(max(loop.lowerBound + offset, 0), loop.upperBound - gap))
        case .end: (loop.upperBound, min(max(loop.upperBound + offset, loop.lowerBound + gap), duration))
        }
        let moved = offset < 0 ? target < current : target > current
        return moved ? target : nil
    }

    /// "Split here" on B: a marker of B's own, so nudging B no longer moves
    /// the next section's start. B on a marker or the song's end gets one a
    /// nudge short of it, leaving a gap section that nudging B back widens;
    /// a B between markers gets one right there. `nil` when the loop is too
    /// short to give up a nudge.
    static func splitTime(
        of loop: ClosedRange<TimeInterval>,
        markers: [TimeInterval],
        duration: TimeInterval
    ) -> TimeInterval? {
        let end = loop.upperBound
        let onBoundary = abs(end - duration) < MarkerPlacement.sameTime
            || markers.contains { abs($0 - end) < MarkerPlacement.sameTime }
        let time = onBoundary ? end - nudgeStep : end
        guard time - loop.lowerBound >= MarkerPlacement.minimumNudgedSection - MarkerPlacement.sameTime else { return nil }
        return time
    }
}

// MARK: - Applied to a song's markers

/// The store side of the flow: what the controller does with the times
/// above. Kept off the controller, which needs a music player, so it can be
/// tested.
@MainActor
extension ABLoop {
    /// Closes the loop and adds the markers it needs. `song` is `nil` for a
    /// song that couldn't be saved, which still loops but gets no markers.
    static func close(
        a: TimeInterval,
        b: TimeInterval,
        duration: TimeInterval,
        song: SavedSong?,
        in context: ModelContext?
    ) -> (loop: ClosedRange<TimeInterval>, created: [SongMarker])? {
        guard let closing = close(
            a: a, b: b, duration: duration,
            markers: song?.sortedMarkers.map(\.startTime) ?? []
        ) else { return nil }
        var created: [SongMarker] = []
        if let song, let context {
            for time in closing.newMarkers {
                let added = SongMarker.addSnapping(to: song, at: time, in: context)
                if added.created { created.append(added.marker) }
            }
        }
        return (closing.start...closing.end, created)
    }

    /// Moves the marker at that end of the loop, so the neighbouring section
    /// moves with it, and returns the loop with that end where the marker
    /// landed. An end with no marker (the song's start or end) moves alone.
    /// `nil` when it can't move.
    static func nudge(
        _ end: End,
        of loop: ClosedRange<TimeInterval>,
        by offset: TimeInterval,
        duration: TimeInterval,
        song: SavedSong?,
        in context: ModelContext?
    ) -> ClosedRange<TimeInterval>? {
        guard let target = nudged(end, of: loop, by: offset, duration: duration) else { return nil }
        let current = end == .start ? loop.lowerBound : loop.upperBound
        var moved = target
        if let song, let context,
           let marker = song.sortedMarkers.first(where: { abs($0.startTime - current) < MarkerPlacement.sameTime }) {
            marker.nudge(by: target - current, in: context)
            moved = marker.startTime
        }
        return switch end {
        case .start: moved...loop.upperBound
        case .end: loop.lowerBound...moved
        }
    }

    /// "Split here": B's own marker, and the loop ending on it. `created` is
    /// `nil` when a marker was already there.
    static func split(
        _ loop: ClosedRange<TimeInterval>,
        duration: TimeInterval,
        song: SavedSong,
        in context: ModelContext
    ) -> (loop: ClosedRange<TimeInterval>, created: SongMarker?)? {
        let before = song.sortedMarkers
        guard let time = splitTime(of: loop, markers: before.map(\.startTime), duration: duration) else { return nil }
        let marker = SongMarker.split(song, at: time, in: context)
        let isNew = !before.contains { $0 === marker }
        return (loop.lowerBound...marker.startTime, isNew ? marker : nil)
    }
}
