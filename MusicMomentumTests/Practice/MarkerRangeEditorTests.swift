//
//  MarkerRangeEditorTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// A bad snap drops the handle somewhere other than where the user let go,
/// and nothing on screen says so.
@Suite("Handle snapping")
struct MarkerRangeEditorTests {
    @Test("Snaps onto a playhead within tolerance")
    func snapsNearby() {
        let landing = MarkerRangeEditor.handleTime(70.1, playhead: 70.3, tolerance: 0.25, in: 0...200)
        #expect(landing.time == 70.3)
        #expect(landing.snapped)
    }

    @Test("Leaves the touch alone outside tolerance")
    func ignoresFarPlayhead() {
        let landing = MarkerRangeEditor.handleTime(70.0, playhead: 70.3, tolerance: 0.25, in: 0...200)
        #expect(landing.time == 70.0)
        #expect(!landing.snapped)
    }

    @Test("Never snaps past where the handle may go")
    func respectsRange() {
        // The end handle can't come within a clip's minimum length of the start.
        let landing = MarkerRangeEditor.handleTime(80.1, playhead: 79.9, tolerance: 0.5, in: 80...200)
        #expect(landing.time == 80.1)
        #expect(!landing.snapped)
    }

    @Test("Clamps to the range without a playhead")
    func clampsWithoutPlayhead() {
        #expect(MarkerRangeEditor.handleTime(-3, playhead: nil, tolerance: 1, in: 0...200).time == 0)
        #expect(MarkerRangeEditor.handleTime(250, playhead: nil, tolerance: 1, in: 0...200).time == 200)
    }

    @Test("Minor ticks divide each labelled interval evenly", arguments: [1.0, 2, 5, 10, 15, 30, 60, 120, 300, 600])
    func minorTicksDivideMajor(major: TimeInterval) {
        let ratio = major / MarkerRangeEditor.minorTickInterval(for: major)
        #expect(abs(ratio - ratio.rounded()) < 1e-9)
    }
}
