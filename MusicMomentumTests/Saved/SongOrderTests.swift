//
//  SongOrderTests.swift
//  MusicMomentumTests
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// A wrong heading files a song where nobody looks for it.
@MainActor
@Suite("Song order and sections")
struct SongOrderTests {
    private let context: ModelContext
    private let calendar: Calendar
    /// Wednesday 25 November 2026, 15:00 UTC.
    private let now: Date

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 15))!
    }

    private func song(_ title: String, artist: String = "", practicedDaysAgo: Double? = nil) -> SavedSong {
        let song = SavedSong(
            songID: title,
            speed: 1,
            title: title,
            artistName: artist,
            practicedAt: practicedDaysAgo.map { now.addingTimeInterval(-$0 * 86_400) }
        )
        context.insert(song)
        return song
    }

    private func headingID(daysAgo: Double) -> String {
        SongSection.dateHeading(for: now.addingTimeInterval(-daysAgo * 86_400), now: now, calendar: calendar).id
    }

    @Test("Dates fall into Today, Yesterday, the last week and the last month")
    func recentBuckets() {
        #expect(headingID(daysAgo: 0.5) == "today")
        #expect(headingID(daysAgo: 1) == "yesterday")
        #expect(headingID(daysAgo: 3) == "week")
        #expect(headingID(daysAgo: 7) == "week")
        #expect(headingID(daysAgo: 8) == "month")
        #expect(headingID(daysAgo: 30) == "month")
    }

    @Test("Older dates this year go by month, earlier years by year")
    func olderBuckets() {
        let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let heading = SongSection.dateHeading(for: march, now: now, calendar: calendar)
        #expect(heading.id == "month-3")
        #expect(SongSection.dateHeading(for: .distantPast, now: now, calendar: calendar).id == "year-1")
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        #expect(SongSection.dateHeading(for: lastYear, now: now, calendar: calendar).id == "year-2025")
    }

    @Test("A date ahead of the clock counts as today")
    func futureIsToday() {
        #expect(headingID(daysAgo: -2) == "today")
    }

    @Test("Titles file under their first letter, folded, or # when it isn't one")
    func indexLetters() {
        #expect(SongSection.indexLetter(for: "blackbird") == "B")
        #expect(SongSection.indexLetter(for: "Écoute") == "E")
        #expect(SongSection.indexLetter(for: "99 Problems") == "#")
        #expect(SongSection.indexLetter(for: "(Sittin' On) The Dock") == "#")
        #expect(SongSection.indexLetter(for: "") == "#")
    }

    @Test("Title order makes one section per letter, in order, with an index")
    func titleSections() {
        let songs = ["Little Wing", "blackbird", "Bohemian Rhapsody", "4 Minutes"].map { song($0) }

        let sections = SongOrder.title.sections(songs, now: now, calendar: calendar)

        #expect(sections.map(\.title) == ["#", "B", "L"])
        #expect(sections.map(\.indexLabel) == ["#", "B", "L"])
        #expect(sections[1].songs.map(\.title) == ["blackbird", "Bohemian Rhapsody"])
    }

    @Test("Artist order files songs under the artist's first letter, with an index")
    func artistSections() {
        let songs = [
            song("Little Wing", artist: "Jimi Hendrix"),
            song("Both Sides Now", artist: "Joni Mitchell"),
            song("Demo"),
            song("Blackbird", artist: "The Beatles"),
        ]

        let sections = SongOrder.artist.sections(songs, now: now, calendar: calendar)

        #expect(sections.map(\.title) == ["#", "J", "T"])
        #expect(sections.map(\.indexLabel) == ["#", "J", "T"])
        #expect(sections[1].songs.map(\.title) == ["Little Wing", "Both Sides Now"])
    }

    @Test("Practice order puts songs never played last, under their own heading")
    func practicedSections() {
        let songs = [
            song("Never"),
            song("Old", practicedDaysAgo: 20),
            song("Fresh", practicedDaysAgo: 0.1),
        ]

        let sections = SongOrder.practiced.sections(songs, now: now, calendar: calendar)

        #expect(sections.map(\.id) == ["today", "month", "never"])
        #expect(sections.map { $0.songs.map(\.title) } == [["Fresh"], ["Old"], ["Never"]])
    }

    @Test("Only a list of twelve songs or more is grouped")
    func groupingThreshold() {
        #expect(!SongSection.groups(songCount: 0))
        #expect(!SongSection.groups(songCount: 11))
        #expect(SongSection.groups(songCount: 12))
        #expect(SongSection.groups(songCount: 300))
    }

    @Test("No songs, no sections")
    func emptyList() {
        #expect(SongOrder.title.sections([], now: now, calendar: calendar).isEmpty)
    }
}
