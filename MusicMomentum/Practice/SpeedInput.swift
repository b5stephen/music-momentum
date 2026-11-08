//
//  SpeedInput.swift
//  MusicMomentum
//

import CoreGraphics
import Foundation

/// How a mouse turns movement and typing into a speed, away from the views so
/// the rounding and the stops can be tested.
nonisolated enum SpeedInput {
    /// About Logic's knobs: a short stroke covers a few percent and the whole
    /// range is one long drag down a Mac window.
    static let pointsPerPercent: CGFloat = 4

    /// Each step a held ⇧ takes, in percent, and the grid it lands on.
    static let shiftStep = 5

    /// The whole percent to land on `travel` points above where the drag
    /// began, from `start`. Plain, a percent per `pointsPerPercent`; with ⇧,
    /// `shiftStep` percent per that distance, on the 5% grid. Stops dead at
    /// either end.
    static func dragged(from start: Double, travel: CGFloat, shift: Bool, in range: ClosedRange<Int>) -> Int {
        let steps = Double(travel / pointsPerPercent)
        return snapped(start + steps * Double(shift ? shiftStep : 1), toGrid: shift, in: range)
    }

    /// `raw` as a whole percent, or with ⇧ the nearest stop on the 5% grid,
    /// so a snapped drag lands on 75 rather than 77 whatever it began on.
    static func snapped(_ raw: Double, toGrid: Bool, in range: ClosedRange<Int>) -> Int {
        let grid = Double(shiftStep)
        let rounded = toGrid ? (raw / grid).rounded() * grid : raw.rounded()
        return min(max(Int(rounded), range.lowerBound), range.upperBound)
    }

    /// The speed a typed readout asks for, clamped to `range`, or `nil` for
    /// anything that isn't a number ("75", "75%" and " 80 " all are).
    static func typed(_ text: String, in range: ClosedRange<Int>) -> Int? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%") { trimmed.removeLast() }
        guard let value = Double(trimmed.trimmingCharacters(in: .whitespaces)), value.isFinite else { return nil }
        return Int(min(max(value, Double(range.lowerBound)), Double(range.upperBound)).rounded())
    }

    /// The next stop on the 5% grid from `percent`, up or down, clamped to
    /// `range`. Off the grid it lands on the grid rather than adding five
    /// (72 goes to 75 or 70, not 77).
    static func stepped(from percent: Int, up: Bool, in range: ClosedRange<Int>) -> Int {
        let grid = shiftStep
        let next = up
            ? (percent / grid + 1) * grid
            : (percent - 1) / grid * grid
        return min(max(next, range.lowerBound), range.upperBound)
    }

    /// The menu bar's one-click speeds, in percent.
    static let presets = [50, 60, 75, 90, 100]

    /// The Speed menu's and right-click menus' speeds: every 5% from 50,
    /// where the menu bar panel's segmented row has room for only five.
    static let menuSpeeds = Array(stride(from: 50, through: 100, by: shiftStep))

    /// The preset `rate` is showing as, matched on the whole percent the knob
    /// reads out (0.749 is 75%), or `nil` between presets.
    static func preset(matching rate: Double) -> Int? {
        let percent = Int((rate * 100).rounded())
        return presets.first { $0 == percent }
    }
}
