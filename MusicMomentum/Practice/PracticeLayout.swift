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
/// Once the gaps have closed, the volume row goes, before the controls
/// shrink: the side buttons do the same job. Wide, the wheel's column is
/// usually what's short, and the volume row only goes when it's the reason
/// anything gives way.
///
/// Before the wheel has given up much, the screen goes compact: a one-line
/// header, a transport row of even buttons, and Play | Loop at the bottom
/// instead of over the timeline. That frees enough height to hand the wheel most of
/// its size back.
nonisolated struct PracticeLayout: Equatable {
    /// The song and its speed on the left, playback on the right.
    var isWide: Bool
    var isCompact: Bool
    var showsVolume: Bool
    var wheelDiameter: CGFloat
    /// The play button's circle. Compact, the button is a bare glyph in a
    /// 44pt frame and this is that frame.
    var playSize: CGFloat
    var transportGlyph: CGFloat
    /// The height of the transport's end capsules, A·B and Add marker.
    /// Their touch areas stay at least 44pt.
    var loopFill: CGFloat
    var coverSide: CGFloat
    /// Stacked, the header holds this from the top and the player holds
    /// `bottomMargin` from the bottom, and the gaps round the wheel take
    /// what's spare. Centring the stack put the cover anywhere from 6 to 80pt
    /// down a phone. It closes with the gaps, so only a short screen moves it.
    var topMargin: CGFloat
    var wheelGap: CGFloat
    var scrubberGap: CGFloat
    /// Above the scrubber's touch area, whose lane sits only 8pt down it: on
    /// the wide layout's panel the lane looked pressed against the top edge.
    /// It closes with the gaps, so an iPhone SE keeps its full wheel.
    var scrubberTop: CGFloat
    /// Wide, how far the playback panel can reach below the columns' middle
    /// before it's too close to a landscape phone's tab bar.
    var widePanelReach: CGFloat = 0
    var transportGap: CGFloat
    /// Wide, the most height the playback column can spread to: clear of a
    /// landscape phone's tab bar, with `widePlayerBreathing` above and below.
    var widePlayerSpace: CGFloat = 0

    /// Heights the layout can't work out from a stage: text, which follows
    /// Dynamic Type, and the headers, which wrap long titles.
    struct Heights: Equatable {
        /// Title and artist beside the cover.
        var titleBlock: CGFloat
        /// Title and artist beside the wide layout's cover, measured at the
        /// width its largest cover leaves. Measuring the whole header fed the
        /// cover back into the stage that sizes it: at some window heights a
        /// smaller cover let the stage fall, the bigger cover pushed it back
        /// up, and the screen re-laid out every frame without settling.
        var wideTitleBlock: CGFloat
        var compactHeader: CGFloat
        /// The Play | Loop control and the gap under it. Compact, the
        /// control goes in the bottom row instead.
        var modeRow: CGFloat
        /// Either mode's timeline: they're the same height, so the
        /// transport holds still when the mode switches.
        var scrubber: CGFloat
        /// Compact, Play | Loop.
        var compactRow: CGFloat
        /// The loop caption, still 44pt tall from when Mark shared it: the
        /// give-way stages were tuned with it.
        var captionRow: CGFloat

        static let standard = Heights(
            titleBlock: 54, wideTitleBlock: 54, compactHeader: 44,
            modeRow: 38, scrubber: 60, compactRow: 40, captionRow: 50
        )
    }

    /// `tabBarInset` is the inset a landscape phone's floating tab bar
    /// reserves along the bottom edge; only the wide layout's playback
    /// column has to clear it, as the columns centre on the whole screen.
    init(size: CGSize, heights: Heights, tabBarInset: CGFloat = 0) {
        self = Self.isWide(size) ? Self.wide(size, heights, tabBarInset) : Self.stacked(size, heights)
    }

    /// Wider than tall, and with room for the transport beside the wheel.
    static func isWide(_ size: CGSize) -> Bool {
        size.width > size.height && size.width >= 700
    }

    /// The top and bottom padding round the wide layout's columns, which
    /// centre in the window.
    static let verticalPadding: CGFloat = 22
    /// Height a solved layout leaves spare. SwiftUI rounds each fractional
    /// size to the pixel grid, so a layout solved to fill a window exactly
    /// came out a fraction of a point too tall, and the screen scrolled.
    static let roundingSlack: CGFloat = 2
    /// Stacked, the bottom of the player's distance from the bottom edge.
    static let bottomMargin: CGFloat = 16
    /// A little over the tallest iPhone's screen once its bars are taken off.
    static let maxStackedHeight: CGFloat = 860
    static let wideHeaderGap: CGFloat = 20
    /// Between the wide header's cover and title and its buttons.
    static let wideHeaderSpacing: CGFloat = 12
    /// The roomy stage's cover. Titles are measured beside it, so a cover
    /// shrinking can't unwrap one and feed back into the layout.
    static let maxCover: CGFloat = 72
    /// Without it, the timeline met the top of a landscape phone and the
    /// bottom row met its tab bar.
    static let widePlayerBreathing: CGFloat = 16
    /// Between the wide playback column's glass panel and its rows.
    static let widePanelPadding: CGFloat = 14
    /// The wide layout's top padding.
    static let wideTopPadding: CGFloat = 6
    static let volumeRow: CGFloat = 44
    /// Between the Play | Loop control and the timeline it switches.
    static let modeGap: CGFloat = 4
    /// The system's thumbless slider track, near enough the scrubber's.
    private static let volumeTrack: CGFloat = 6
    /// How far down its touch area the scrubber's bar ends.
    private static let scrubberBarBottom: CGFloat = 41
    /// The header stops growing here: any larger and a title wraps over
    /// several lines and pushes the wheel down, and the buttons' glyphs
    /// spill out of their 44pt glass.
    static let headerTypeLimit = DynamicTypeSize.xxxLarge

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
    /// The gaps have closed and the controls are next.
    private static let volumeStage: CGFloat = 1

    private static func stacked(_ size: CGSize, _ heights: Heights) -> Self {
        let cap = wheelCap(width: size.width)
        let roomy = max(cap, min(size.width - 130, roomyWheel))
        // Phone widths stay at the phone layout however tall they are.
        let reach = min(unit((size.width - 440) / 160), unit((roomy - 260) / 40))
        let fits = { (layout: Self) in layout.stackedHeight(heights) <= size.height - roundingSlack }

        let full = solve(from: -reach, cap: cap, roomy: roomy, isWide: false, isCompact: false, showsVolume: true, fits: fits)
        guard full.stage > volumeStage else { return full.layout }
        // Held at the stage it went at, so the controls don't grow back into
        // the room it leaves.
        let bare = solve(from: volumeStage, cap: cap, roomy: roomy, isWide: false, isCompact: false, showsVolume: false, fits: fits)
        guard bare.stage > compactStage else { return bare.layout }
        // Compact frees so much that the stage falls back, but not into roomy:
        // a bigger-than-phone wheel over a compact transport looks wrong.
        return solve(from: 0, cap: cap, roomy: cap, isWide: false, isCompact: true, showsVolume: false, fits: fits).layout
    }

    private static func wide(_ size: CGSize, _ heights: Heights, _ tabBarInset: CGFloat) -> Self {
        let column = wideLeadingWidth(size.width) - 48
        let cap = min(column, 280)
        let roomy = min(column, roomyWheel)
        let available = size.height - verticalPadding - roundingSlack
        // Centred, the playback column reaches half its height below the
        // middle, which `tabBarInset` has dropped; it has to end clear of the
        // tab bar.
        let middle = wideTopPadding + (size.height - verticalPadding) / 2 + tabBarInset / 2
        let playerSpace = min(size.height - verticalPadding, 2 * (size.height - 8 - middle))
            - roundingSlack - 2 * widePlayerBreathing - 2 * widePanelPadding
        let fits = { (layout: Self) in
            layout.wideHeaderHeight(heights) + wideHeaderGap + layout.wheelDiameter <= available
                && layout.playerHeight(heights) <= playerSpace
        }

        func layout(showsVolume: Bool) -> Self {
            let full = solve(from: -unit((column - 260) / 40), cap: cap, roomy: roomy, isWide: true, isCompact: false, showsVolume: showsVolume, fits: fits)
            guard full.stage > compactStage else { return full.layout }
            return solve(from: 0, cap: cap, roomy: cap, isWide: true, isCompact: true, showsVolume: showsVolume, fits: fits).layout
        }
        var with = layout(showsVolume: true)
        var without = layout(showsVolume: false)
        let reach = size.height - 8 - middle - widePlayerBreathing - roundingSlack / 2
        with.widePlayerSpace = playerSpace
        without.widePlayerSpace = playerSpace
        with.widePanelReach = reach
        without.widePanelReach = reach
        var same = without
        same.showsVolume = true
        // At the floor nothing fits either way, and the two come out equal.
        return same == with && with.playerHeight(heights) <= playerSpace ? with : without
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
        showsVolume: Bool,
        fits: (Self) -> Bool
    ) -> (stage: CGFloat, layout: Self) {
        let make = { stage in
            Self(stage: stage, cap: cap, roomy: roomy, isWide: isWide, isCompact: isCompact, showsVolume: showsVolume)
        }
        if fits(make(lower)) { return (lower, make(lower)) }
        if !fits(make(highestStage)) { return (highestStage, make(highestStage)) }
        var (low, high) = (lower, highestStage)
        for _ in 0..<20 {
            let middle = (low + high) / 2
            if fits(make(middle)) { high = middle } else { low = middle }
        }
        return (high, make(high))
    }

    private init(stage: CGFloat, cap: CGFloat, roomy: CGFloat, isWide: Bool, isCompact: Bool, showsVolume: Bool) {
        func at(_ values: [CGFloat]) -> CGFloat { Self.interpolate(values, at: stage) }
        //                      roomy  phone  gaps  controls  wheel  floor
        let play =         at([76,     68,    68,   54,       54,    54])
        let glyph =        at([26,     24,    24,   22,       22,    22])
        let cover =        at([72,     64,    64,   48,       48,    48])
        topMargin =        at([16,     16,    6,    6,        6,     6])
        wheelGap =         at([40,     30,    14,   14,       14,    14])
        transportGap =     at([28,     24,    16,   16,       16,    16])
        scrubberGap =      at([16,     14,    10,   10,       10,    10])
        scrubberTop =      at([8,      8,     0,    0,        0,     0])
        wheelDiameter =    at([roomy,  cap,   cap,  cap,      min(cap, 210), min(cap, 150)])

        self.isWide = isWide
        self.isCompact = isCompact
        self.showsVolume = showsVolume
        if isCompact {
            playSize = 44
            transportGlyph = 22
            loopFill = 40
            coverSide = 44
        } else {
            playSize = play
            transportGlyph = glyph
            // Scales with play so the capsules keep their proportion to it.
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

    // MARK: - Crease

    /// The gap either side of the wheel when a crease splits the stack.
    static let creaseWheelGap: CGFloat = 14
    /// The smallest wheel the stack's own give-way allows.
    private static let wheelFloor: CGFloat = 150

    /// A bent foldable's crease across the stack: the header and wheel take
    /// the half above it and the player the half below, so nothing sits in
    /// the fold. `above` is the height above the crease and `below` the
    /// height below it less the bottom margin. Nil when either half is too
    /// short, and the stack carries on across the crease.
    func split(above: CGFloat, below: CGFloat, width: CGFloat, heights: Heights) -> Self? {
        guard !isWide, playerHeight(heights) <= below - Self.roundingSlack else { return nil }
        let header = isCompact ? heights.compactHeader : max(coverSide, heights.titleBlock, 44)
        let room = above - topMargin - header - 2 * Self.creaseWheelGap - Self.roundingSlack
        let diameter = min(max(wheelDiameter, Self.wheelCap(width: width)), room)
        guard diameter >= Self.wheelFloor else { return nil }
        var split = self
        split.wheelDiameter = diameter
        return split
    }

    // MARK: - Heights

    func stackedHeight(_ heights: Heights) -> CGFloat {
        let header = isCompact
            ? heights.compactHeader
            : max(coverSide, heights.titleBlock, 44)
        return topMargin + Self.bottomMargin + header + 2 * wheelGap + wheelDiameter + playerHeight(heights)
    }

    /// The wide header's cover or title, whichever is taller, over its
    /// 44pt buttons.
    func wideHeaderHeight(_ heights: Heights) -> CGFloat {
        max(coverSide, heights.wideTitleBlock) + Self.wideHeaderSpacing + 44
    }

    /// The transport sits midway between the scrubber's bar and the
    /// volume's, so the two bars read as a pair framing it. The time labels
    /// make the scrubber's side of the transport the taller.
    func volumeGap(_ heights: Heights) -> CGFloat {
        heights.scrubber - Self.scrubberBarBottom + scrubberGap
            - (Self.volumeRow - Self.volumeTrack) / 2
    }

    func playerHeight(_ heights: Heights) -> CGFloat {
        scrubberTop + (isCompact ? 0 : heights.modeRow) + heights.scrubber + scrubberGap
            + playSize + transportGap
            + (showsVolume ? volumeGap(heights) + Self.volumeRow : 0)
            + (isCompact ? heights.compactRow : heights.captionRow)
    }
}

#if canImport(UIKit)
extension PracticeLayout.Heights {
    /// The text heights at a Dynamic Type size, with the measured headers.
    @MainActor
    init(dynamicTypeSize: DynamicTypeSize, titleBlock: CGFloat, wideTitleBlock: CGFloat) {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let titleTraits = UITraitCollection(
            preferredContentSizeCategory: UIContentSizeCategory(min(dynamicTypeSize, PracticeLayout.headerTypeLimit))
        )
        func line(_ style: UIFont.TextStyle, _ traits: UITraitCollection = traits) -> CGFloat {
            UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).lineHeight.rounded(.up)
        }
        self.init(
            titleBlock: titleBlock,
            wideTitleBlock: wideTitleBlock,
            compactHeader: max(44, line(.headline, titleTraits) + 2 + line(.subheadline, titleTraits)),
            modeRow: max(34, line(.subheadline, titleTraits) + 8) + PracticeLayout.modeGap,
            // The times tuck 4pt up under the bar's touch area.
            scrubber: PlaybackScrubber.barHeight + line(.caption1) - 4,
            compactRow: max(40, line(.subheadline, titleTraits) + 12),
            captionRow: 6 + max(44, line(.subheadline) + 16)
        )
    }
}
#endif
