//
//  SectionSpanTests.swift
//  MusicMomentumTests
//

import Testing
@testable import MusicMomentum

@Suite("Section spans")
struct SectionSpanTests {
    private let points: [(name: String, start: Double)] = [
        ("Chorus", 60), ("Intro", 0), ("Verse", 20),
    ]

    @Test("Ends at the next point by start time, whatever the input order")
    func nextPoint() {
        let end = SectionSpan.end(after: 5, among: points, duration: 200)
        #expect(end.name == "Verse")
        #expect(end.time == 20)
    }

    @Test("A point exactly at start is not after it")
    func tie() {
        let end = SectionSpan.end(after: 20, among: points, duration: 200)
        #expect(end.name == "Chorus")
        #expect(end.time == 60)
    }

    @Test("No next point runs to the duration")
    func lastSection() {
        let end = SectionSpan.end(after: 60, among: points, duration: 200)
        #expect(end.name == nil)
        #expect(end.time == 200)
        #expect(SectionSpan.end(after: 1, among: [], duration: 90).time == 90)
    }

    @Test("Containing picks the last point at or before the time")
    func containing() {
        #expect(SectionSpan.name(containing: 25, among: points) == "Verse")
        #expect(SectionSpan.name(containing: 60, among: points) == "Chorus")
        #expect(SectionSpan.name(containing: 0, among: points) == "Intro")
        #expect(SectionSpan.name(containing: 500, among: points) == "Chorus")
    }

    @Test("Before the first point there is no section")
    func beforeFirst() {
        let later: [(name: String, start: Double)] = [("Verse", 10)]
        #expect(SectionSpan.name(containing: 5, among: later) == nil)
        #expect(SectionSpan.name(containing: 5, among: []) == nil)
    }
}
