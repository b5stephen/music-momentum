//
//  ClipMigration.swift
//  MusicMomentum
//

import Foundation
import SwiftData

/// Turns clips, from when markers could have an end, into pairs of points.
///
/// Runs on every launch and after every sync, on every device, because a
/// clip can still arrive from a device on an older build. So it has to be
/// idempotent, and two devices migrating the same clip offline each add an
/// end marker at exactly the clip's end; `collapseCopies` folds those back
/// into one once they meet.
enum ClipMigration {
    static func run(in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<SongMarker>()) else { return }
        var changed = false
        let clips = all.filter { $0.endTime != nil }.sorted { $0.startTime < $1.startTime }
        for clip in clips {
            guard let end = clip.endTime else { continue }
            clip.endTime = nil
            changed = true
            guard let song = clip.song, end > clip.startTime else { continue }
            // The clip's own start is no place for its end to snap to.
            let others = (song.markers ?? []).filter { $0 !== clip }.map(\.startTime)
            guard MarkerPlacement.snapIndex(for: end, in: others) == nil else { continue }
            // Not through `SongMarker.add`: a repair isn't the user's edit, and
            // touching `lastPracticed` on every device would reshuffle their lists.
            context.insert(SongMarker(name: "", startTime: end, song: song))
        }
        if collapseCopies(in: context) { changed = true }
        if changed { try? context.save() }
    }

    /// Of markers sharing a time, an unnamed one adds nothing (it opens a
    /// section with no length), so it goes. The one kept is chosen from synced
    /// fields alone, a named marker first and then the oldest, so two devices
    /// collapsing at once delete the same copy rather than one each. Named
    /// markers are never deleted here.
    @discardableResult
    static func collapseCopies(in context: ModelContext) -> Bool {
        guard let songs = try? context.fetch(FetchDescriptor<SavedSong>()) else { return false }
        var changed = false
        for song in songs {
            var group: [SongMarker] = []
            for marker in song.sortedMarkers + [nil] as [SongMarker?] {
                if let marker, let first = group.first,
                   marker.startTime - first.startTime < MarkerPlacement.sameTime {
                    group.append(marker)
                    continue
                }
                if group.count > 1 {
                    let keeper = group.filter { !$0.name.isEmpty }.min { $0.createdAt < $1.createdAt }
                        ?? group.min { $0.createdAt < $1.createdAt }
                    for copy in group where copy !== keeper && copy.name.isEmpty {
                        context.delete(copy)
                        changed = true
                    }
                }
                group = marker.map { [$0] } ?? []
            }
        }
        return changed
    }
}
