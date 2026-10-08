//
//  PlaybackScrubberTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// The name under the timeline is how you tell where a marker is mid-song,
/// so a wrong one reads as a misplaced marker.
@Suite("Section name under the timeline")
struct PlaybackScrubberTests {
    private let markers: [PlaybackScrubber.Marker] = [
        .init(id: 0, name: "Intro", start: 0, end: 20),
        .init(id: 1, name: "Verse", start: 20, end: nil),
        .init(id: 2, name: "Solo", start: 60, end: 90),
        .init(id: 3, name: "Bend", start: 70, end: 75),
        .init(id: 4, name: "Lick", start: 80, end: nil),
        .init(id: 5, name: "", start: 100, end: 110),
    ]

    @Test("Names the point just passed, then the clip, then nothing", arguments: [
        (5.0, "Intro"),
        (20.0, "Verse"),
        (22.9, "Verse"),
        (23.0, nil),
        (59.9, nil),
        (60.0, "Solo"),
        (72.0, "Bend"),
        (75.0, "Solo"),
        (81.0, "Lick"),
        (83.0, "Solo"),
        (90.0, nil),
        (105.0, nil),
    ] as [(TimeInterval, String?)])
    func names(position: TimeInterval, name: String?) {
        #expect(PlaybackScrubber.sectionName(at: position, in: markers, pointNameDuration: 3) == name)
    }

    @Test("A point holds its name for the time it's given")
    func pointDuration() {
        #expect(PlaybackScrubber.sectionName(at: 25, in: markers, pointNameDuration: 6) == "Verse")
        #expect(PlaybackScrubber.sectionName(at: 25, in: markers, pointNameDuration: 3) == nil)
    }

    @Test("Before a point is reached it isn't named")
    func beforePoint() {
        #expect(PlaybackScrubber.sectionName(at: 19.9, in: markers, pointNameDuration: 3) == "Intro")
    }
}
