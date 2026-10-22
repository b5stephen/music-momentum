//
//  SongSection.swift
//  MusicMomentum
//

import Foundation

/// The span from one marker to the next, or to the end of the song for the
/// last. Never stored: markers are points, and sections are derived from
/// them each time, so there's no second copy of a boundary to drift.
nonisolated struct SongSection<MarkerID: Hashable & Sendable>: Hashable, Sendable {
    struct Opening: Hashable, Sendable {
        let id: MarkerID
        /// Position among the song's markers in time order, from 0.
        let index: Int
        /// As stored: empty when the user didn't name it.
        let name: String
    }

    let start: TimeInterval
    let end: TimeInterval
    /// The marker the section starts at; `nil` for the stretch before the
    /// first marker.
    let opening: Opening?
    /// A song with no markers has one section, all of it.
    let isWholeSong: Bool

    var length: TimeInterval { end - start }

    func contains(_ time: TimeInterval) -> Bool {
        time >= start && time < end
    }

    /// For the block row, where an unnamed section has no label.
    var label: String? {
        guard let opening, !opening.name.isEmpty else { return nil }
        return opening.name
    }

    /// For the sheet and the loop caption, where everything needs a name.
    var displayName: String {
        guard let opening else { return isWholeSong ? "Whole song" : "Start" }
        return Self.markerName(opening.name, index: opening.index)
    }

    /// An unnamed marker is "Marker N", N counting markers in time order from 1.
    static func markerName(_ name: String, index: Int) -> String {
        name.isEmpty ? "Marker \(index + 1)" : name
    }

    /// Every marker opens exactly one section, even one sharing its time
    /// with another, so each stays reachable; times are clamped into the
    /// song. Equal times keep their input order.
    static func derive(
        from markers: [(id: MarkerID, time: TimeInterval, name: String)],
        duration: TimeInterval
    ) -> [SongSection] {
        let duration = max(0, duration)
        let sorted = markers.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
        let starts = sorted.map { min(max(0, $0.time), duration) }

        guard let first = starts.first else {
            return [SongSection(start: 0, end: duration, opening: nil, isWholeSong: true)]
        }
        var sections: [SongSection] = []
        if first > 0 {
            sections.append(SongSection(start: 0, end: first, opening: nil, isWholeSong: false))
        }
        for (index, marker) in sorted.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1] : duration
            sections.append(SongSection(
                start: starts[index],
                end: end,
                opening: Opening(id: marker.id, index: index, name: marker.name),
                isWholeSong: false
            ))
        }
        return sections
    }
}
