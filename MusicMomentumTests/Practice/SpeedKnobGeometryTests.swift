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

    // MARK: - Pointed clicks (Mac)

    /// Midway across the skirt, between the cap and the scale.
    private func onSkirt(_ geometry: SpeedKnobGeometry, at percent: Double) -> CGPoint {
        SpeedKnobGeometry.point(
            from: CGPoint(x: geometry.radius, y: geometry.radius),
            radius: (geometry.capRadius + geometry.skirtRadius) / 2,
            angle: SpeedKnobGeometry.angle(for: percent)
        )
    }

    @Test("A click on the skirt lands on the whole percent under it, ticks or not")
    func pointedOnSkirt() {
        #expect(full.pointedPercent(at: onSkirt(full, at: 72.6)) == 73)
        #expect(full.pointedPercent(at: onSkirt(full, at: 74.4)) == 74)
        #expect(full.pointedPercent(at: onSkirt(full, at: 75.2)) == 75)
        #expect(small.pointedPercent(at: onSkirt(small, at: 66.3)) == 66)
    }

    @Test("Shift lands a click on the skirt on the nearest 5%")
    func pointedGrid() {
        #expect(full.pointedPercent(at: onSkirt(full, at: 72.6), toGrid: true) == 75)
        #expect(full.pointedPercent(at: onSkirt(full, at: 72.4), toGrid: true) == 70)
    }

    @Test("A click on the scale lands on the nearest 5%, shift or not")
    func pointedOnScale() {
        #expect(full.pointedPercent(at: tap(full, at: 72.6)) == 75)
        #expect(full.pointedPercent(at: tap(full, at: 72.4)) == 70)
        #expect(full.pointedPercent(at: tap(full, at: 81)) == 80)
        #expect(full.pointedPercent(at: tap(full, at: 81), toGrid: true) == 80)
        #expect(small.pointedPercent(at: tap(small, at: 74)) == 75)
    }

    @Test("The saved dot takes a click on the scale right on it, and only there")
    func pointedSaved() {
        #expect(full.pointedPercent(at: tap(full, at: 71.4), saved: 72) == 72)
        #expect(full.pointedPercent(at: tap(full, at: 70.7), saved: 72) == 70)
        #expect(full.pointedPercent(at: tap(full, at: 71.4)) == 70)
        #expect(full.pointedPercent(at: onSkirt(full, at: 71.4), saved: 72) == 71)
    }

    @Test("A click on the skirt just past a stop lands on it, deep in the gap or in the cap on nothing")
    func pointedLimits() {
        #expect(full.pointedPercent(at: onSkirt(full, at: 100.6)) == 100)
        #expect(full.pointedPercent(at: onSkirt(full, at: 29.4)) == 30)
        let bottom = CGPoint(x: full.radius, y: full.radius + (full.capRadius + full.skirtRadius) / 2)
        #expect(full.pointedPercent(at: bottom) == nil)
        #expect(full.pointedPercent(at: CGPoint(x: full.radius, y: full.radius)) == nil)
        let inCap = CGPoint(x: full.radius, y: full.radius - full.capRadius + 2)
        #expect(full.pointedPercent(at: inCap) == nil)
    }
}
