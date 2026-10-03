//
//  ArtworkPalette.swift
//  MusicMomentum
//

import CoreGraphics
import ImageIO
import MusicKit
import SwiftUI

/// The loaded song's colours, which the practice screen is painted in: a
/// dark-to-darker ground in the cover's dominant colour under light text,
/// the way Apple Music's Now Playing gets its depth.
struct ArtworkPalette: Equatable {
    var top: Color
    /// The ground's midpoint, which "on" fills put their glyph in.
    var background: Color
    var bottom: Color
    var foreground: Color

    init(cover: OKLCH) {
        let ground = Self.ground(for: cover)
        top = Color(cgColor: ground.top.cgColor)
        background = Color(cgColor: ground.middle.cgColor)
        bottom = Color(cgColor: ground.bottom.cgColor)
        foreground = Color(cgColor: ground.text.cgColor)
    }

    /// From the colour MusicKit ships with the artwork, to show while the cover
    /// itself is sampled. It's often the cover's border rather than its
    /// subject: Count on Me's is cream, which can only darken to olive.
    /// `nil` for artwork without colours, which library uploads can be.
    init?(_ artwork: Artwork?) {
        guard let color = artwork?.backgroundColor, let cover = OKLCH(color) else { return nil }
        self.init(cover: cover)
    }

    /// From the cover image's dominant colour. `nil` when the image can't be
    /// fetched, as library artwork's device-local `musicKit://` URLs can't.
    static func sampled(from artwork: Artwork) async -> ArtworkPalette? {
        guard let url = artwork.url(width: 64, height: 64),
              url.scheme == "https" || url.scheme == "http",
              let (data, _) = try? await URLSession.shared.data(from: url),
              let rgba = pixels(of: data),
              let cover = dominantColour(rgba: rgba)
        else { return nil }
        return ArtworkPalette(cover: cover)
    }

    nonisolated struct Ground: Equatable {
        var top: OKLCH
        var middle: OKLCH
        var bottom: OKLCH
        var text: OKLCH
    }

    /// Hues are only rich near their sRGB cusp, so a vivid yellow stays bright
    /// while reds, blues and muted covers sit dark; light text reads on all of
    /// them. Yellows warm towards orange as they darken, or they turn olive.
    nonisolated static func ground(for cover: OKLCH) -> Ground {
        let vividness = min(0.97, cover.vividness)
        let isVivid = vividness > 0.6
        let ceiling = isVivid ? min(0.76, max(0.46, OKLCH.cuspLightness(h: cover.h) - 0.08)) : 0.46
        let top = max(0.30, min(cover.l, ceiling))
        let bottom = top - (top - 0.22) * 0.55
        let warmth = (40...110).contains(cover.h) && cover.c > 0.03 ? (isVivid ? 12.0 : 6.0) : 0

        func shade(_ l: Double, hue: Double) -> OKLCH {
            OKLCH(l: l, c: vividness * OKLCH.maxChroma(l: l, h: hue), h: hue)
        }
        return Ground(
            top: shade(top, hue: cover.h),
            middle: shade((top + bottom) / 2, hue: cover.h - warmth / 2),
            bottom: shade(bottom, hue: cover.h - warmth),
            text: OKLCH(l: 0.96, c: min(0.06, cover.c * 0.5), h: cover.h)
        )
    }

    /// The hue that covers the most of the image, weighted by how saturated it
    /// is, so a vivid subject beats a pale border. Mostly grey covers come out
    /// grey. `rgba` is 8-bit RGBA, four bytes a pixel.
    nonisolated static func dominantColour(rgba: [UInt8]) -> OKLCH? {
        struct Bin { var score = 0.0, weight = 0.0, l = 0.0, a = 0.0, b = 0.0 }
        let hueBins = 12
        var bins = Array(repeating: Bin(), count: hueBins + 1)

        for i in stride(from: 0, to: rgba.count - 3, by: 4) where rgba[i + 3] >= 128 {
            let colour = OKLCH(red: Double(rgba[i]) / 255, green: Double(rgba[i + 1]) / 255, blue: Double(rgba[i + 2]) / 255)
            let weight = colour.l < 0.15 || colour.l > 0.95 ? 0.3 : 1
            let isNeutral = colour.c < 0.03
            let index = isNeutral ? hueBins : Int(colour.h / 360 * Double(hueBins)) % hueBins
            bins[index].score += weight * (isNeutral ? 0.02 : colour.c)
            bins[index].weight += weight
            bins[index].l += weight * colour.l
            bins[index].a += weight * colour.c * cos(colour.h * .pi / 180)
            bins[index].b += weight * colour.c * sin(colour.h * .pi / 180)
        }

        // A hue that straddles two bins shouldn't lose to one that doesn't.
        func neighbourhood(_ i: Int) -> [Int] { [(i + hueBins - 1) % hueBins, i, (i + 1) % hueBins] }
        let bestHue = (0..<hueBins).max { a, b in
            neighbourhood(a).reduce(0) { $0 + bins[$1].score } < neighbourhood(b).reduce(0) { $0 + bins[$1].score }
        } ?? 0
        let hueScore = neighbourhood(bestHue).reduce(0) { $0 + bins[$1].score }
        let chosen = hueScore > bins[hueBins].score ? neighbourhood(bestHue) : [hueBins]

        let total = chosen.reduce(Bin()) { sum, i in
            Bin(weight: sum.weight + bins[i].weight, l: sum.l + bins[i].l, a: sum.a + bins[i].a, b: sum.b + bins[i].b)
        }
        guard total.weight > 0 else { return nil }
        let a = total.a / total.weight, b = total.b / total.weight
        return OKLCH(l: total.l / total.weight, c: hypot(a, b), h: atan2(b, a) * 180 / .pi)
    }

    /// The image drawn into a small sRGB bitmap.
    nonisolated static func pixels(of data: Data, side: Int = 32) -> [UInt8]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drawn ? bytes : nil
    }
}

extension EnvironmentValues {
    /// Text and glyphs on a solid tint fill. The asset's dark brown everywhere
    /// but the practice screen, where the tint is the cover's text colour.
    @Entry var onAccent: Color = .onAccent
}
