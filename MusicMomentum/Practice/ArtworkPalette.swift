//
//  ArtworkPalette.swift
//  MusicMomentum
//

import CoreGraphics
import MusicKit
import SwiftUI

/// The loaded song's cover colours, which the practice screen is painted in.
/// Apple Music picks `primaryTextColor` to read on `backgroundColor`, so it
/// doubles as the "on" fill, with the background as the glyph on top.
struct ArtworkPalette: Equatable {
    var background: Color
    var foreground: Color
    var isLight: Bool

    init(background: CGColor, foreground: CGColor) {
        self.background = Color(cgColor: background)
        self.foreground = Color(cgColor: foreground)
        isLight = Self.luminance(of: background) > 0.4
    }

    /// `nil` for artwork without colours, which library uploads can be.
    init?(_ artwork: Artwork?) {
        guard let background = artwork?.backgroundColor,
              let foreground = artwork?.primaryTextColor
        else { return nil }
        self.init(background: background, foreground: foreground)
    }

    /// WCAG relative luminance, 0 for black to 1 for white.
    nonisolated static func luminance(of color: CGColor) -> Double {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
              components.count >= 3
        else { return 0 }
        let linear = components.prefix(3).map { channel -> Double in
            let c = Double(channel)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}

extension EnvironmentValues {
    /// Text and glyphs on a solid tint fill. The asset's dark brown everywhere
    /// but the practice screen, where the tint is the cover's text colour.
    @Entry var onAccent: Color = .onAccent
}
