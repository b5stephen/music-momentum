//
//  SpeedInputTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Testing
@testable import MusicMomentum

/// A drag or a typed value sets the playback speed directly, so a wrong
/// direction, rounding or stop is a speed nobody asked for.
@Suite("Speed input")
struct SpeedInputTests {
    private let range = 30...100

    @Test("Dragging up raises the speed a percent per few points")
    func dragUp() {
        let step = SpeedInput.pointsPerPercent
        #expect(SpeedInput.dragged(from: 70, travel: step, shift: false, in: range) == 71)
        #expect(SpeedInput.dragged(from: 70, travel: step * 10, shift: false, in: range) == 80)
        #expect(SpeedInput.dragged(from: 70, travel: -step * 10, shift: false, in: range) == 60)
    }

    @Test("Travel rounds to the nearest whole percent")
    func rounding() {
        let step = SpeedInput.pointsPerPercent
        #expect(SpeedInput.dragged(from: 70, travel: step * 0.4, shift: false, in: range) == 70)
        #expect(SpeedInput.dragged(from: 70, travel: step * 0.6, shift: false, in: range) == 71)
        #expect(SpeedInput.dragged(from: 70, travel: -step * 0.6, shift: false, in: range) == 69)
    }

    @Test("Shift moves five percent at a time")
    func shift() {
        let step = SpeedInput.pointsPerPercent
        #expect(SpeedInput.dragged(from: 70, travel: step, shift: true, in: range) == 75)
        #expect(SpeedInput.dragged(from: 70, travel: -step * 2, shift: true, in: range) == 60)
        #expect(SpeedInput.dragged(from: 70, travel: step * 0.4, shift: true, in: range) == 70)
    }

    @Test("The speed stops at either end")
    func clamping() {
        #expect(SpeedInput.dragged(from: 95, travel: 400, shift: false, in: range) == 100)
        #expect(SpeedInput.dragged(from: 35, travel: -400, shift: false, in: range) == 30)
        #expect(SpeedInput.dragged(from: 98, travel: 40, shift: true, in: range) == 100)
        #expect(SpeedInput.dragged(from: 32, travel: -40, shift: true, in: range) == 30)
    }

    @Test("A typed speed parses with or without its percent sign")
    func typedParses() {
        #expect(SpeedInput.typed("75", in: range) == 75)
        #expect(SpeedInput.typed("75%", in: range) == 75)
        #expect(SpeedInput.typed(" 80 ", in: range) == 80)
        #expect(SpeedInput.typed(" 80 % ", in: range) == 80)
        #expect(SpeedInput.typed("72.6", in: range) == 73)
    }

    @Test("A typed speed outside the knob's range is clamped")
    func typedClamps() {
        #expect(SpeedInput.typed("120", in: range) == 100)
        #expect(SpeedInput.typed("5", in: range) == 30)
        #expect(SpeedInput.typed("-50", in: range) == 30)
    }

    @Test("Anything that isn't a number is ignored")
    func typedRejects() {
        #expect(SpeedInput.typed("abc", in: range) == nil)
        #expect(SpeedInput.typed("", in: range) == nil)
        #expect(SpeedInput.typed("%", in: range) == nil)
        #expect(SpeedInput.typed("7 5", in: range) == nil)
        #expect(SpeedInput.typed("nan", in: range) == nil)
        #expect(SpeedInput.typed("inf", in: range) == nil)
    }
}
