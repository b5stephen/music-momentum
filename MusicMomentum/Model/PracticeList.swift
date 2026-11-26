//
//  PracticeList.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import Foundation
import SwiftData

/// A user-created list that organizes saved songs as folders, setlists, or
/// filter tags.
///
/// Membership lives on `PracticeListEntry` rather than an implicit many-to-many
/// array so custom per-list song order (`position`) is supported without a
/// future CloudKit schema migration.
@Model
final class PracticeList {
    var listID: String = UUID().uuidString
    var name: String = ""
    var sortOrder: Double = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// Optional because CloudKit requires every relationship to be.
    @Relationship(deleteRule: .cascade, inverse: \PracticeListEntry.list)
    var entries: [PracticeListEntry]? = []

    init(
        listID: String = UUID().uuidString,
        name: String,
        sortOrder: Double = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.listID = listID
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// CloudKit can sync an entry before its song or list arrives, so callers
    /// only read completed links.
    var validEntries: [PracticeListEntry] {
        (entries ?? []).filter { $0.song != nil && $0.list != nil }
    }

    var sortedEntries: [PracticeListEntry] {
        validEntries.sorted {
            ($0.position, $0.addedAt) < ($1.position, $1.addedAt)
        }
    }

    var songs: [SavedSong] {
        var seen = Set<PersistentIdentifier>()
        var result: [SavedSong] = []
        for entry in sortedEntries {
            guard let song = entry.song, seen.insert(song.persistentModelID).inserted else { continue }
            result.append(song)
        }
        return result
    }

    var songCount: Int {
        Set(validEntries.compactMap { $0.song?.persistentModelID }).count
    }
}

// MARK: - Storage

extension PracticeList {
    static func all(in context: ModelContext) -> [PracticeList] {
        let descriptor = FetchDescriptor<PracticeList>(sortBy: [
            SortDescriptor(\.sortOrder),
            SortDescriptor(\.createdAt),
            SortDescriptor(\.name),
        ])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    static func create(name: String, in context: ModelContext) -> PracticeList {
        let existing = all(in: context)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? defaultName(existingCount: existing.count) : trimmed
        let nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
        let list = PracticeList(name: resolvedName, sortOrder: nextOrder)
        context.insert(list)
        try? context.save()
        return list
    }

    static func rename(_ list: PracticeList, to name: String, in context: ModelContext) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != list.name else { return }
        list.name = trimmed
        list.updatedAt = .now
        try? context.save()
    }

    static func reorder(_ orderedLists: [PracticeList], in context: ModelContext) {
        var changed = false
        for (index, list) in orderedLists.enumerated() {
            let newOrder = Double(index + 1)
            if list.sortOrder != newOrder {
                list.sortOrder = newOrder
                list.updatedAt = .now
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Deletes only the list and its membership entries, leaving `SavedSong` intact.
    static func delete(_ list: PracticeList, in context: ModelContext) {
        context.delete(list)
        try? context.save()
    }

    static func add(_ songs: [SavedSong], to list: PracticeList, in context: ModelContext) {
        guard !songs.isEmpty else { return }
        let existingIDs = Set(list.validEntries.compactMap { $0.song?.persistentModelID })
        var nextPosition = (list.validEntries.map(\.position).max() ?? 0) + 1
        var changed = false

        for song in songs where !existingIDs.contains(song.persistentModelID) {
            let entry = PracticeListEntry(position: nextPosition, list: list, song: song)
            context.insert(entry)
            nextPosition += 1
            changed = true
        }

        if changed {
            list.updatedAt = .now
            try? context.save()
        }
    }

    static func remove(_ songs: [SavedSong], from list: PracticeList, in context: ModelContext) {
        guard !songs.isEmpty else { return }
        let songIDs = Set(songs.map(\.persistentModelID))
        var changed = false

        for entry in list.entries ?? [] {
            guard let song = entry.song, songIDs.contains(song.persistentModelID) else { continue }
            context.delete(entry)
            changed = true
        }

        if changed {
            list.updatedAt = .now
            try? context.save()
        }
    }

    static func setLists(_ targetLists: [PracticeList], for song: SavedSong, in context: ModelContext) {
        let targetIDs = Set(targetLists.map(\.persistentModelID))
        var existingIDs = Set<PersistentIdentifier>()
        var changed = false

        for entry in song.listEntries ?? [] {
            guard let list = entry.list else { continue }
            if targetIDs.contains(list.persistentModelID) {
                existingIDs.insert(list.persistentModelID)
            } else {
                list.updatedAt = .now
                context.delete(entry)
                changed = true
            }
        }

        for list in targetLists where !existingIDs.contains(list.persistentModelID) {
            let nextPosition = (list.validEntries.map(\.position).max() ?? 0) + 1
            let entry = PracticeListEntry(position: nextPosition, list: list, song: song)
            context.insert(entry)
            list.updatedAt = .now
            changed = true
        }

        if changed { try? context.save() }
    }

    /// Collapses duplicate membership entries created if two devices added the
    /// same song to the same list while offline.
    static func deduplicateEntries(in context: ModelContext) {
        mergeDuplicateLists(in: context)
        guard let entries = try? context.fetch(FetchDescriptor<PracticeListEntry>()) else { return }

        struct Key: Hashable {
            let list: PersistentIdentifier
            let song: PersistentIdentifier
        }

        let valid = entries.filter { $0.list != nil && $0.song != nil }
        let groups = Dictionary(grouping: valid) { entry in
            Key(list: entry.list!.persistentModelID, song: entry.song!.persistentModelID)
        }.values.filter { $0.count > 1 }

        guard !groups.isEmpty else { return }
        for group in groups {
            let ordered = group.sorted { ($0.position, $0.addedAt) < ($1.position, $1.addedAt) }
            for duplicate in ordered.dropFirst() {
                context.delete(duplicate)
            }
        }
        try? context.save()
    }

    private static func mergeDuplicateLists(in context: ModelContext) {
        let lists = all(in: context)
        let groups = Dictionary(grouping: lists, by: \.listID).values.filter { $0.count > 1 }
        guard !groups.isEmpty else { return }

        for group in groups {
            let ordered = group.sorted {
                ($0.updatedAt, $0.createdAt, $0.name) > ($1.updatedAt, $1.createdAt, $1.name)
            }
            let keeper = ordered[0]
            for duplicate in ordered.dropFirst() {
                for entry in duplicate.entries ?? [] {
                    entry.list = keeper
                }
                context.delete(duplicate)
            }
        }
        try? context.save()
    }

    private static func defaultName(existingCount: Int) -> String {
        "List \(existingCount + 1)"
    }
}
