//
//  PracticeLayout.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Sizes the loaded practice screen for the space it's given. As the window
/// gets shorter things give way in order: the gaps close, then the controls
/// shrink, and only then the wheel. Shrinking only the wheel, as the screen
/// first did, left a small dial under full-size controls.
///
/// Before the wheel has given up much, the screen goes compact: a one-line
/// header, a transport row of even buttons, and Mark in the clip row instead
/// of on a caption line. That frees enough height to hand the wheel most of
/// its size back.
nonisolated struct PracticeLayout: Equatable {
    /// The song and its speed on the left, playback on the right.
    var isWide: Bool
    var isCompact: Bool
    var wheelDiameter: CGFloat
    /// The play button's circle. Compact, the button is a bare glyph in a
    /// 44pt frame and this is that frame.
    var playSize: CGFloat
    var transportGlyph: CGFloat
    /// The loop button's fill when it's on. Its touch area stays 44pt.
    var loopFill: CGFloat
    var coverSide: CGFloat
    var wheelGap: CGFloat
    var scrubberGap: CGFloat
    var transportGap: CGFloat

    /// Heights the layout can't work out from a stage: text, which follows
    /// Dynamic Type, and the headers, which wrap long titles.
    struct Heights: Equatable {
        /// Title and artist beside the cover.
        var titleBlock: CGFloat
        /// Title, artist and chips above the wide layout's wheel.
        var wideHeader: CGFloat
        var chipRow: CGFloat
        var compactHeader: CGFloat
        var scrubber: CGFloat
        var pillRow: CGFloat
        /// The loop caption and Mark under the clips.
        var captionRow: CGFloat

        static let standard = Heights(
            titleBlock: 54, wideHeader: 110, chipRow: 30, compactHeader: 44,
            scrubber: 56, pillRow: 36, captionRow: 52
        )
    }

    init(size: CGSize, heights: Heights) {
        self = Self.isWide(size) ? Self.wide(size, heights) : Self.stacked(size, heights)
    }

    /// Wider than tall, and with room for the transport beside the wheel.
    static func isWide(_ size: CGSize) -> Bool {
        size.width > size.height && size.width >= 700
    }

    /// The top and bottom padding round the screen's content.
    static let verticalPadding: CGFloat = 22
    static let wideHeaderGap: CGFloat = 20

    /// Grows with the window up to what the wheel needs, and never takes so
    /// much that the transport's five controls are squeezed.
    static func wideLeadingWidth(_ width: CGFloat) -> CGFloat {
        min(380, width * 0.46)
    }

    /// The stacked wheel's size before height limits it: 260 across a phone,
    /// growing to 280 by the time the window is twice as wide as the wheel.
    /// It used to step from 260 to 280 at 600pt, which a dragged iPad window
    /// showed as a jump.
    static func wheelCap(width: CGFloat) -> CGFloat {
        min(width - 130, 260 + 20 * unit((width - 440) / 160))
    }

    /// On a roomy iPad window everything grows a little past the phone size.
    /// A 320pt wheel alone dwarfed phone-sized controls; at 300 the play
    /// button and cover grow with it.
    private static let roomyWheel: CGFloat = 300

    // MARK: - Stages

    /// Give-way stages run from -1 (roomy) through 0 (the phone layout) to 4
    /// (everything at its floor): 0–1 closes the gaps, 1–2 shrinks the
    /// controls, 2–4 shrinks the wheel.
    private static let lowestStage: CGFloat = -1
    private static let highestStage: CGFloat = 4
    /// Halfway through the wheel's first shrink. Waiting until the wheel had
    /// given up its whole first step left it looking small for too long.
    private static let compactStage: CGFloat = 2.5

    private static func stacked(_ size: CGSize, _ heights: Heights) -> Self {
        let cap = wheelCap(width: size.width)
        let roomy = max(cap, min(size.width - 130, roomyWheel))
        // Phone widths stay at the phone layout however tall they are.
        let reach = min(unit((size.width - 440) / 160), unit((roomy - 260) / 40))
        let fits = { (layout: Self) in layout.stackedHeight(heights) <= size.height }

        let full = solve(from: -reach, cap: cap, roomy: roomy, isWide: false, isCompact: false, fits: fits)
        guard full.stage > compactStage else { return full.layout }
        // Compact frees so much that the stage falls back, but not into roomy:
        // a bigger-than-phone wheel over a compact transport looks wrong.
        return solve(from: 0, cap: cap, roomy: cap, isWide: false, isCompact: true, fits: fits).layout
    }

    private static func wide(_ size: CGSize, _ heights: Heights) -> Self {
        let column = wideLeadingWidth(size.width) - 48
        let cap = min(column, 280)
        let roomy = min(column, roomyWheel)
        let available = size.height - verticalPadding
        let fits = { (layout: Self) in
            heights.wideHeader + wideHeaderGap + layout.wheelDiameter <= available
                && layout.playerHeight(heights) <= available
        }

        let full = solve(from: -unit((column - 260) / 40), cap: cap, roomy: roomy, isWide: true, isCompact: false, fits: fits)
        guard full.stage > compactStage else { return full.layout }
        return solve(from: 0, cap: cap, roomy: cap, isWide: true, isCompact: true, fits: fits).layout
    }

    /// The lowest stage that fits. Everything shrinks as the stage rises, so
    /// a bisection finds it; nothing fitting gives the floor, and the screen
    /// scrolls.
    private static func solve(
        from lower: CGFloat,
        cap: CGFloat,
        roomy: CGFloat,
        isWide: Bool,
        isCompact: Bool,
        fits: (Self) -> Bool
    ) -> (stage: CGFloat, layout: Self) {
        let make = { stage in Self(stage: stage, cap: cap, roomy: roomy, isWide: isWide, isCompact: isCompact) }
        if fits(make(lower)) { return (lower, make(lower)) }
        if !fits(make(highestStage)) { return (highestStage, make(highestStage)) }
        var (low, high) = (lower, highestStage)
        for _ in 0..<20 {
            let middle = (low + high) / 2
            if fits(make(middle)) { high = middle } else { low = middle }
        }
        return (high, make(high))
    }

    private init(stage: CGFloat, cap: CGFloat, roomy: CGFloat, isWide: Bool, isCompact: Bool) {
        func at(_ values: [CGFloat]) -> CGFloat { Self.interpolate(values, at: stage) }
        //                      roomy  phone  gaps  controls  wheel  floor
        let play =         at([76,     68,    68,   54,       54,    54])
        let glyph =        at([26,     24,    24,   22,       22,    22])
        let cover =        at([72,     64,    64,   48,       48,    48])
        wheelGap =         at([40,     30,    14,   14,       14,    14])
        transportGap =     at([28,     24,    16,   16,       16,    16])
        scrubberGap =      at([16,     14,    10,   10,       10,    10])
        wheelDiameter =    at([roomy,  cap,   cap,  cap,      min(cap, 210), min(cap, 150)])

        self.isWide = isWide
        self.isCompact = isCompact
        if isCompact {
            playSize = 44
            transportGlyph = 22
            loopFill = 40
            coverSide = 44
        } else {
            playSize = play
            transportGlyph = glyph
            // Scales with play so the two filled circles keep their proportion.
            loopFill = 44 * play / 68
            coverSide = cover
        }
    }

    /// Piecewise-linear across the stages, one value per whole stage.
    private static func interpolate(_ values: [CGFloat], at stage: CGFloat) -> CGFloat {
        let position = min(max(stage - lowestStage, 0), CGFloat(values.count - 1))
        let index = min(Int(position), values.count - 2)
        let fraction = position - CGFloat(index)
        return values[index] + (values[index + 1] - values[index]) * fraction
    }

    private static func unit(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    // MARK: - Heights

    private func stackedHeight(_ heights: Heights) -> CGFloat {
        let header = isCompact
            ? heights.compactHeader
            : max(coverSide, heights.titleBlock) + 12 + heights.chipRow
        return Self.verticalPadding + header + 2 * wheelGap + wheelDiameter + playerHeight(heights)
    }

    private func playerHeight(_ heights: Heights) -> CGFloat {
        heights.scrubber + scrubberGap
            + playSize + transportGap
            + heights.pillRow
            + (isCompact ? 0 : heights.captionRow)
    }
}

#if canImport(UIKit)
extension PracticeLayout.Heights {
    /// The text heights at a Dynamic Type size, with the measured headers.
    @MainActor
    init(dynamicTypeSize: DynamicTypeSize, titleBlock: CGFloat, wideHeader: CGFloat) {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        func line(_ style: UIFont.TextStyle) -> CGFloat {
            UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).lineHeight.rounded(.up)
        }
        let footnote = UIFontMetrics(forTextStyle: .footnote)
        self.init(
            titleBlock: titleBlock,
            wideHeader: wideHeader,
            chipRow: line(.footnote) + 12,
            compactHeader: max(44, line(.headline) + 2 + line(.subheadline)),
            // The labels tuck 4pt up under the bar's 44pt touch area.
            scrubber: 44 + line(.caption1) - 4,
            pillRow: footnote.scaledValue(for: 32, compatibleWith: traits) + 4,
            captionRow: 8 + max(44, line(.footnote))
        )
    }
}
#endif
