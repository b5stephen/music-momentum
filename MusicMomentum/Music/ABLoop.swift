//
//  ABLoop.swift
//  MusicMomentum
//

import Foundation

/// A loop caught on the beat with A·B: A pressed, then B. Nothing is saved
/// until Save Loop makes it a `SongMarker`, so it lives only as long as the
/// song is loaded.
nonisolated enum ABLoop: Equatable {
    /// A is set; B is still to come.
    case started(TimeInterval)
    /// Both ends set. Looping while `PlaybackController.loop` is `.scratch`
    /// of it; otherwise kept as a ghost the Loop button can bring back.
    case closed(Range<TimeInterval>)

    var range: Range<TimeInterval>? {
        if case .closed(let range) = self { return range }
        return nil
    }

    /// B before A (the playhead was sent back past A) loops between the two
    /// all the same, and a B pressed hard on A's heels still gets a loop the
    /// player can play.
    static func close(from a: TimeInterval, to b: TimeInterval, duration: TimeInterval) -> Range<TimeInterval> {
        let shortest = SongMarker.minimumClipLength
        var lower = max(0, min(a, b))
        var upper = min(duration, max(a, b))
        if upper - lower < shortest {
            upper = min(duration, lower + shortest)
            lower = max(0, upper - shortest)
        }
        return lower..<upper
    }
}
