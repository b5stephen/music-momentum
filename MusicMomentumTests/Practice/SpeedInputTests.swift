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

    @Test("Stepping moves to the next 5% stop, from on or off the grid")
    func stepping() {
        #expect(SpeedInput.stepped(from: 70, up: true, in: range) == 75)
        #expect(SpeedInput.stepped(from: 70, up: false, in: range) == 65)
        #expect(SpeedInput.stepped(from: 72, up: true, in: range) == 75)
        #expect(SpeedInput.stepped(from: 72, up: false, in: range) == 70)
        #expect(SpeedInput.stepped(from: 71, up: false, in: range) == 70)
        #expect(SpeedInput.stepped(from: 74, up: true, in: range) == 75)
    }

    @Test("Stepping stops dead at the ends of the range")
    func steppingClamps() {
        #expect(SpeedInput.stepped(from: 100, up: true, in: range) == 100)
        #expect(SpeedInput.stepped(from: 98, up: true, in: range) == 100)
        #expect(SpeedInput.stepped(from: 30, up: false, in: range) == 30)
        #expect(SpeedInput.stepped(from: 32, up: false, in: range) == 30)
    }

    @Test("A preset is current when the knob reads out its percent")
    func presetMatching() {
        #expect(SpeedInput.preset(matching: 0.75) == 75)
        #expect(SpeedInput.preset(matching: 0.749) == 75)
        #expect(SpeedInput.preset(matching: 0.7449) == nil)
        #expect(SpeedInput.preset(matching: 1.0) == 100)
        #expect(SpeedInput.preset(matching: 0.5) == 50)
    }

    @Test("Between presets, none is current")
    func presetBetween() {
        #expect(SpeedInput.preset(matching: 0.72) == nil)
        #expect(SpeedInput.preset(matching: 0.3) == nil)
    }
}
