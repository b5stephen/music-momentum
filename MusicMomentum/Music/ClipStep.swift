//
//  ClipStep.swift
//  MusicMomentum
//

import Foundation

/// Which clip the mini player's previous and next buttons go to, away from the
/// views so the edges (first, last, mid-clip) can be tested.
nonisolated enum ClipStep {
    enum Direction {
        case previous, next
    }

    /// Past this far into a clip, "previous" goes to the clip's own start
    /// rather than the one before, as a player's previous-track does.
    static let grace: TimeInterval = 1

    private static let tolerance: TimeInterval = 0.001

    /// The index in `starts` (the song's clips in start order) to go to, or
    /// `nil` when there is no clip that way.
    ///
    /// With a clip loop running, the loop's clip is where "here" is, so
    /// stepping from a lone looping clip moves to its neighbour instead of
    /// to itself: the playhead's clip in a chain, else the last one it has
    /// passed. Otherwise "here" is the playhead.
    static func target(
        starts: [TimeInterval],
        loop: [Range<TimeInterval>],
        playhead: TimeInterval,
        direction: Direction
    ) -> Int? {
        let (anchor, grace) = here(loop: loop, playhead: playhead)
        switch direction {
        case .previous:
            return starts.lastIndex { $0 < anchor - grace - tolerance }
        case .next:
            return starts.firstIndex { $0 > anchor + tolerance }
        }
    }

    private static func here(loop: [Range<TimeInterval>], playhead: TimeInterval) -> (anchor: TimeInterval, grace: TimeInterval) {
        guard let first = loop.first else { return (playhead, grace) }
        let current = loop.first { $0.contains(playhead) } ?? loop.last { $0.lowerBound <= playhead } ?? first
        return (current.lowerBound, 0)
    }
}
