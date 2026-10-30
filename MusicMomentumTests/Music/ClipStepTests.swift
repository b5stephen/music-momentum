//
//  ClipStepTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// The mini player's previous and next buttons are disabled when this says
/// `nil`, so an off-by-one here is a button that does nothing or a clip skipped.
@Suite("Stepping between clips")
struct ClipStepTests {
    private let starts: [TimeInterval] = [10, 40, 90]

    private func target(
        _ direction: ClipStep.Direction, at playhead: TimeInterval, loop: [Range<TimeInterval>] = []
    ) -> Int? {
        ClipStep.target(starts: starts, loop: loop, playhead: playhead, direction: direction)
    }

    @Test("Next is the first clip that starts after the playhead")
    func nextFromPlayhead() {
        #expect(target(.next, at: 0) == 0)
        #expect(target(.next, at: 10) == 1)
        #expect(target(.next, at: 55) == 2)
    }

    @Test("There is no next clip after the last one starts")
    func noNext() {
        #expect(target(.next, at: 90) == nil)
        #expect(target(.next, at: 200) == nil)
    }

    @Test("Previous is the last clip that starts before the playhead")
    func previousFromPlayhead() {
        #expect(target(.previous, at: 50) == 1)
        #expect(target(.previous, at: 95) == 2)
    }

    @Test("Just inside a clip, previous goes to the clip before, not its own start")
    func previousWithinGrace() {
        #expect(target(.previous, at: 40) == 0)
        #expect(target(.previous, at: 40.5) == 0)
        #expect(target(.previous, at: 41.5) == 1)
    }

    @Test("There is no previous clip at or before the first")
    func noPrevious() {
        #expect(target(.previous, at: 0) == nil)
        #expect(target(.previous, at: 10.5) == nil)
        #expect(target(.previous, at: 10) == nil)
    }

    @Test("Without clips there is nowhere to go")
    func noClips() {
        #expect(ClipStep.target(starts: [], loop: [], playhead: 30, direction: .next) == nil)
        #expect(ClipStep.target(starts: [], loop: [], playhead: 30, direction: .previous) == nil)
    }

    @Test("Looping a clip steps from that clip, however far in the playhead is")
    func loopingAClip() {
        let middle = [40.0..<55.0]
        #expect(target(.previous, at: 50, loop: middle) == 0)
        #expect(target(.next, at: 50, loop: middle) == 2)
        #expect(target(.previous, at: 40.2, loop: middle) == 0)
    }

    @Test("Looping the first or last clip has no way past it")
    func loopingAnEnd() {
        #expect(target(.previous, at: 12, loop: [10.0..<20.0]) == nil)
        #expect(target(.next, at: 95, loop: [90.0..<100.0]) == nil)
    }

    @Test("A chain steps from the clip the playhead is in")
    func chain() {
        let chain = [10.0..<20.0, 90.0..<100.0]
        #expect(target(.next, at: 15, loop: chain) == 1)
        #expect(target(.previous, at: 95, loop: chain) == 1)
    }

    @Test("A playhead outside the chain steps from the last clip it has passed")
    func outsideChain() {
        let chain = [10.0..<20.0, 90.0..<100.0]
        #expect(target(.next, at: 50, loop: chain) == 1)
        #expect(target(.previous, at: 50, loop: chain) == nil)
        #expect(target(.previous, at: 5, loop: chain) == nil)
    }
}
