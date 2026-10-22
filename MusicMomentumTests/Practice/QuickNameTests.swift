//
//  QuickNameTests.swift
//  MusicMomentumTests
//

import Testing
@testable import MusicMomentum

/// A chip that names the wrong thing, or shows selected for the wrong name,
/// leaves a song with two sections called the same.
@Suite("Quick-pick names")
struct QuickNameTests {
    @Test("A chip matches its name and its numbered copies, in any case")
    func matches() {
        #expect(QuickName.matches("Verse", name: "Verse"))
        #expect(QuickName.matches("Verse", name: " verse 2 "))
        #expect(!QuickName.matches("Verse", name: "Verses"))
        #expect(!QuickName.matches("Verse", name: "Verse two"))
        #expect(!QuickName.matches("Verse", name: "Verse 0"))
        #expect(!QuickName.matches("Verse", name: ""))
        #expect(!QuickName.matches("Solo", name: "Chorus"))
    }

    @Test("A name already taken gets the next number")
    func numbering() {
        #expect(QuickName.name(for: "Verse", taken: []) == "Verse")
        #expect(QuickName.name(for: "Verse", taken: ["Intro", "Chorus"]) == "Verse")
        #expect(QuickName.name(for: "Verse", taken: ["Verse"]) == "Verse 2")
        #expect(QuickName.name(for: "Verse", taken: ["Verse", "verse 3"]) == "Verse 4")
        #expect(QuickName.name(for: "Chorus", taken: ["Verse", "Verse 2", ""]) == "Chorus")
    }
}
