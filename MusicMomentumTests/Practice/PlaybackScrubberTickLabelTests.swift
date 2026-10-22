//
//  PlaybackScrubberTickLabelTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// A label running into the next tick reads as that marker's name.
@Suite("Room for each tick's label")
struct PlaybackScrubberTickLabelTests {
    @Test("Each label runs to just short of the next tick, the last to the end")
    func room() {
        let widths = PlaybackScrubber.tickLabelWidths(xs: [0, 60, 200], width: 300)
        #expect(widths == [54, 134, 100])
    }

    @Test("A label without room to read is dropped")
    func crowded() {
        let widths = PlaybackScrubber.tickLabelWidths(xs: [100, 120, 200, 290], width: 300)
        #expect(widths == [nil, 74, 84, nil])
    }

    @Test("No ticks, no labels")
    func empty() {
        #expect(PlaybackScrubber.tickLabelWidths(xs: [], width: 300).isEmpty)
    }
}
