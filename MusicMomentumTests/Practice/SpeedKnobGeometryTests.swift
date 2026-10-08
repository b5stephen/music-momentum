//
//  SpeedKnobGeometryTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Testing
@testable import MusicMomentum

/// A tap on the scale jumps to the tick under it, so a tap read against the
/// wrong tick, or against one the knob doesn't draw, sets a speed nobody chose.
@Suite("Speed knob geometry")
struct SpeedKnobGeometryTests {
    private let full = SpeedKnobGeometry(diameter: 260)
    private let small = SpeedKnobGeometry(diameter: 150)

    /// On the ticks, at `percent`'s angle.
    private func tap(_ geometry: SpeedKnobGeometry, at percent: Double) -> CGPoint {
        SpeedKnobGeometry.point(
            from: CGPoint(x: geometry.radius, y: geometry.radius),
            radius: geometry.tickInnerRadius + 3,
            angle: SpeedKnobGeometry.angle(for: percent)
        )
    }

    @Test("A tap on a tick lands on it")
    func onTick() {
        #expect(full.detail == .full)
        for percent in stride(from: 30, through: 100, by: 5) {
            #expect(full.tapPercent(at: tap(full, at: Double(percent))) == percent)
        }
    }

    @Test("A tap between ticks lands on the nearer one")
    func betweenTicks() {
        #expect(full.tapPercent(at: tap(full, at: 72)) == 70)
        #expect(full.tapPercent(at: tap(full, at: 73)) == 75)
    }

    @Test("A small knob only lands on the ticks it draws")
    func smallKnob() {
        #expect(small.detail == .small)
        #expect(small.tapPercent(at: tap(small, at: 75)) != 75)
        #expect(small.tapPercent(at: tap(small, at: 74)) == 70)
        #expect(small.tapPercent(at: tap(small, at: 76)) == 80)
    }

    @Test("A tap just past a stop lands on it, deep in the gap on nothing")
    func gap() {
        #expect(full.tapPercent(at: tap(full, at: 101)) == 100)
        #expect(full.tapPercent(at: tap(full, at: 29)) == 30)
        let bottom = CGPoint(x: full.radius, y: full.radius + full.tickInnerRadius)
        #expect(full.tapPercent(at: bottom) == nil)
    }

    @Test("The saved dot takes taps between ticks, and the ticks keep the rest")
    func savedDot() {
        #expect(full.tapPercent(at: tap(full, at: 72), saved: 72) == 72)
        #expect(full.tapPercent(at: tap(full, at: 71.2), saved: 72) == 72)
        #expect(full.tapPercent(at: tap(full, at: 70.8), saved: 72) == 70)
        #expect(full.tapPercent(at: tap(full, at: 74), saved: 72) == 75)
        #expect(small.tapPercent(at: tap(small, at: 77), saved: 75) == 75)
        #expect(small.tapPercent(at: tap(small, at: 72), saved: 75) == 70)
    }

    @Test("Only the scale ring takes taps, not the skirt or cap")
    func ringOnly() {
        let onSkirt = SpeedKnobGeometry.point(
            from: CGPoint(x: full.radius, y: full.radius),
            radius: full.skirtRadius - 2,
            angle: SpeedKnobGeometry.angle(for: 70)
        )
        #expect(full.tapPercent(at: onSkirt) == nil)
        #expect(full.tapPercent(at: CGPoint(x: full.radius, y: full.radius)) == nil)
    }
}
