//
//  TimelineViewport.swift
//  MusicMomentum
//

import CoreGraphics
import Foundation

/// Which slice of the song the Mac timeline shows: a zoom and where the view
/// starts. Pure, so the clamping at the song's ends, the paging and the fit
/// to a loop can be tested without a view. Every operation takes the song's
/// duration and leaves the view inside `0...duration`, so a stale value from
/// the previous song can never show past the end.
nonisolated struct TimelineViewport: Equatable {
    enum Edge {
        case leading, trailing
    }

    /// 1 is the whole song.
    private(set) var zoom: Double = 1
    private(set) var start: TimeInterval = 0

    /// Zooming in stops when this much of the song is left in view.
    static let minimumVisibleSeconds: TimeInterval = 8
    /// How far in from the leading edge paging puts the playhead, as a share
    /// of the view.
    static let leadIn = 0.1
    /// Room left around a loop that is brought into view, as a share of its
    /// length, and at least `minimumMargin`.
    static let loopMargin = 0.1
    static let minimumMargin: TimeInterval = 0.5
    /// What the buttons and keys multiply the zoom by.
    static let step = 2.0
    /// More hidden names than this, in the whole-song view, and zoom is worth offering.
    static let hiddenNameLimit = 3

    var isZoomed: Bool { zoom > 1.0001 }

    func maxZoom(duration: TimeInterval) -> Double {
        guard duration > 0 else { return 1 }
        return max(1, duration / min(Self.minimumVisibleSeconds, duration))
    }

    func canZoomIn(duration: TimeInterval) -> Bool { zoom < maxZoom(duration: duration) - 0.0001 }

    func span(duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return 0 }
        return duration / min(max(zoom, 1), maxZoom(duration: duration))
    }

    /// Always inside `0...duration`.
    func visible(duration: TimeInterval) -> ClosedRange<TimeInterval> {
        guard duration > 0 else { return 0...0 }
        let span = span(duration: duration)
        let lower = min(max(start, 0), duration - span)
        return lower...(lower + span)
    }

    // MARK: Zoom and pan

    /// Zooms by `factor`, keeping `time` where it is on screen. A `time`
    /// outside the view is held to its nearest edge.
    mutating func zoom(by factor: Double, around time: TimeInterval, duration: TimeInterval) {
        guard duration > 0, factor.isFinite, factor > 0 else { return }
        let current = visible(duration: duration)
        let span = current.upperBound - current.lowerBound
        let fraction = min(max((time - current.lowerBound) / span, 0), 1)
        let newZoom = min(max(zoom * factor, 1), maxZoom(duration: duration))
        guard newZoom > 1.0001 else {
            fit()
            return
        }
        let newSpan = duration / newZoom
        zoom = newZoom
        start = min(max(time - fraction * newSpan, 0), duration - newSpan)
    }

    mutating func pan(by seconds: TimeInterval, duration: TimeInterval) {
        guard isZoomed, duration > 0 else { return }
        move(to: visible(duration: duration).lowerBound + seconds, duration: duration)
    }

    /// The view starting at `start`, held inside the song.
    mutating func move(to start: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else { return }
        self.start = min(max(start, 0), duration - span(duration: duration))
    }

    mutating func center(on time: TimeInterval, duration: TimeInterval) {
        move(to: time - span(duration: duration) / 2, duration: duration)
    }

    mutating func fit() {
        self = TimelineViewport()
    }

    /// Drags one edge of the view to `time`, the other staying put and the
    /// view keeping its minimum length.
    mutating func resize(_ edge: Edge, to time: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else { return }
        let current = visible(duration: duration)
        let minimum = min(Self.minimumVisibleSeconds, duration)
        let range: ClosedRange<TimeInterval>
        switch edge {
        case .leading:
            range = min(max(time, 0), current.upperBound - minimum)...current.upperBound
        case .trailing:
            range = current.lowerBound...min(max(time, current.lowerBound + minimum), duration)
        }
        show(range, duration: duration)
    }

    /// Zooms and pans to exactly `range`, within the limits.
    mutating func show(_ range: ClosedRange<TimeInterval>, duration: TimeInterval) {
        guard duration > 0 else { return }
        let length = max(range.upperBound - range.lowerBound, min(Self.minimumVisibleSeconds, duration))
        let newZoom = min(max(duration / length, 1), maxZoom(duration: duration))
        guard newZoom > 1.0001 else {
            fit()
            return
        }
        zoom = newZoom
        move(to: range.lowerBound, duration: duration)
    }

    // MARK: Following the playhead

    /// Pages when the playhead has just left the view: the view jumps so the
    /// playhead sits near its leading edge, once, rather than scrolling along.
    /// A playhead that was already out of view (the user has panned away to
    /// look at something) is left alone.
    mutating func follow(playhead: TimeInterval, previous: TimeInterval, duration: TimeInterval) {
        guard isZoomed, duration > 0 else { return }
        let current = visible(duration: duration)
        guard !current.contains(playhead), current.contains(previous) else { return }
        move(to: playhead - Self.leadIn * (current.upperBound - current.lowerBound), duration: duration)
    }

    /// Brings a loop into view with a margin when it isn't all there: panning
    /// if the view is wide enough to hold it, zooming out if not. A loop
    /// already in view, or a view of the whole song, is left alone.
    mutating func reveal(_ loop: ClosedRange<TimeInterval>, duration: TimeInterval) {
        guard isZoomed, duration > 0 else { return }
        let current = visible(duration: duration)
        guard !(current.contains(loop.lowerBound) && current.contains(loop.upperBound)) else { return }
        let length = loop.upperBound - loop.lowerBound
        let margin = max(length * Self.loopMargin, Self.minimumMargin)
        let needed = length + 2 * margin
        if needed >= duration {
            fit()
        } else if current.upperBound - current.lowerBound >= needed {
            center(on: (loop.lowerBound + loop.upperBound) / 2, duration: duration)
        } else {
            show((loop.lowerBound - margin)...(loop.upperBound + margin), duration: duration)
        }
    }

    // MARK: Whether to offer it

    /// Zoom is offered when the whole-song lane hides more than a few names or
    /// needs three clip rows, and stays offered once zoomed, or the controls
    /// would vanish under the user's hand.
    func isNeeded(wholeSong layout: MarkerLaneLayout) -> Bool {
        isZoomed
            || layout.hiddenNameCount > Self.hiddenNameLimit
            || layout.rowCount >= MarkerLaneLayout.maxRows
    }

    // MARK: Mapping

    /// The song time under `x` on a track `width` wide showing `range`,
    /// clamped to it.
    static func time(atX x: CGFloat, width: CGFloat, in range: ClosedRange<TimeInterval>) -> TimeInterval {
        guard width > 0 else { return range.lowerBound }
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + span * Double(min(max(x / width, 0), 1))
    }

    /// Where `time` falls across `width`; outside the range it falls outside 0...width.
    static func x(for time: TimeInterval, width: CGFloat, in range: ClosedRange<TimeInterval>) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return width * CGFloat((time - range.lowerBound) / span)
    }
}
