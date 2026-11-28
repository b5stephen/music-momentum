//
//  ListFolderTests.swift
//  MusicMomentumTests
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// A song dropped from a folder, or a folder that loses its unfiled songs,
/// hides saved songs from the Lists view.
@MainActor
@Suite("List folders")
struct ListFolderTests {
    private let context: ModelContext

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
    }

    private func song(_ id: String) -> SavedSong {
        SavedSong.save(songID: id, title: id, artistName: "Artist", artworkData: nil, speed: 1.0, in: context)
    }

    @Test("All Songs leads, then folders follow list order, keep the songs' order, and repeat a song in each of its lists")
    func grouping() {
        let a = song("a"), b = song("b"), c = song("c")
        let warmUps = PracticeList.create(name: "Warm-ups", in: context)
        let gig = PracticeList.create(name: "Gig", in: context)
        PracticeList.add([a, b], to: warmUps, in: context)
        PracticeList.add([b], to: gig, in: context)

        let folders = ListFolder.folders(lists: [warmUps, gig], songs: [c, b, a], isSearching: false)

        #expect(folders.map(\.id) == [ListFolder.allID, warmUps.listID, gig.listID, ListFolder.unfiledID])
        #expect(folders[0].songs.map(\.songID) == ["c", "b", "a"])
        #expect(folders[0].list == nil)
        #expect(folders[1].songs.map(\.songID) == ["b", "a"])
        #expect(folders[2].songs.map(\.songID) == ["b"])
        #expect(folders[3].songs.map(\.songID) == ["c"])
        #expect(folders[3].list == nil)
    }

    @Test("Empty lists keep their folder, but searching drops every empty folder")
    func emptyFolders() {
        let a = song("a")
        let empty = PracticeList.create(name: "Empty", in: context)
        let full = PracticeList.create(name: "Full", in: context)
        PracticeList.add([a], to: full, in: context)

        let browsing = ListFolder.folders(lists: [empty, full], songs: [a], isSearching: false)
        #expect(browsing.map(\.id) == [ListFolder.allID, empty.listID, full.listID])

        let searching = ListFolder.folders(lists: [empty, full], songs: [a], isSearching: true)
        #expect(searching.map(\.id) == [full.listID])
    }

    @Test("All Songs is left out with no songs to hold")
    func allSongsNeedsSongs() {
        let list = PracticeList.create(name: "Empty", in: context)

        let folders = ListFolder.folders(lists: [list], songs: [], isSearching: false)

        #expect(folders.map(\.id) == [list.listID])
    }

    @Test("Lists start open and All Songs starts closed, and a toggle flips each")
    func startingState() {
        var collapsed = ListFolder.Collapsed()
        #expect(collapsed.isOpen("list"))
        #expect(!collapsed.isOpen(ListFolder.allID))

        collapsed.toggle("list")
        collapsed.toggle(ListFolder.allID)

        #expect(!collapsed.isOpen("list"))
        #expect(collapsed.isOpen(ListFolder.allID))
    }

    @Test("Collapsed folders survive a round trip through storage")
    func collapsedStorage() {
        var collapsed = ListFolder.Collapsed()
        collapsed.toggle("one")
        collapsed.toggle("two")
        collapsed.toggle("one")

        #expect(ListFolder.Collapsed(rawValue: collapsed.rawValue)?.ids == ["two"])
        #expect(ListFolder.Collapsed(rawValue: "")?.ids == [])
    }
}
