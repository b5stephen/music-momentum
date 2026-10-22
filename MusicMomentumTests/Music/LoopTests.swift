//
//  LoopTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// Tested against `Loop.step` rather than the controller, so nothing here
/// needs a music player.
@Suite("Looping a range")
struct LoopTests {
    private func step(at time: TimeInterval, wasInside: Bool) -> Loop.Step {
        Loop.step(start: 60, end: 90, time: time, wasInside: wasInside)
    }

    @Test("Inside the range, playback carries on")
    func inside() {
        #expect(step(at: 60, wasInside: false) == .inside)
        #expect(step(at: 89.9, wasInside: true) == .inside)
    }

    @Test("Playing out of the end jumps back to the start")
    func wraps() {
        #expect(step(at: 90, wasInside: true) == .jump(to: 60))
        // Up to a poll late, or a short range swallowed by a seek's settling.
        #expect(step(at: 95, wasInside: true) == .jump(to: 60))
    }

    @Test("Outside without having just played out of it, the playhead is left alone")
    func waits() {
        // Without the wait, sitting past the end after a jump would read as
        // "the loop just finished" and the playhead could never leave.
        #expect(step(at: 120, wasInside: false) == .wait)
        #expect(step(at: 30, wasInside: false) == .wait)
        // Before the start it waits for playback to run in, even from inside.
        #expect(step(at: 30, wasInside: true) == .wait)
    }

    @Test("An empty or backwards range never loops")
    func degenerate() {
        #expect(Loop.step(start: 60, end: 60, time: 60, wasInside: true) == .wait)
        #expect(Loop.step(start: 90, end: 60, time: 95, wasInside: true) == .wait)
    }

    @Test("A range matches a section with the same bounds")
    func matches() {
        let loop = Loop.range(start: 60, end: 90)
        #expect(loop.matches(start: 60, end: 90))
        #expect(!loop.matches(start: 60, end: 91))
        #expect(!Loop.wholeSong.matches(start: 0, end: 200))
    }
}
