//
//  SongMarker.swift
//  MusicMomentum
//

import Foundation
import SwiftData

/// A point in a saved song. Sections run from one marker to the next and
/// are derived, never stored; see `SongSection`.
@Model
final class SongMarker {
    /// Empty when the user didn't name it; shown as "Marker N".
    var name: String = ""
    /// The marker's time. Named for when markers had an end too; renaming it
    /// would rename the CloudKit field installed builds still sync.
    var startTime: TimeInterval = 0
    /// Clips' ends, from before markers were points. Kept only so the
    /// CloudKit field survives: `ClipMigration` turns each into a marker of
    /// its own and clears it, and nothing sets it again.
    var endTime: TimeInterval?
    var createdAt: Date = Date.now
    var song: SavedSong?

    init(name: String, startTime: TimeInterval, song: SavedSong? = nil) {
        self.name = name
        self.startTime = startTime
        self.song = song
    }

    var timeLabel: String {
        PlaybackScrubber.timeLabel(startTime)
    }

    /// The next marker in time order, whose section follows this one's.
    var next: SongMarker? {
        guard let markers = song?.sortedMarkers,
              let index = markers.firstIndex(where: { $0 === self }),
              index + 1 < markers.count
        else { return nil }
        return markers[index + 1]
    }

    private var previous: SongMarker? {
        guard let markers = song?.sortedMarkers,
              let index = markers.firstIndex(where: { $0 === self }),
              index > 0
        else { return nil }
        return markers[index - 1]
    }
}

// MARK: - Storage

extension SongMarker {
    /// What a delete took away, enough to put the marker back for Undo.
    struct Removed: Equatable {
        let name: String
        let time: TimeInterval
    }

    @discardableResult
    static func add(
        to song: SavedSong,
        name: String = "",
        at time: TimeInterval,
        in context: ModelContext
    ) -> SongMarker {
        let marker = SongMarker(name: "", startTime: 0, song: song)
        context.insert(marker)
        marker.apply(name: name, time: time)
        try? context.save()
        return marker
    }

    /// Reuses a marker within `MarkerPlacement.snapThreshold` rather than
    /// leaving a sliver of a section beside it; a reused marker keeps its own
    /// name. `created` says which happened, so only a new marker is offered a
    /// name.
    @discardableResult
    static func addSnapping(
        to song: SavedSong,
        name: String = "",
        at time: TimeInterval,
        in context: ModelContext
    ) -> (marker: SongMarker, created: Bool) {
        let markers = song.sortedMarkers
        if let index = MarkerPlacement.snapIndex(for: max(0, time), in: markers.map(\.startTime)) {
            return (markers[index], false)
        }
        return (add(to: song, name: name, at: time, in: context), true)
    }

    /// "Split here": adds a marker rather than moving the boundary, leaving a
    /// new section between the two. Deliberately doesn't snap, since the user
    /// asked for a boundary of their own; only a marker at the very same
    /// time is reused.
    @discardableResult
    static func split(
        _ song: SavedSong,
        at time: TimeInterval,
        name: String = "",
        in context: ModelContext
    ) -> SongMarker {
        let time = max(0, time)
        if let existing = song.sortedMarkers.first(where: { abs($0.startTime - time) < MarkerPlacement.sameTime }) {
            return existing
        }
        return add(to: song, name: name, at: time, in: context)
    }

    /// Free to move past its neighbours, unlike `nudge`: setting a marker to
    /// the playhead is a fresh placement.
    func set(name: String, time: TimeInterval, in context: ModelContext) {
        apply(name: name, time: time)
        try? context.save()
    }

    /// Moves the marker, so both sections it bounds move with it: nudging
    /// the end of Chorus moves the start of Verse 2. Held short of its
    /// neighbours so a nudge never reorders sections.
    func nudge(by offset: TimeInterval, in context: ModelContext) {
        let lower = (previous?.startTime).map { $0 + MarkerPlacement.minimumNudgedSection } ?? 0
        let upper = (next?.startTime).map { $0 - MarkerPlacement.minimumNudgedSection } ?? .infinity
        guard lower <= upper else { return }
        let target = min(max(startTime + offset, lower), upper)
        // Already closer to a neighbour than the gap: clamping must not push
        // it the opposite way to the nudge.
        guard offset < 0 ? target < startTime : target > startTime else { return }
        apply(name: name, time: target)
        try? context.save()
    }

    /// The section merges into the previous one.
    @discardableResult
    static func delete(_ marker: SongMarker, in context: ModelContext) -> Removed {
        let removed = Removed(name: marker.name, time: marker.startTime)
        marker.song?.lastPracticed = .now
        context.delete(marker)
        try? context.save()
        return removed
    }

    /// Undo for `delete`.
    @discardableResult
    static func restore(_ removed: Removed, to song: SavedSong, in context: ModelContext) -> SongMarker {
        add(to: song, name: removed.name, at: removed.time, in: context)
    }

    /// Deletes the next marker, so the following section joins this one.
    /// `nil` when this is the last.
    @discardableResult
    static func mergeWithNext(_ marker: SongMarker, in context: ModelContext) -> Removed? {
        guard let next = marker.next else { return nil }
        return delete(next, in: context)
    }

    private func apply(name: String, time: TimeInterval) {
        song?.lastPracticed = .now
        startTime = max(0, time)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
