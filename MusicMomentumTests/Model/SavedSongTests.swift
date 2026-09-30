//
//  SavedSongTests.swift
//  MusicMomentumTests
//
//  Created by Stephen Denekamp on 05/09/2026.
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// Getting the upsert wrong silently destroys speeds the user tuned by hand.
@MainActor
@Suite("Saved songs")
struct SavedSongTests {
    private let context: ModelContext

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
    }

    private func allSongs() throws -> [SavedSong] {
        try context.fetch(FetchDescriptor<SavedSong>())
    }

    @discardableResult
    private func save(
        _ songID: String,
        catalogID: String? = nil,
        title: String = "Blackbird",
        artist: String = "The Beatles",
        artworkData: Data? = nil,
        speed: Double = 1.0
    ) -> SavedSong {
        SavedSong.save(
            songID: songID,
            catalogID: catalogID,
            title: title,
            artistName: artist,
            artworkData: artworkData,
            speed: speed,
            in: context
        )
    }

    @Test("Saving a new song stores every field")
    func savesNewSong() throws {
        let art = Data("cover".utf8)
        save("i.1", title: "Little Wing", artist: "Jimi Hendrix", artworkData: art, speed: 0.6)

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].songID == "i.1")
        #expect(songs[0].title == "Little Wing")
        #expect(songs[0].artistName == "Jimi Hendrix")
        #expect(songs[0].artworkData == art)
        #expect(songs[0].speed == 0.6)
    }

    @Test("Re-saving the same song updates it instead of duplicating")
    func reSaveUpdatesInPlace() throws {
        save("i.1", speed: 1.0)
        save("i.1", speed: 0.5)

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].speed == 0.5)
    }

    @Test("Re-saving refreshes metadata that has gone stale")
    func reSaveRefreshesMetadata() throws {
        let old = Data("old".utf8)
        let new = Data("new".utf8)
        save("i.1", catalogID: "1", title: "Blackbrid", artist: "Beatles", artworkData: old)
        save("i.1", catalogID: "1440857781", title: "Blackbird", artist: "The Beatles", artworkData: new)

        let song = try #require(SavedSong.find(songID: "i.1", in: context))
        #expect(song.title == "Blackbird")
        #expect(song.artistName == "The Beatles")
        #expect(song.artworkData == new)
        #expect(song.catalogID == "1440857781")
    }

    @Test("Saving keeps the catalog ID alongside the library one")
    func savesCatalogID() throws {
        save("i.1", catalogID: "1440857781")
        #expect(try allSongs()[0].catalogID == "1440857781")
    }

    /// The rule behind `SavedSongsView.add`.
    @Test("Adding an already-saved song keeps its tuned speed")
    func addingExistingSongKeepsSpeed() throws {
        save("i.1", speed: 0.6)

        let existing = try #require(SavedSong.find(songID: "i.1", in: context))
        SavedSong.touch(existing, in: context)

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].speed == 0.6)
    }

    /// Artwork is repaired on every device a sync reaches; bumping a date
    /// would reshuffle each of their lists.
    @Test("Replacing artwork keeps both dates")
    func settingArtworkKeepsDates() throws {
        let song = save("i.1", artworkData: Data("local".utf8))
        let when = Date.now.addingTimeInterval(-300)
        song.lastPracticed = when
        song.practicedAt = when

        SavedSong.setArtwork(Data("catalog".utf8), for: song, in: context)

        #expect(song.artworkData == Data("catalog".utf8))
        #expect(song.lastPracticed == when)
        #expect(song.practicedAt == when)
    }

    @Test("A newly saved song has never been practised")
    func newSongNeverPractised() {
        #expect(save("i.1").practicedAt == nil)
    }

    /// A "last practised" label would lie if editing moved it.
    @Test("Saving and touching change the edit date, not the practice date")
    func editsLeavePracticeDate() throws {
        let song = save("i.1", speed: 1.0)
        let when = Date.now.addingTimeInterval(-300)
        song.lastPracticed = when
        song.practicedAt = when

        save("i.1", speed: 0.8)
        #expect(song.lastPracticed > when)
        #expect(song.practicedAt == when)

        song.lastPracticed = when
        SavedSong.touch(song, in: context)
        #expect(song.lastPracticed > when)
        #expect(song.practicedAt == when)
    }

    @Test("Practising changes the practice date, not the edit date")
    func practiceLeavesEditDate() throws {
        let song = save("i.1")
        let when = Date.now.addingTimeInterval(-300)
        song.lastPracticed = when

        SavedSong.markPracticed(song, in: context)

        #expect(try #require(song.practicedAt) > when)
        #expect(song.lastPracticed == when)
    }

    @Test("Finding a song by ID")
    func findsByID() {
        save("i.1")
        #expect(SavedSong.find(songID: "i.1", in: context) != nil)
        #expect(SavedSong.find(songID: "i.2", in: context) == nil)
    }

    /// The sort behind "Practising lately", which relies on the store putting
    /// a `nil` practice date last when descending.
    @Test("Practised songs come first, then the rest by last change")
    func sortsByPractice() throws {
        // Explicit dates: the clock may not tick between saves in a row.
        save("i.1").lastPracticed = .now.addingTimeInterval(-400)
        save("i.2").lastPracticed = .now.addingTimeInterval(-100)
        save("i.3").practicedAt = .now.addingTimeInterval(-300)
        save("i.4").practicedAt = .now.addingTimeInterval(-200)

        let descriptor = FetchDescriptor<SavedSong>(sortBy: [
            SortDescriptor(\.practicedAt, order: .reverse),
            SortDescriptor(\.lastPracticed, order: .reverse),
        ])
        let ordered = try context.fetch(descriptor)
        #expect(ordered.map(\.songID) == ["i.4", "i.3", "i.2", "i.1"])
    }

    @Test("Deleting removes only the song asked for")
    func deleteRemovesOne() throws {
        save("i.1")
        save("i.2")

        context.delete(try #require(SavedSong.find(songID: "i.1", in: context)))
        try context.save()

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].songID == "i.2")
    }

    /// Inserted directly: `save` upserts, and duplicates only arrive by sync.
    @discardableResult
    private func insertDuplicate(
        _ songID: String,
        catalogID: String? = nil,
        speed: Double,
        lastPracticed: Date,
        practicedAt: Date? = nil
    ) -> SavedSong {
        let song = SavedSong(
            songID: songID, catalogID: catalogID, speed: speed,
            lastPracticed: lastPracticed, practicedAt: practicedAt
        )
        context.insert(song)
        return song
    }

    @Test("Merging keeps the most recently changed copy and every marker")
    func mergeKeepsNewestAndAllMarkers() throws {
        let older = insertDuplicate("i.1", catalogID: "1440857781", speed: 0.5, lastPracticed: .now.addingTimeInterval(-60))
        let newer = insertDuplicate("i.1", speed: 0.8, lastPracticed: .now)
        insertDuplicate("i.2", speed: 1.0, lastPracticed: .now)
        SongMarker.add(to: older, name: "Solo", startTime: 60, endTime: 90, in: context)
        SongMarker.add(to: newer, name: "Intro", startTime: 0, endTime: nil, in: context)

        SavedSong.mergeDuplicates(in: context)

        let songs = try allSongs()
        #expect(songs.count == 2)
        let merged = try #require(songs.first { $0.songID == "i.1" })
        #expect(merged.speed == 0.8)
        #expect(merged.catalogID == "1440857781")
        #expect(merged.sortedMarkers.map(\.name) == ["Intro", "Solo"])
        #expect(try context.fetch(FetchDescriptor<SongMarker>()).count == 2)
    }

    @Test("Merging keeps the latest practice from either copy")
    func mergeKeepsLatestPractice() throws {
        let practised = Date.now
        insertDuplicate("i.1", speed: 0.5, lastPracticed: .now.addingTimeInterval(-60), practicedAt: practised)
        insertDuplicate("i.1", speed: 0.8, lastPracticed: .now)

        SavedSong.mergeDuplicates(in: context)

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].speed == 0.8)
        #expect(songs[0].practicedAt == practised)
    }

    @Test("Copies changed at the same moment fall back to the latest practice")
    func mergeTieBreaksOnPractice() throws {
        let when = Date.now
        insertDuplicate("i.1", speed: 0.6, lastPracticed: when, practicedAt: when)
        insertDuplicate("i.1", speed: 0.7, lastPracticed: when)

        SavedSong.mergeDuplicates(in: context)

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].speed == 0.6)
    }

    @Test("Merging picks the same survivor whatever order the rows come in")
    func mergeTieBreaksOnSyncedFields() throws {
        let when = Date.now
        insertDuplicate("i.1", speed: 0.6, lastPracticed: when)
        insertDuplicate("i.1", speed: 0.7, lastPracticed: when)

        SavedSong.mergeDuplicates(in: context)

        let songs = try allSongs()
        #expect(songs.count == 1)
        #expect(songs[0].speed == 0.7)
    }

    @Test("Percent rounds the stored speed for display")
    func percentRounds() {
        #expect(save("i.1", speed: 0.755).percent == 76)
        #expect(save("i.2", speed: 1.0).percent == 100)
    }
}
