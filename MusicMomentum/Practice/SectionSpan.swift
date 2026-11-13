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
}
