//
//  Loop.swift
//  MusicMomentum
//

import Foundation

/// What's looping: the whole song, or one A→B range. Plain times, not
/// markers, so the loop belongs to the player: deleting a marker leaves a
/// running loop where it was. Moving a marker the loop ends on carries the
/// loop with it; see `ABLoop.following`.
nonisolated enum Loop: Hashable, Sendable {
    case wholeSong
    case range(start: TimeInterval, end: TimeInterval)

    func matches(start: TimeInterval, end: TimeInterval) -> Bool {
        guard case .range(let loopStart, let loopEnd) = self else { return false }
        return abs(loopStart - start) < MarkerPlacement.sameTime && abs(loopEnd - end) < MarkerPlacement.sameTime
    }
}

nonisolated extension Loop {
    /// Pure and free of the player, so the wrap-around rules can be tested.
    enum Step: Equatable {
        case inside
        case jump(to: TimeInterval)
        /// Outside the range without having just played out of it (the user
        /// jumped or scrubbed away); leave the playhead be until playback
        /// runs back into the range.
        case wait
    }

    /// `wasInside` is whether the last reading was in the range; the
    /// controller clears it on a user seek.
    static func step(start: TimeInterval, end: TimeInterval, time: TimeInterval, wasInside: Bool) -> Step {
        guard end > start else { return .wait }
        if time >= start && time < end { return .inside }
        guard wasInside, time >= end else { return .wait }
        return .jump(to: start)
    }
}
