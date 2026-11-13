//
//  SectionSpan.swift
//  MusicMomentum
//

import Foundation

nonisolated enum SectionSpan {
    static func end(
        after start: TimeInterval,
        among points: [(name: String, start: TimeInterval)],
        duration: TimeInterval
    ) -> (name: String?, time: TimeInterval) {
        guard let next = points.filter({ $0.start > start }).min(by: { $0.start < $1.start }) else {
            return (nil, duration)
        }
        return (next.name, next.start)
    }

    static func name(containing time: TimeInterval, among points: [(name: String, start: TimeInterval)]) -> String? {
        points.filter { $0.start <= time }.max(by: { $0.start < $1.start })?.name
    }

    /// Where a loop made from the point at `start` ends: its section's end,
    /// stretched to the shortest loop when the next point is too close. `nil`
    /// when there's no room for a loop before the song ends.
    static func loopEnd(
        from start: TimeInterval,
        among points: [(name: String, start: TimeInterval)],
        duration: TimeInterval
    ) -> TimeInterval? {
        let shortest = start + SongMarker.minimumClipLength
        guard shortest <= duration else { return nil }
        return max(end(after: start, among: points, duration: duration).time, shortest)
    }
}
