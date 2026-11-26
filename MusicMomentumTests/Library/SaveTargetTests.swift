//
//  SaveTargetTests.swift
//  MusicMomentumTests
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// A row's + decides whether a song lands in Saved or a list, and its tick
/// claims the song is already there; getting either wrong misfiles songs.
@MainActor
@Suite("Save targets")
struct SaveTargetTests {
    private let context: ModelContext

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
    }

    private func song(_ id: String) -> SavedSong {
        SavedSong.save(songID: id, title: "Song \(id)", artistName: "Artist", artworkData: nil, speed: 0.7, in: context)
    }

    @Test("Saved contains any saved song, and nothing unsaved")
    func savedContains() {
        let target = SaveTarget.saved
        #expect(target.contains(song("1")))
        #expect(!target.contains(nil))
    }

    @Test("A list contains only its own songs, so a saved song elsewhere still gets a +")
    func listContains() {
        let acoustic = PracticeList.create(name: "Acoustic", in: context)
        let inList = song("1")
        let elsewhere = song("2")
        PracticeList.add([inList], to: acoustic, in: context)

        let target = SaveTarget.list(acoustic)
        #expect(target.contains(inList))
        #expect(!target.contains(elsewhere))
        #expect(!target.contains(nil))
    }

    @Test("Adding a saved song to a list keeps its speed and adds it once")
    func addSavedToList() {
        let acoustic = PracticeList.create(name: "Acoustic", in: context)
        let saved = song("1")
        let target = SaveTarget(list: acoustic)

        target.add(saved, in: context)
        target.add(saved, in: context)

        #expect(saved.isInList(acoustic))
        #expect(acoustic.songCount == 1)
        #expect(saved.speed == 0.7)
    }

    @Test("Adding to Saved leaves lists alone")
    func addSavedToSaved() {
        let acoustic = PracticeList.create(name: "Acoustic", in: context)
        let saved = song("1")

        SaveTarget(list: nil).add(saved, in: context)

        #expect(!saved.isInList(acoustic))
        #expect(saved.isUnfiled)
    }

    @Test("The name is what the picker's title and confirmation say")
    func names() {
        let acoustic = PracticeList.create(name: "Acoustic", in: context)
        #expect(SaveTarget.saved.name == "Saved")
        #expect(SaveTarget.list(acoustic).name == "Acoustic")
        #expect(SongPickerView.addTitle(for: .list(acoustic)) == "Add to Acoustic")
    }
}
