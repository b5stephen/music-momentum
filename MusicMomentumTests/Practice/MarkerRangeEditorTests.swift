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

    @Test("Zoom slider ends are the whole song and the closest zoom")
    func zoomEnds() {
        #expect(MarkerRangeEditor.span(atZoomLevel: 0, duration: 245, minimum: 2) == 245)
        #expect(abs(MarkerRangeEditor.span(atZoomLevel: 1, duration: 245, minimum: 2) - 2) < 1e-9)
    }

    @Test("Zoom level and span round-trip", arguments: [2.0, 5, 30, 120, 245])
    func zoomRoundTrip(span: TimeInterval) {
        let level = MarkerRangeEditor.zoomLevel(span: span, duration: 245, minimum: 2)
        #expect(abs(MarkerRangeEditor.span(atZoomLevel: level, duration: 245, minimum: 2) - span) < 1e-6)
    }

    @Test("A song shorter than the closest zoom doesn't zoom")
    func shortSong() {
        #expect(MarkerRangeEditor.span(atZoomLevel: 1, duration: 1.5, minimum: 2) == 1.5)
        #expect(MarkerRangeEditor.zoomLevel(span: 1.5, duration: 1.5, minimum: 2) == 0)
    }

    @Test("Zoom label reads as a length", arguments: [
        (245.0, "Whole song"),
        (90, "1m 30s"),
        (120, "2m"),
        (30, "30s"),
        (4.5, "4.5s"),
        (5, "5s"),
    ])
    func spanLabel(span: TimeInterval, text: String) {
        #expect(MarkerRangeEditor.spanLabel(span, duration: 245) == text)
    }

    @Test("Slider settles on a nearby detent and leaves the rest alone")
    func detentSnap() {
        #expect(MarkerRangeEditor.snappedSpan(5.1) == 5)
        #expect(MarkerRangeEditor.snappedSpan(7) == 7)
    }
}
