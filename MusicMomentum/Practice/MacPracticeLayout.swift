//
//  MacPracticeLayout.swift
//  MusicMomentum
//

import CoreGraphics

/// The sizes of Practice's Mac layout, decided from Practice's own size and
/// not the window's: with the sidebar showing, a 1180pt window leaves
/// Practice narrower than a 1000pt one with it collapsed.
nonisolated struct MacPracticeLayout: Equatable {
    var isWide: Bool

    /// The wide layout's widths (margins, cover, a title column, the knob and
    /// the gaps between) leave a title like "Slow Burn Avenue" about 280pt;
    /// below that it truncates. It also needs the knob, a header and the
    /// timeline in view without scrolling.
    static let wideMinimum = CGSize(width: 900, height: 560)

    init(size: CGSize) {
        isWide = size.width >= Self.wideMinimum.width && size.height >= Self.wideMinimum.height
    }

    var coverSide: CGFloat { isWide ? 172 : 112 }
    var titleSize: CGFloat { isWide ? 34 : 24 }
    var knobDiameter: CGFloat { isWide ? 284 : 216 }
    /// Three quarters of the knob, so it reads as belonging to it.
    var volumeWidth: CGFloat { knobDiameter * 0.75 }
    var sideMargin: CGFloat { isWide ? 48 : 32 }
    var bottomMargin: CGFloat { isWide ? 44 : 32 }
    var sectionGap: CGFloat { isWide ? 44 : 32 }
    var heroGap: CGFloat { isWide ? 56 : 28 }
    var columnGap: CGFloat { isWide ? 26 : 20 }
}
