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
            #expect(full.tickPercent(at: tap(full, at: Double(percent))) == percent)
        }
    }

    @Test("A tap between ticks lands on the nearer one")
    func betweenTicks() {
        #expect(full.tickPercent(at: tap(full, at: 72)) == 70)
        #expect(full.tickPercent(at: tap(full, at: 73)) == 75)
    }

    @Test("A small knob only lands on the ticks it draws")
    func smallKnob() {
        #expect(small.detail == .small)
        #expect(small.tickPercent(at: tap(small, at: 75)) != 75)
        #expect(small.tickPercent(at: tap(small, at: 74)) == 70)
        #expect(small.tickPercent(at: tap(small, at: 76)) == 80)
    }

    @Test("A tap just past a stop lands on it, deep in the gap on nothing")
    func gap() {
        #expect(full.tickPercent(at: tap(full, at: 101)) == 100)
        #expect(full.tickPercent(at: tap(full, at: 29)) == 30)
        let bottom = CGPoint(x: full.radius, y: full.radius + full.tickInnerRadius)
        #expect(full.tickPercent(at: bottom) == nil)
    }

    @Test("Only the scale ring takes taps, not the skirt or cap")
    func ringOnly() {
        let onSkirt = SpeedKnobGeometry.point(
            from: CGPoint(x: full.radius, y: full.radius),
            radius: full.skirtRadius - 2,
            angle: SpeedKnobGeometry.angle(for: 70)
        )
        #expect(full.tickPercent(at: onSkirt) == nil)
        #expect(full.tickPercent(at: CGPoint(x: full.radius, y: full.radius)) == nil)
    }
}
