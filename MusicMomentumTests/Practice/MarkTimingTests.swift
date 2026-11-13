//
//  MarkTimingTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

@Suite("Mark timing")
struct MarkTimingTests {
    @Test("Playing at full speed backs off the allowance")
    func fullSpeed() {
        let t = MarkTiming.time(playhead: 10, rate: 1, isPlaying: true, duration: 200)
        #expect(abs(t - 9.65) < 1e-9)
    }

    @Test("Playing at 75% backs off less song time")
    func slowed() {
        let t = MarkTiming.time(playhead: 10, rate: 0.75, isPlaying: true, duration: 200)
        #expect(abs(t - 9.7375) < 1e-9)
    }

    @Test("Paused uses the playhead itself")
    func paused() {
        #expect(MarkTiming.time(playhead: 10, rate: 1, isPlaying: false, duration: 200) == 10)
    }

    @Test("Clamps at the start and the end")
    func clamps() {
        #expect(MarkTiming.time(playhead: 0.1, rate: 1, isPlaying: true, duration: 200) == 0)
        #expect(MarkTiming.time(playhead: 250, rate: 1, isPlaying: false, duration: 200) == 200)
        #expect(MarkTiming.time(playhead: 5, rate: 1, isPlaying: false, duration: -3) == 0)
    }

    @Test("A second press inside the window is a repeat")
    func repeatInside() {
        let last = Date(timeIntervalSince1970: 1000)
        #expect(MarkTiming.isRepeat(at: last.addingTimeInterval(0.5), lastMark: last))
        #expect(MarkTiming.isRepeat(at: last, lastMark: last))
    }

    @Test("Outside the window is not a repeat")
    func repeatOutside() {
        let last = Date(timeIntervalSince1970: 1000)
        #expect(!MarkTiming.isRepeat(at: last.addingTimeInterval(1), lastMark: last))
        #expect(!MarkTiming.isRepeat(at: last.addingTimeInterval(5), lastMark: last))
    }

    @Test("No earlier mark, or a clock that went backwards, is not a repeat")
    func repeatEdges() {
        let now = Date(timeIntervalSince1970: 1000)
        #expect(!MarkTiming.isRepeat(at: now, lastMark: nil))
        #expect(!MarkTiming.isRepeat(at: now, lastMark: now.addingTimeInterval(0.5)))
    }
}
