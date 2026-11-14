//
//  MarkerNameSuggestionsTests.swift
//  MusicMomentumTests
//

import Testing
@testable import MusicMomentum

@Suite("Marker name suggestions")
struct MarkerNameSuggestionsTests {
    private typealias Point = (name: String, start: Double)

    @Test("The first point is guessed as Intro")
    func firstIsIntro() {
        let names = MarkerNameSuggestions.forMarker(at: 0, among: [])
        #expect(names == ["Intro", "Verse", "Chorus", "Bridge", "Solo"])
    }

    @Test("A marker before every other point is guessed as Intro")
    func beforeAll() {
        let others: [Point] = [("Verse", 30)]
        #expect(MarkerNameSuggestions.forMarker(at: 5, among: others).first == "Intro")
    }

    @Test("The guess follows the nearest earlier point and is numbered")
    func followsPrevious() {
        let others: [Point] = [("Intro", 0), ("Verse", 10), ("Chorus", 40), ("Verse 2", 70)]
        let names = MarkerNameSuggestions.forMarker(at: 100, among: others)
        #expect(names.first == "Chorus 2")
        #expect(names.count == 5)
        #expect(names.contains("Verse 3"))
    }

    @Test("Nearest earlier point is chosen by start, not input order")
    func unsortedInput() {
        let others: [Point] = [("Verse", 50), ("Intro", 0), ("Chorus", 20)]
        #expect(MarkerNameSuggestions.forMarker(at: 60, among: others).first == "Chorus 2")
    }

    @Test("Each section maps to what usually follows it", arguments: [
        ("Intro", "Verse"), ("Verse", "Chorus"), ("Pre-chorus", "Chorus"),
        ("Chorus", "Verse"), ("Bridge", "Chorus"), ("Solo", "Chorus"), ("Outro", "Outro"),
    ])
    func followMap(previous: String, expected: String) {
        let names = MarkerNameSuggestions.forMarker(at: 50, among: [(previous, 10)])
        #expect(names.first == expected || names.first?.hasPrefix(expected + " ") == true)
    }

    @Test("An unknown previous name gives the fallback order")
    func unknownPrevious() {
        for name in ["Marker 7", "Guitar in"] {
            let names = MarkerNameSuggestions.forMarker(at: 50, among: [(name, 10)])
            #expect(names == ["Verse", "Chorus", "Bridge", "Solo", "Pre-chorus"])
        }
    }

    @Test("Guess is not repeated in the fallback tail")
    func noDuplicates() {
        let others: [Point] = [("Verse", 10)]
        let names = MarkerNameSuggestions.forMarker(at: 50, among: others)
        #expect(names == ["Chorus", "Verse 2", "Bridge", "Solo", "Pre-chorus"])
    }

    @Test("Numbering counts an unnumbered use as 1 and continues from the highest")
    func numbering() {
        func verse(_ existing: [String]) -> String? {
            let others = existing.enumerated().map { (name: $0.element, start: Double($0.offset)) }
            return MarkerNameSuggestions.forMarker(at: 1000, among: others).first { $0.hasPrefix("Verse") }
        }
        #expect(verse(["Marker 1"]) == "Verse")
        #expect(verse(["Verse"]) == "Verse 2")
        #expect(verse(["Verse 2"]) == "Verse 3")
        #expect(verse(["Verse", "Verse 3"]) == "Verse 4")
    }

    @Test("Base matching ignores case")
    func caseInsensitive() {
        let others: [Point] = [("verse", 10)]
        let names = MarkerNameSuggestions.forMarker(at: 50, among: others)
        #expect(names.first == "Chorus")
        #expect(names.contains("Verse 2"))
    }

    @Test("Always five suggestions")
    func alwaysFive() {
        let samples: [[Point]] = [[], [("Outro", 5)], [("Marker 1", 5)], [("Intro", 0), ("Verse", 9), ("Solo", 20)]]
        for others in samples {
            #expect(MarkerNameSuggestions.forMarker(at: 30, among: others).count == 5)
        }
    }

    @Test("Loop names are numbered against existing loops")
    func loops() {
        #expect(MarkerNameSuggestions.forLoop(among: []) == ["Riff", "Lick", "Fill", "Solo", "Run"])
        let names = MarkerNameSuggestions.forLoop(among: ["Riff", "riff 4", "Fill 2", "Chorus"])
        #expect(names == ["Riff 5", "Lick", "Fill 3", "Solo", "Run"])
    }

    @Test("Only an untouched default name counts as unnamed")
    func defaultNames() {
        #expect(MarkerNameSuggestions.isDefaultName("Marker 7"))
        #expect(MarkerNameSuggestions.isDefaultName("Loop 12"))
        #expect(!MarkerNameSuggestions.isDefaultName("Chorus 2"))
        #expect(!MarkerNameSuggestions.isDefaultName("Marker"))
        #expect(!MarkerNameSuggestions.isDefaultName("Marker 7 again"))
    }
}
