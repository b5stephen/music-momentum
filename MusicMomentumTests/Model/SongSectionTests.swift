//
//  SongSectionTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// Sections are what gets looped, so a wrong boundary loops the wrong music.
@Suite("Sections derived from markers")
struct SongSectionTests {
    private func derive(_ markers: [(Int, TimeInterval, String)], duration: TimeInterval = 200) -> [SongSection<Int>] {
        SongSection.derive(from: markers.map { (id: $0.0, time: $0.1, name: $0.2) }, duration: duration)
    }

    @Test("No markers: one section, the whole song")
    func empty() {
        let sections = derive([])
        #expect(sections.count == 1)
        #expect(sections[0].start == 0)
        #expect(sections[0].end == 200)
        #expect(sections[0].isWholeSong)
        #expect(sections[0].opening == nil)
        #expect(sections[0].displayName == "Whole song")
    }

    @Test("A first marker after 0:00 leaves an unnamed leading section")
    func leading() {
        let sections = derive([(1, 30, "Verse")])
        #expect(sections.map(\.start) == [0, 30])
        #expect(sections.map(\.end) == [30, 200])
        #expect(sections[0].opening == nil)
        #expect(!sections[0].isWholeSong)
        #expect(sections[0].label == nil)
        #expect(sections[1].opening?.id == 1)
    }

    @Test("A marker at 0:00 leaves no leading section, and the last runs to the end")
    func noLeading() {
        let sections = derive([(1, 0, "Intro"), (2, 60, "Chorus")])
        #expect(sections.map(\.start) == [0, 60])
        #expect(sections.last?.end == 200)
        #expect(sections.map(\.label) == ["Intro", "Chorus"])
    }

    @Test("Unsorted input comes out in time order, indexed in that order")
    func unsorted() {
        let sections = derive([(3, 120, ""), (1, 10, "Intro"), (2, 60, "")])
        #expect(sections.map(\.start) == [0, 10, 60, 120])
        #expect(sections.map(\.end) == [10, 60, 120, 200])
        #expect(sections.compactMap(\.opening?.id) == [1, 2, 3])
        #expect(sections.compactMap(\.opening?.index) == [0, 1, 2])
    }

    @Test("Unnamed markers have no label but display as Marker N")
    func names() {
        let sections = derive([(1, 10, ""), (2, 60, "Chorus"), (3, 120, "")])
        #expect(sections.map(\.label) == [nil, nil, "Chorus", nil])
        #expect(sections.map(\.displayName) == ["Start", "Marker 1", "Chorus", "Marker 3"])
        #expect(SongSection<Int>.markerName("", index: 4) == "Marker 5")
        #expect(SongSection<Int>.markerName("Solo", index: 4) == "Solo")
    }

    @Test("Markers sharing a time each keep a (zero-length) section, in input order")
    func sharedTime() {
        let sections = derive([(1, 60, "A"), (2, 60, "B")])
        #expect(sections.compactMap(\.opening?.id) == [1, 2])
        #expect(sections[1].length == 0)
        #expect(sections[2].end == 200)
    }

    @Test("Markers past the end are clamped into the song")
    func clamped() {
        let sections = derive([(1, 50, ""), (2, 250, "")], duration: 100)
        #expect(sections.map(\.start) == [0, 50, 100])
        #expect(sections.map(\.end) == [50, 100, 100])
    }

    @Test("A section contains its start but not its end")
    func contains() {
        let section = derive([(1, 10, "")])[1]
        #expect(section.contains(10))
        #expect(section.contains(199.9))
        #expect(!section.contains(200))
        #expect(!section.contains(9.9))
    }
}
