//
//  SpeedKnobGeometry.swift
//  MusicMomentum
//

import SwiftUI

/// Where everything in the speed knob sits for a given diameter. Shapes scale
/// with the knob but text keeps its size, so as the knob shrinks it drops
/// detail rather than scaling the scale's numbers into an unreadable blur:
/// the scale ring costs the same few points of radius at any size, and a
/// small knob drawn like a big one was mostly ring.
nonisolated struct SpeedKnobGeometry: Equatable {
    enum Detail: Equatable {
        /// Numbers every 10, ticks every 5, knurling, and a caption over the readout.
        case full
        /// Ticks every 10, numbers only at the stops, coarser knurling.
        case medium
        /// Lit ticks alone show the level.
        case small
    }

    static let minPercent = 30
    static let maxPercent = 100
    /// Screen angles run 0° at 3 o'clock, clockwise, so the gap is centred on 90°.
    static let sweep: Double = 284
    static let startAngle: Double = 90 + (360 - sweep) / 2
    static let degreesPerPercent = sweep / Double(maxPercent - minPercent)

    let diameter: CGFloat
    /// The scale's numbers, which follow Dynamic Type.
    let labelSize: CGFloat
    let detail: Detail

    init(diameter: CGFloat, labelSize: CGFloat = 11) {
        self.diameter = diameter
        self.labelSize = labelSize
        // Numbers grown by Dynamic Type would outgrow the full ring, so they
        // keep to the stops instead, and past that they'd clip at the frame's
        // corners, so they go.
        if diameter >= 240, labelSize <= 14 {
            detail = .full
        } else if diameter >= 190, labelSize <= 16 {
            detail = .medium
        } else {
            detail = .small
        }
    }

    var radius: CGFloat { diameter / 2 }

    /// The stop numbers sit low beside the gap, where the frame's corners
    /// leave them room, so only the full scale needs a ring wide enough for
    /// numbers.
    private var ringWidth: CGFloat {
        switch detail {
        case .full: 20 + 1.8 * labelSize
        case .medium: 26
        case .small: 15
        }
    }

    var skirtRadius: CGFloat { radius - ringWidth }
    var tickInnerRadius: CGFloat { skirtRadius + (detail == .small ? 7 : 9) }
    var savedDotRadius: CGFloat { skirtRadius + 4.5 }

    /// A little bigger on a small knob so the readout keeps a legible size,
    /// but no bigger: at three quarters the pointer shrank to a stub.
    var capRadius: CGFloat { skirtRadius * (detail == .small ? 0.68 : 0.66) }
    /// Smaller against the cap on a small knob, where "100%" at full size
    /// ran nearly edge to edge and crowded the cap's rim.
    var readoutSize: CGFloat { max(28, capRadius * (detail == .small ? 0.6 : 0.72)) }
    var showsCaption: Bool { capRadius >= 55 }

    var tickStep: Int { detail == .full ? 5 : 10 }

    func tickLength(major: Bool) -> CGFloat {
        switch detail {
        case .full: major ? 11 : 7
        case .medium: 8
        case .small: 6
        }
    }

    func isLabelled(_ percent: Int) -> Bool {
        switch detail {
        case .full: percent.isMultiple(of: 10)
        case .medium: percent == Self.minPercent || percent == Self.maxPercent
        case .small: false
        }
    }

    func labelRadius(major: Bool) -> CGFloat {
        tickInnerRadius + tickLength(major: major) + 0.9 * labelSize
    }

    /// Knurling on the skirt's edge, spaced so it never closes into a grey band.
    var knurlCount: Int {
        switch detail {
        case .full: 120
        case .medium: 72
        case .small: 0
        }
    }

    var pointerWidth: CGFloat { max(4, diameter * 0.018) }

    /// How far below the centre the back-to-saved glyph sits: under the
    /// readout, clear of the cap's rim.
    var resetGlyphDrop: CGFloat { capRadius * 0.62 }
    var resetGlyphSize: CGFloat { max(13, readoutSize * 0.38) }

    /// Where a tap at `location` in the knob's frame lands: the nearest drawn
    /// tick, or the saved speed's dot, which needn't sit on one. Only the
    /// scale ring counts, and only within half a tick's spacing, so a smaller
    /// knob with fewer ticks has fewer places to land and a tap deep in the
    /// gap between the stops lands nowhere.
    func tapPercent(at location: CGPoint, saved: Int? = nil) -> Int? {
        let dx = location.x - radius
        let dy = location.y - radius
        let distance = hypot(dx, dy)
        guard distance >= skirtRadius, distance <= radius else { return nil }

        let angle = atan2(dy, dx) * 180 / .pi
        let tolerance = Double(tickStep) * Self.degreesPerPercent / 2
        let ticks = stride(from: Self.minPercent, through: Self.maxPercent, by: tickStep)
        return (Array(ticks) + [saved].compactMap { $0 })
            .map { percent in
                (percent, abs((angle - Self.angle(for: Double(percent)).degrees).remainder(dividingBy: 360)))
            }
            .filter { $0.1 <= tolerance }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// How near the saved dot, in percent, a click on the scale has to be to
    /// land on it rather than the 5% grid, since it's often off the grid.
    static let savedDotReach: Double = 1

    /// Where a click at `location` lands on the Mac, which the hover pointer
    /// shows before the click. The scale is the coarse zone: the nearest 5%,
    /// whether or not a small knob draws that tick, or the saved dot when
    /// it's right on it. The skirt is the fine one: the whole percent under
    /// the pointer, or with `toGrid` (⇧) the nearest 5% as everywhere else.
    /// Just past a stop lands on it, deep in the gap or in the cap on nothing.
    func pointedPercent(at location: CGPoint, saved: Int? = nil, toGrid: Bool = false) -> Int? {
        let dx = location.x - radius
        let dy = location.y - radius
        let distance = hypot(dx, dy)
        guard distance > capRadius, distance <= radius else { return nil }

        var offset = (atan2(dy, dx) * 180 / .pi - Self.startAngle).truncatingRemainder(dividingBy: 360)
        if offset < 0 { offset += 360 }
        // Past the halfway point of the gap is just before the bottom stop.
        if offset > Self.sweep + (360 - Self.sweep) / 2 { offset -= 360 }
        let raw = Double(Self.minPercent) + offset / Self.degreesPerPercent

        let range = Self.minPercent...Self.maxPercent
        guard raw >= Double(range.lowerBound) - 1, raw <= Double(range.upperBound) + 1 else { return nil }
        guard distance >= skirtRadius else { return SpeedInput.snapped(raw, toGrid: toGrid, in: range) }
        if let saved, abs(Double(saved) - raw) <= Self.savedDotReach { return saved }
        return SpeedInput.snapped(raw, toGrid: true, in: range)
    }

    static func angle(for percent: Double) -> Angle {
        .degrees(startAngle + (percent - Double(minPercent)) * degreesPerPercent)
    }

    static func point(from centre: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: centre.x + radius * cos(angle.radians),
            y: centre.y + radius * sin(angle.radians)
        )
    }
}
