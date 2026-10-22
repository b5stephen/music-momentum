//
//  MarkerPlacementTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// A wrong snap either leaves slivers of sections or swallows a boundary the
/// user meant to place.
@Suite("Marker placement")
struct MarkerPlacementTests {
    @Test("Snaps to the nearest marker strictly inside the threshold", arguments: [
        (60.4, 1),
        (59.6, 1),
        (60.5, nil),
        (59.5, nil),
        (30.0, nil),
        (90.2, 2),
    ] as [(TimeInterval, Int?)])
    func snaps(time: TimeInterval, index: Int?) {
        #expect(MarkerPlacement.snapIndex(for: time, in: [10, 60, 90], threshold: 0.5) == index)
    }

    @Test("Between two close markers, the nearer wins")
    func nearest() {
        #expect(MarkerPlacement.snapIndex(for: 60.3, in: [60, 60.5], threshold: 0.5) == 1)
        #expect(MarkerPlacement.snapIndex(for: 60.2, in: [60, 60.5], threshold: 0.5) == 0)
        #expect(MarkerPlacement.snapIndex(for: 1, in: []) == nil)
    }

    @Test("Pre-roll moves starts earlier and ends later, within the song")
    func preRoll() {
        #expect(MarkerPlacement.compensatedStart(10) == 10 - MarkerPlacement.startPreRoll)
        #expect(MarkerPlacement.compensatedStart(0.1) == 0)
        #expect(MarkerPlacement.compensatedEnd(10, duration: 200) == 10 + MarkerPlacement.endPostRoll)
        #expect(MarkerPlacement.compensatedEnd(199.9, duration: 200) == 200)
    }
}
