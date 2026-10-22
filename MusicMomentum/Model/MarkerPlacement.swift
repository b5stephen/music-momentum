//
//  MarkerPlacement.swift
//  MusicMomentum
//

import Foundation

/// Where a tap puts a marker. The values are guesses to tune on a device
/// with real songs, and may become settings.
nonisolated enum MarkerPlacement {
    /// A boundary landing this close to an existing marker reuses it rather
    /// than leaving a sliver of a section.
    static let snapThreshold: TimeInterval = 0.5
    /// Taps land late: A and new markers go this much earlier than the tap...
    static let startPreRoll: TimeInterval = 0.3
    /// ...and B this much later, so the loop doesn't clip the last note.
    static let endPostRoll: TimeInterval = 0.3
    /// Markers closer than this are at the same time, for splitting and for
    /// collapsing copies made by two devices.
    static let sameTime: TimeInterval = 0.001
    /// How close a nudge may bring a marker to its neighbour.
    static let minimumNudgedSection: TimeInterval = 0.1

    static func compensatedStart(_ tapped: TimeInterval) -> TimeInterval {
        max(0, tapped - startPreRoll)
    }

    static func compensatedEnd(_ tapped: TimeInterval, duration: TimeInterval) -> TimeInterval {
        min(duration, tapped + endPostRoll)
    }

    /// The index of the nearest time strictly within `threshold` of `time`.
    static func snapIndex(
        for time: TimeInterval,
        in times: [TimeInterval],
        threshold: TimeInterval = snapThreshold
    ) -> Int? {
        times.indices
            .filter { abs(times[$0] - time) < threshold }
            .min { abs(times[$0] - time) < abs(times[$1] - time) }
    }
}
