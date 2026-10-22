//
//  ClipMigrationTests.swift
//  MusicMomentumTests
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// Runs on every device at every launch over the user's synced markers, so
/// a mistake here rewrites everyone's songs.
@MainActor
@Suite("Clip migration")
struct ClipMigrationTests {
    private let context: ModelContext
    private let song: SavedSong
    private let lastChanged = Date.now.addingTimeInterval(-3600)

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
        song = SavedSong.save(
            songID: "i.1", title: "Little Wing", artistName: "Jimi Hendrix",
            artworkData: nil, speed: 0.6, in: context
        )
    }

    /// As an older build stored it.
    @discardableResult
    private func clip(_ name: String, _ start: TimeInterval, _ end: TimeInterval?, on song: SavedSong? = nil, in context: ModelContext? = nil) -> SongMarker {
        let context = context ?? self.context
        let marker = SongMarker(name: name, startTime: start, song: song ?? self.song)
        context.insert(marker)
        marker.endTime = end
        try? context.save()
        return marker
    }

    private func markers(of song: SavedSong? = nil) -> [(String, TimeInterval)] {
        (song ?? self.song).sortedMarkers.map { ($0.name, $0.startTime) }
    }

    private func allMarkers(in context: ModelContext? = nil) throws -> [SongMarker] {
        try (context ?? self.context).fetch(FetchDescriptor<SongMarker>())
    }

    @Test("A clip becomes a named start and an unnamed end")
    func clipToTwoMarkers() throws {
        clip("Solo", 96, 112)
        clip("Verse 2", 150, nil)
        ClipMigration.run(in: context)
        #expect(markers().map(\.0) == ["Solo", "", "Verse 2"])
        #expect(markers().map(\.1) == [96, 112, 150])
        #expect(try allMarkers().allSatisfy { $0.endTime == nil })
    }

    @Test("A clip's end within the snap threshold of a marker reuses it")
    func endReusesNearbyMarker() {
        clip("Solo", 96, 112)
        clip("Outro", 112.3, nil)
        ClipMigration.run(in: context)
        #expect(markers().map(\.0) == ["Solo", "Outro"])
    }

    @Test("Clips butted end to end share the boundary")
    func adjacentClips() {
        clip("Intro", 0, 22)
        clip("Verse", 22, 58)
        clip("Chorus", 70, 90)
        ClipMigration.run(in: context)
        #expect(markers().map(\.0) == ["Intro", "Verse", "", "Chorus", ""])
        #expect(markers().map(\.1) == [0, 22, 58, 70, 90])
    }

    @Test("A short clip's end never snaps to its own start")
    func shortClip() {
        clip("Lick", 10, 10.4)
        ClipMigration.run(in: context)
        #expect(markers().map(\.1) == [10, 10.4])
    }

    @Test("Running again changes nothing")
    func idempotent() throws {
        clip("Intro", 0, 22)
        clip("Solo", 96, 112)
        ClipMigration.run(in: context)
        let first = markers()
        ClipMigration.run(in: context)
        let second = markers()
        #expect(first.map(\.0) == second.map(\.0))
        #expect(first.map(\.1) == second.map(\.1))
        #expect(try allMarkers().count == 4)
    }

    @Test("The migration isn't counted as the user changing the song")
    func leavesDatesAlone() {
        clip("Solo", 96, 112)
        song.lastPracticed = lastChanged
        try? context.save()
        ClipMigration.run(in: context)
        #expect(song.lastPracticed == lastChanged)
    }

    @Test("Two devices' end markers for the same clip collapse to one")
    func twoDevicesCollapse() throws {
        let start = clip("Solo", 96, 112)
        ClipMigration.run(in: context)
        // The other device's copy arriving by sync: same clip, already cleared,
        // and its own end marker, made a moment later.
        let theirs = clip("", 112, nil)
        theirs.createdAt = .now.addingTimeInterval(5)
        try context.save()
        #expect(markers().count == 3)

        ClipMigration.run(in: context)
        #expect(markers().map(\.0) == ["Solo", ""])
        #expect(try allMarkers().contains { $0 === theirs } == false)
        #expect(start.name == "Solo")
    }

    @Test("Both devices collapsing at once delete the same copy")
    func collapseIsDeterministic() throws {
        let older = Date.now.addingTimeInterval(-10)
        let newer = Date.now
        var kept: [Date] = []
        // Each device holds both copies, inserted in opposite orders.
        for order in [[older, newer], [newer, older]] {
            let context = ModelContext(try AppSchema.inMemoryContainer())
            let song = SavedSong.save(songID: "i.1", title: "T", artistName: "A", artworkData: nil, speed: 1, in: context)
            clip("Solo", 96, nil, on: song, in: context)
            for created in order {
                clip("", 112, nil, on: song, in: context).createdAt = created
            }
            try context.save()
            ClipMigration.run(in: context)
            let ends = try allMarkers(in: context).filter { $0.name.isEmpty }
            #expect(ends.count == 1)
            kept += ends.map(\.createdAt)
        }
        #expect(kept == [older, older])
    }

    @Test("A named marker wins over an unnamed one at the same time; named ones are never collapsed")
    func namedSurvive() {
        let unnamed = clip("", 112, nil)
        unnamed.createdAt = .now.addingTimeInterval(-100)
        clip("Outro", 112, nil)
        clip("Bridge", 112, nil)
        ClipMigration.run(in: context)
        #expect(Set(markers().map(\.0)) == ["Outro", "Bridge"])
    }

    @Test("Unnamed markers merely near each other are left alone")
    func nearIsNotSame() {
        clip("", 112, nil)
        clip("", 112.2, nil)
        ClipMigration.run(in: context)
        #expect(markers().count == 2)
    }
}
