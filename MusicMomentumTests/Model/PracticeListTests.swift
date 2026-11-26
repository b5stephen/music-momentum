//
//  PracticeListTests.swift
//  MusicMomentumTests
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// Corrupting list memberships or deleting saved songs alongside a list
/// would throw away speeds and markers the user built up.
@MainActor
@Suite("Practice lists")
struct PracticeListTests {
    private let context: ModelContext

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
    }

    private func song(_ id: String, title: String? = nil) -> SavedSong {
        SavedSong.save(
            songID: id,
            title: title ?? id,
            artistName: "Artist",
            artworkData: nil,
            speed: 0.75,
            in: context
        )
    }

    @Test("Creating lists trims whitespace, defaults blank names, and increments sortOrder")
    func createLists() {
        let first = PracticeList.create(name: "  Level 1  ", in: context)
        let second = PracticeList.create(name: "   ", in: context)

        #expect(first.name == "Level 1")
        #expect(second.name == "List 2")
        #expect(first.sortOrder < second.sortOrder)
        #expect(PracticeList.all(in: context).map(\.name) == ["Level 1", "List 2"])
    }

    @Test("Renaming ignores blank names and preserves the existing name")
    func renameList() {
        let list = PracticeList.create(name: "Blues", in: context)
        PracticeList.rename(list, to: "   ", in: context)
        #expect(list.name == "Blues")

        PracticeList.rename(list, to: "  Jazz Blues  ", in: context)
        #expect(list.name == "Jazz Blues")
    }

    @Test("Reordering updates sortOrder across lists")
    func reorderLists() {
        let a = PracticeList.create(name: "A", in: context)
        let b = PracticeList.create(name: "B", in: context)
        let c = PracticeList.create(name: "C", in: context)

        PracticeList.reorder([c, a, b], in: context)

        #expect(PracticeList.all(in: context).map(\.name) == ["C", "A", "B"])
    }

    @Test("Adding songs seeds sequential positions and ignores duplicates")
    func addSongsSeedsPositions() {
        let list = PracticeList.create(name: "Setlist", in: context)
        let s1 = song("1", title: "One")
        let s2 = song("2", title: "Two")
        let s3 = song("3", title: "Three")

        PracticeList.add([s1, s2], to: list, in: context)
        PracticeList.add([s2, s3], to: list, in: context)

        #expect(list.songs.map(\.songID) == ["1", "2", "3"])
        #expect(list.sortedEntries.map(\.position) == [1, 2, 3])
        #expect(list.songCount == 3)
    }

    @Test("Deleting a list deletes its entries without deleting saved songs")
    func deletingListPreservesSongs() throws {
        let list = PracticeList.create(name: "Tuesday Lesson", in: context)
        let s1 = song("1", title: "Blackbird")
        PracticeList.add([s1], to: list, in: context)

        PracticeList.delete(list, in: context)

        #expect(PracticeList.all(in: context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PracticeListEntry>()).isEmpty)
        let remaining = try context.fetch(FetchDescriptor<SavedSong>())
        #expect(remaining.map(\.songID) == ["1"])
        #expect(remaining[0].isUnfiled)
    }

    @Test("Deleting a saved song cascades its membership entries without deleting the list")
    func deletingSongPreservesList() throws {
        let list = PracticeList.create(name: "Gig Set", in: context)
        let s1 = song("1")
        let s2 = song("2")
        PracticeList.add([s1, s2], to: list, in: context)

        context.delete(s1)
        try context.save()

        #expect(list.songs.map(\.songID) == ["2"])
        #expect(try context.fetch(FetchDescriptor<PracticeListEntry>()).count == 1)
    }

    @Test("setLists updates memberships in one pass")
    func setListsUpdatesMemberships() {
        let l1 = PracticeList.create(name: "Level 1", in: context)
        let l2 = PracticeList.create(name: "Level 2", in: context)
        let l3 = PracticeList.create(name: "Capo 2", in: context)
        let s1 = song("1")

        PracticeList.setLists([l1, l2], for: s1, in: context)
        #expect(s1.lists.map(\.name) == ["Level 1", "Level 2"])

        PracticeList.setLists([l2, l3], for: s1, in: context)
        #expect(s1.lists.map(\.name) == ["Level 2", "Capo 2"])
        #expect(l1.songCount == 0)
        #expect(l2.songCount == 1)
        #expect(l3.songCount == 1)
    }

    @Test("Merging duplicate saved songs preserves and deduplicates list memberships")
    func mergeDuplicatesPreservesLists() throws {
        let l1 = PracticeList.create(name: "Level 1", in: context)
        let l2 = PracticeList.create(name: "Gig", in: context)

        let older = SavedSong(songID: "i.1", speed: 0.6, title: "Older", lastPracticed: .now.addingTimeInterval(-60))
        let newer = SavedSong(songID: "i.1", speed: 0.8, title: "Newer", lastPracticed: .now)
        context.insert(older)
        context.insert(newer)
        PracticeList.add([older], to: l1, in: context)
        PracticeList.add([older], to: l2, in: context)
        PracticeList.add([newer], to: l2, in: context)

        SavedSong.mergeDuplicates(in: context)

        let songs = try context.fetch(FetchDescriptor<SavedSong>())
        #expect(songs.count == 1)
        #expect(songs[0].speed == 0.8)
        #expect(songs[0].lists.map(\.name) == ["Level 1", "Gig"])
        #expect(try context.fetch(FetchDescriptor<PracticeListEntry>()).count == 2)
    }

    @Test("Merging duplicate saved songs keeps an entry whose list hasn't synced yet")
    func mergeDuplicatesKeepsUnlinkedEntries() throws {
        let older = SavedSong(songID: "i.1", speed: 0.6, title: "Older", lastPracticed: .now.addingTimeInterval(-60))
        let newer = SavedSong(songID: "i.1", speed: 0.8, title: "Newer", lastPracticed: .now)
        context.insert(older)
        context.insert(newer)
        let pending = PracticeListEntry(position: 1, song: older)
        context.insert(pending)
        try context.save()

        SavedSong.mergeDuplicates(in: context)

        let entries = try context.fetch(FetchDescriptor<PracticeListEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.song?.persistentModelID == newer.persistentModelID)
    }

    @Test("deduplicateEntries removes duplicate entries synced for the same song and list")
    func deduplicateEntries() throws {
        let list = PracticeList.create(name: "Warmup", in: context)
        let s1 = song("1")
        let earlier = PracticeListEntry(position: 1, addedAt: .now.addingTimeInterval(-30), list: list, song: s1)
        let later = PracticeListEntry(position: 2, addedAt: .now, list: list, song: s1)
        context.insert(earlier)
        context.insert(later)
        try context.save()

        PracticeList.deduplicateEntries(in: context)

        let entries = try context.fetch(FetchDescriptor<PracticeListEntry>())
        #expect(entries.count == 1)
        #expect(entries[0].position == 1)
    }
}
