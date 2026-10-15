//
//  PlaybackScrubberMarkerHitTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// A tap in the marker lane seeks to whatever this picks, so a wrong pick
/// drops the playhead at the wrong marker.
@Suite("Marker a tap in the lane jumps to")
struct PlaybackScrubberMarkerHitTests {
    // 100pt over 100s: one point per second.
    private let markers: [PlaybackScrubber.Marker] = [
        .init(id: "intro", start: 0, end: 20),
        .init(id: "cue", start: 15, end: nil),
        .init(id: "solo", start: 40, end: 70),
        .init(id: "bend", start: 50, end: 55),
        .init(id: "blip", start: 75, end: 76),
        .init(id: "a", start: 90, end: nil),
        .init(id: "b", start: 96, end: nil),
    ]

    private func hit(_ x: CGFloat) -> AnyHashable? {
        PlaybackScrubber.marker(at: x, width: 100, duration: 100, in: markers)?.id
    }

    @Test("Picks by position", arguments: [
        (2.0, "intro"),
        (14.0, "cue"),
        (25.0, "cue"),
        (30.0, nil),
        (41.0, "solo"),
        (52.0, "bend"),
        (64.0, "solo"),
        (72.0, "blip"),
        (78.0, "blip"),
        (80.0, "a"),
        (92.0, "a"),
        (94.0, "b"),
    ] as [(CGFloat, String?)])
    func picks(x: CGFloat, id: String?) {
        #expect(hit(x) == id.map(AnyHashable.init))
    }

    @Test("Nothing to hit without a duration")
    func noDuration() {
        #expect(PlaybackScrubber.marker(at: 5, width: 100, duration: 0, in: markers) == nil)
    }
}
