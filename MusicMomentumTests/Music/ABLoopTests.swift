//
//  ABLoopTests.swift
//  MusicMomentumTests
//

import Testing
@testable import MusicMomentum

@Suite("A·B loop")
struct ABLoopTests {
    @Test("A then B loops between them")
    func inOrder() {
        #expect(ABLoop.close(from: 76, to: 87, duration: 238) == 76..<87)
    }

    @Test("B before A still loops between the two")
    func reversed() {
        #expect(ABLoop.close(from: 87, to: 76, duration: 238) == 76..<87)
    }

    @Test("A B pressed together gets the shortest playable loop")
    func tooShort() {
        let range = ABLoop.close(from: 40, to: 40.1, duration: 238)
        #expect(range.lowerBound == 40)
        #expect(range.upperBound - range.lowerBound == SongMarker.minimumClipLength)
    }

    @Test("The shortest loop at the song's end moves A back rather than run past it")
    func atTheEnd() {
        let range = ABLoop.close(from: 237.9, to: 238, duration: 238)
        #expect(range.upperBound == 238)
        #expect(range.upperBound - range.lowerBound == SongMarker.minimumClipLength)
    }

    @Test("Ends are held inside the song")
    func clamped() {
        #expect(ABLoop.close(from: -1, to: 300, duration: 238) == 0..<238)
    }

    @Test("Only a closed loop has a range")
    func range() {
        #expect(ABLoop.started(12).range == nil)
        #expect(ABLoop.closed(12..<20).range == 12..<20)
    }

    @Test("A scratch loop is the one range the ticker keeps to") @MainActor
    func scratchRanges() {
        #expect(Loop.scratch(12..<20).ranges == [12..<20])
        #expect(Loop.wholeSong.ranges.isEmpty)
        #expect(Loop.scratch(12..<20).segments.isEmpty)
        #expect(Loop.scratch(12..<20).isScratch)
        #expect(!Loop.wholeSong.isScratch)
    }
}
