//
//  ListFilterTests.swift
//  MusicMomentumTests
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// Filtering decides which songs appear in Saved and must never hide songs
/// behind stale list IDs or wrong match semantics.
@MainActor
@Suite("List filters")
struct ListFilterTests {
    private let context: ModelContext

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
    }

    private func song(_ id: String, title: String, artist: String = "Artist") -> SavedSong {
        SavedSong.save(songID: id, title: title, artistName: artist, artworkData: nil, speed: 1.0, in: context)
    }

    @Test("All, unfiled, single-list, and multi-list filters match expected songs")
    func filterMatching() {
        let level1 = PracticeList.create(name: "Level 1", in: context)
        let acoustic = PracticeList.create(name: "Acoustic", in: context)

        let s1 = song("1", title: "Blackbird", artist: "The Beatles")
        let s2 = song("2", title: "Little Wing", artist: "Jimi Hendrix")
        let s3 = song("3", title: "Unfiled Tune", artist: "Someone")

        PracticeList.add([s1], to: level1, in: context)
        PracticeList.add([s1, s2], to: acoustic, in: context)

        let all = [s1, s2, s3]

        #expect(ListFilter.all.apply(to: all).map(\.songID) == ["1", "2", "3"])
        #expect(ListFilter.unfiled.apply(to: all).map(\.songID) == ["3"])
        #expect(ListFilter.lists(ids: [level1.listID], match: .all).apply(to: all).map(\.songID) == ["1"])
        #expect(ListFilter.lists(ids: [level1.listID, acoustic.listID], match: .all).apply(to: all).map(\.songID) == ["1"])
        #expect(ListFilter.lists(ids: [level1.listID, acoustic.listID], match: .any).apply(to: all).map(\.songID) == ["1", "2"])
        #expect(ListFilter.lists(ids: [acoustic.listID], match: .all).apply(to: all, searchTerm: "jimi").map(\.songID) == ["2"])
    }

    @Test("Reconciling drops deleted list IDs and falls back to .all when none remain")
    func reconcilesDeletedLists() {
        let level1 = PracticeList.create(name: "Level 1", in: context)
        let acoustic = PracticeList.create(name: "Acoustic", in: context)

        let multi = ListFilter.lists(ids: [level1.listID, acoustic.listID], match: .any)
        #expect(multi.reconciled(with: [level1]) == .lists(ids: [level1.listID], match: .any))
        #expect(multi.reconciled(with: []) == .all)
        #expect(ListFilter.unfiled.reconciled(with: []) == .unfiled)
    }

    @Test("Toggling supports single-select and multi-select chip interactions")
    func togglingChips() {
        var filter = ListFilter.all
        filter = filter.toggling(listID: "a", multiSelect: false)
        #expect(filter == .lists(ids: ["a"], match: .all))

        filter = filter.toggling(listID: "b", multiSelect: false)
        #expect(filter == .lists(ids: ["b"], match: .all))

        filter = filter.toggling(listID: "b", multiSelect: false)
        #expect(filter == .all)

        filter = filter.toggling(listID: "a", multiSelect: true)
        filter = filter.toggling(listID: "b", multiSelect: true)
        #expect(filter == .lists(ids: ["a", "b"], match: .all))

        filter = filter.toggling(listID: "a", multiSelect: true)
        #expect(filter == .lists(ids: ["b"], match: .all))
    }

    @Test("Raw storage round-trips ListFilter values")
    func rawStorageRoundTrip() {
        let original = ListFilter.lists(ids: ["l1", "l2"], match: .any)
        #expect(ListFilter(rawStorage: original.rawStorage) == original)
        #expect(ListFilter(rawStorage: ListFilter.unfiled.rawStorage) == .unfiled)
    }
}
