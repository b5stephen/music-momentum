//
//  SongMarkerTests.swift
//  MusicMomentumTests
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// Every mutator here moves a section boundary, so a wrong one misplaces
/// part of the song the user marked up.
@MainActor
@Suite("Song markers")
struct SongMarkerTests {
    private let context: ModelContext
    private let song: SavedSong

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
        song = SavedSong.save(
            songID: "i.1", title: "Little Wing", artistName: "Jimi Hendrix",
            artworkData: nil, speed: 0.6, in: context
        )
    }

    private func allMarkers() throws -> [SongMarker] {
        try context.fetch(FetchDescriptor<SongMarker>())
    }

    private var times: [TimeInterval] { song.sortedMarkers.map(\.startTime) }

    @Test("Adding trims the name, keeps a blank one blank and clamps at zero")
    func add() {
        let named = SongMarker.add(to: song, name: "  Solo ", at: 61, in: context)
        let unnamed = SongMarker.add(to: song, name: "  ", at: -2, in: context)
        #expect(named.name == "Solo")
        #expect(named.timeLabel == "1:01")
        #expect(unnamed.name == "")
        #expect(unnamed.startTime == 0)
        #expect(unnamed.endTime == nil)
    }

    @Test("Unnamed markers display as Marker N, counted in time order")
    func displayNames() {
        let late = SongMarker.add(to: song, at: 90, in: context)
        let named = SongMarker.add(to: song, name: "Verse", at: 40, in: context)
        let early = SongMarker.add(to: song, at: 5, in: context)
        #expect(song.displayName(of: early) == "Marker 1")
        #expect(song.displayName(of: named) == "Verse")
        #expect(song.displayName(of: late) == "Marker 3")
    }

    @Test("Markers sort by time, then by age")
    func sortedByTime() {
        SongMarker.add(to: song, name: "C", at: 90, in: context)
        SongMarker.add(to: song, name: "A", at: 5, in: context)
        SongMarker.add(to: song, name: "B", at: 40, in: context)
        #expect(song.sortedMarkers.map(\.name) == ["A", "B", "C"])
    }

    @Test("Adding near an existing marker reuses it instead of making a sliver")
    func addSnaps() throws {
        let chorus = SongMarker.add(to: song, name: "Chorus", at: 60, in: context)
        let snapped = SongMarker.addSnapping(to: song, name: "Ignored", at: 60.4, in: context)
        #expect(snapped.marker === chorus)
        #expect(!snapped.created)
        #expect(chorus.name == "Chorus")
        #expect(chorus.startTime == 60)

        let fresh = SongMarker.addSnapping(to: song, name: "Bridge", at: 60.5, in: context)
        #expect(fresh.created)
        #expect(fresh.marker.name == "Bridge")
        #expect(try allMarkers().count == 2)
    }

    @Test("Setting a marker may move it past its neighbours")
    func setMovesFreely() {
        let a = SongMarker.add(to: song, name: "A", at: 10, in: context)
        SongMarker.add(to: song, name: "B", at: 20, in: context)
        a.set(name: "A", time: 30, in: context)
        #expect(song.sortedMarkers.map(\.name) == ["B", "A"])
    }

    @Test("Nudging moves the boundary both sections share")
    func nudgeMovesSharedBoundary() throws {
        SongMarker.add(to: song, name: "Chorus", at: 60, in: context)
        let verse2 = SongMarker.add(to: song, name: "Verse 2", at: 90, in: context)
        verse2.nudge(by: 1, in: context)
        let sections = song.sections(duration: 200)
        let chorus = try #require(sections.first { $0.label == "Chorus" })
        let next = try #require(sections.first { $0.label == "Verse 2" })
        #expect(chorus.end == 91)
        #expect(next.start == 91)
        #expect(times == [60, 91])
    }

    @Test("A nudge stops short of the neighbouring marker and of zero")
    func nudgeClamps() {
        let first = SongMarker.add(to: song, at: 0.5, in: context)
        let second = SongMarker.add(to: song, at: 10, in: context)
        SongMarker.add(to: song, at: 11, in: context)
        first.nudge(by: -1, in: context)
        #expect(first.startTime == 0)
        second.nudge(by: 5, in: context)
        #expect(abs(second.startTime - (11 - MarkerPlacement.minimumNudgedSection)) < 1e-9)
        // Already at the limit: a further nudge leaves it be.
        let before = second.startTime
        second.nudge(by: 1, in: context)
        #expect(second.startTime == before)
        #expect(song.sortedMarkers.map(\.startTime).count == 3)
    }

    @Test("Splitting adds a boundary instead of moving the shared one")
    func split() throws {
        SongMarker.add(to: song, name: "Chorus", at: 60, in: context)
        let verse2 = SongMarker.add(to: song, name: "Verse 2", at: 90, in: context)
        let gap = SongMarker.split(song, at: 85, in: context)
        #expect(verse2.startTime == 90)
        #expect(gap.name == "")
        let sections = song.sections(duration: 200)
        #expect(sections.map(\.start) == [0, 60, 85, 90])
        #expect(sections.map(\.label) == [nil, "Chorus", nil, "Verse 2"])
    }

    @Test("Splitting doesn't snap, but never stacks two markers at one time")
    func splitDoesNotSnap() throws {
        let chorus = SongMarker.add(to: song, name: "Chorus", at: 60, in: context)
        let near = SongMarker.split(song, at: 60.3, in: context)
        #expect(near !== chorus)
        let same = SongMarker.split(song, at: 60, in: context)
        #expect(same === chorus)
        #expect(try allMarkers().count == 2)
    }

    @Test("Deleting a marker merges its section into the previous one, and can be undone")
    func deleteMerges() throws {
        SongMarker.add(to: song, name: "Verse", at: 20, in: context)
        let chorus = SongMarker.add(to: song, name: "Chorus", at: 60, in: context)
        SongMarker.add(to: song, name: "Outro", at: 120, in: context)

        let removed = SongMarker.delete(chorus, in: context)
        #expect(removed == .init(name: "Chorus", time: 60))
        let merged = song.sections(duration: 200)
        #expect(merged.map(\.start) == [0, 20, 120])
        #expect(merged[1].label == "Verse")
        #expect(merged[1].end == 120)

        SongMarker.restore(removed, to: song, in: context)
        #expect(song.sortedMarkers.map(\.name) == ["Verse", "Chorus", "Outro"])
        #expect(times == [20, 60, 120])
    }

    @Test("Merging with the next deletes the next marker")
    func mergeWithNext() throws {
        let verse = SongMarker.add(to: song, name: "Verse", at: 20, in: context)
        SongMarker.add(to: song, name: "Chorus", at: 60, in: context)
        let outro = SongMarker.add(to: song, name: "Outro", at: 120, in: context)

        #expect(SongMarker.mergeWithNext(verse, in: context) == .init(name: "Chorus", time: 60))
        #expect(song.sortedMarkers.map(\.name) == ["Verse", "Outro"])
        #expect(song.sections(duration: 200)[1].end == 120)
        #expect(SongMarker.mergeWithNext(outro, in: context) == nil)
        #expect(try allMarkers().count == 2)
    }

    @Test("Deleting a song takes its markers with it")
    func cascadeDelete() throws {
        SongMarker.add(to: song, name: "Riff", at: 10, in: context)
        context.delete(song)
        try context.save()
        #expect(try allMarkers().isEmpty)
    }

    @Test("Precise times format to tenths and parse back")
    func preciseTimeRoundTrip() {
        #expect(PreciseTime.format(63.4) == "1:03.4")
        #expect(PreciseTime.format(0) == "0:00.0")
        #expect(PreciseTime.format(3723.05) == "1:02:03.1")
        #expect(PreciseTime.parse("1:03.4") == 63.4)
        #expect(PreciseTime.parse("1:03") == 63)
        #expect(PreciseTime.parse("83.4") == 83.4)
        #expect(PreciseTime.parse("1:02:03.1") == 3723.1)
        #expect(PreciseTime.parse("") == nil)
        #expect(PreciseTime.parse("1:x") == nil)
        #expect(PreciseTime.parse("-5") == nil)
    }

    @Test("Every marker change counts as an edit to its song")
    func markerChangesTouchSong() {
        let when = Date.now.addingTimeInterval(-300)

        song.lastPracticed = when
        let marker = SongMarker.add(to: song, name: "Solo", at: 60, in: context)
        #expect(song.lastPracticed > when)

        song.lastPracticed = when
        marker.set(name: "Solo", time: 62, in: context)
        #expect(song.lastPracticed > when)

        song.lastPracticed = when
        marker.nudge(by: 0.1, in: context)
        #expect(song.lastPracticed > when)

        song.lastPracticed = when
        SongMarker.delete(marker, in: context)
        #expect(song.lastPracticed > when)
    }
}
