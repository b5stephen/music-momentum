//
//  SectionBlockLayoutTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// A tap or drag on the block row becomes a loop through this, so a wrong
/// mapping loops the wrong part of the song.
@Suite("Section blocks")
struct SectionBlockLayoutTests {
    // 100s across 112pt with three 6pt gaps: 100pt of blocks, a point a second.
    private let layout = SectionBlockLayout(
        sections: [0...10, 10...40, 40...90, 90...100],
        width: 118,
        gap: 6,
        minimumWidth: 6
    )

    @Test("Widths are proportional to length")
    func proportional() {
        #expect(layout.frames == [0...10, 16...46, 52...102, 108...118])
    }

    @Test("A sliver of a section is held to the minimum, the rest share what's left")
    func minimumWidth() {
        let widths = SectionBlockLayout.widths(lengths: [1, 49, 50], available: 100, minimum: 6)
        #expect(widths[0] == 6)
        #expect(abs(widths[1] - 94 * 49 / 99) < 0.0001)
        #expect(abs(widths.reduce(0, +) - 100) < 0.0001)
    }

    @Test("A zero-length section still gets a block")
    func zeroLength() {
        let widths = SectionBlockLayout.widths(lengths: [50, 0, 50], available: 106, minimum: 6)
        #expect(widths == [50, 6, 50])
    }

    @Test("Equal widths when the minimums alone don't fit")
    func tooNarrow() {
        #expect(SectionBlockLayout.widths(lengths: [1, 99], available: 10, minimum: 6) == [5, 5])
    }

    @Test("One block for a song without markers")
    func wholeSong() {
        let layout = SectionBlockLayout(sections: [0...200], width: 300)
        #expect(layout.frames == [0...300])
    }

    @Test("Touches map to blocks, splitting gaps down the middle", arguments: [
        (-20.0, 0), (5.0, 0), (12.9, 0), (13.1, 1), (46.0, 1), (60.0, 2), (105.1, 3), (500.0, 3),
    ] as [(CGFloat, Int)])
    func hit(x: CGFloat, index: Int) {
        #expect(layout.index(at: x) == index)
    }

    @Test("Times map into their own block", arguments: [
        (0.0, 0.0), (5.0, 5.0), (10.0, 16.0), (25.0, 31.0), (40.0, 52.0), (95.0, 113.0), (100.0, 118.0), (150.0, 118.0),
    ] as [(TimeInterval, CGFloat)])
    func position(time: TimeInterval, x: CGFloat) {
        #expect(layout.x(for: time) == x)
    }

    @Test("A drag loops every section between its ends, either way round")
    func dragRange() {
        #expect(layout.range(from: 1, to: 1) == 10...40)
        #expect(layout.range(from: 1, to: 2) == 10...90)
        #expect(layout.range(from: 3, to: 0) == 0...100)
    }

    @Test("A loop of whole sections is recognised as its blocks")
    func matching() {
        #expect(layout.blocks(matching: 10...40) == 1...1)
        #expect(layout.blocks(matching: 10...90) == 1...2)
        #expect(layout.blocks(matching: 0...100) == 0...3)
        #expect(layout.blocks(matching: 12...40) == nil)
        #expect(layout.blocks(matching: 10...41) == nil)
    }

    @Test("A zero-length section at a boundary isn't swept into a match")
    func matchingSkipsSlivers() {
        let layout = SectionBlockLayout(sections: [0...10, 10...10, 10...20], width: 100)
        #expect(layout.blocks(matching: 0...10) == 0...0)
        #expect(layout.blocks(matching: 10...20) == 2...2)
        #expect(layout.blocks(matching: 0...20) == 0...2)
    }

    @Test("The looped part of each block")
    func activeSpan() {
        #expect(layout.activeSpan(of: 1, loop: 10...40) == 16...46)
        #expect(layout.activeSpan(of: 2, loop: 30...50) == 52...62)
        #expect(layout.activeSpan(of: 0, loop: 30...50) == nil)
        #expect(layout.activeSpan(of: 3, loop: 30...50) == nil)
    }

    @Test("A run of blocks is named by its ends")
    func names() {
        let names = ["Intro", "Verse", "Chorus", "Outro"]
        #expect(SectionBlockLayout.name(of: 2...2, names: names) == "Chorus")
        #expect(SectionBlockLayout.name(of: 1...3, names: names) == "Verse – Outro")
    }
}
