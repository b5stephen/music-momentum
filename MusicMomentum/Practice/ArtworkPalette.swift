//
//  ArtworkPalette.swift
//  MusicMomentum
//

import CoreGraphics
import ImageIO
import MusicKit
import SwiftUI

/// The loaded song's colours, which the practice screen is painted in: the
/// cover's own colours blurred into a mesh and darkened under light text, the
/// way Apple Music's Now Playing is.
struct ArtworkPalette: Equatable {
    /// 3×3, row by row from the top left.
    var mesh: [Color]
    var shadow: Color
    /// What "on" fills put their glyph in.
    var background: Color
    var foreground: Color
    /// Light glass washes out on a bright ground, so controls there take a
    /// smoked fill instead.
    var isBright: Bool

    private init(ground: Ground) {
        assert(ground.mesh.count == 9, "The mesh is 3×3")
        mesh = ground.mesh.map { Color(cgColor: $0.cgColor) }
        shadow = Color(cgColor: ground.shadow.cgColor)
        background = Color(cgColor: ground.glyph.cgColor)
        foreground = Color(cgColor: ground.text.cgColor)
        isBright = ground.mesh[3...5].map(\.l).reduce(0, +) / 3 > 0.6
    }

    init(cover: OKLCH) {
        self.init(ground: Self.ground(for: Regions(average: cover, mesh: Array(repeating: cover, count: 9))))
    }

    /// From the colour MusicKit ships with the artwork, to show while the cover
    /// itself is sampled. It's often the cover's border rather than its
    /// average: Count on Me's is cream where the cover is mostly gold.
    /// `nil` for artwork without colours, which library uploads can be.
    init?(_ artwork: Artwork?) {
        guard let color = artwork?.backgroundColor, let cover = OKLCH(color) else { return nil }
        self.init(cover: cover)
    }

    /// From the cover image. `nil` when it can't be fetched.
    static func sampled(from song: Song) async -> ArtworkPalette? {
        guard let url = await song.downloadableArtworkURL(side: 64),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let ground = await ground(sampling: data)
        else { return nil }
        return ArtworkPalette(ground: ground)
    }

    private nonisolated static let sampleSide = 32

    /// Off the main actor, as decoding and averaging the cover is the one
    /// part of this that does real work.
    @concurrent
    private nonisolated static func ground(sampling data: Data) async -> Ground? {
        guard let rgba = pixels(of: data, side: sampleSide),
              let regions = regions(rgba: rgba, side: sampleSide)
        else { return nil }
        return ground(for: regions)
    }

    nonisolated struct Regions: Equatable {
        var average: OKLCH
        /// 3×3, row by row from the top left.
        var mesh: [OKLCH]
    }

    nonisolated struct Ground: Equatable {
        var mesh: [OKLCH]
        /// What the bottom of the screen darkens towards.
        var shadow: OKLCH
        var glyph: OKLCH
        var text: OKLCH
    }

    /// Each region keeps only a quarter of its own colour, as Apple's ground
    /// is nearly one colour, and none is less colourful than the average: a
    /// cover's pale parts, darkened, show through as grey patches.
    nonisolated static func ground(for regions: Regions) -> Ground {
        let average = shade(regions.average)
        return Ground(
            mesh: regions.mesh.enumerated().map { index, region in
                let point = mix(average, shade(region), by: 0.25)
                // A near-grey point's hue is noise, so it takes the cover's.
                let h = point.c < 0.02 ? average.h : point.h
                let row = rows[index / 3]
                return OKLCH(l: point.l + row.lift, c: max(point.c, average.c), h: h - row.warmth * warmth(h))
            },
            shadow: OKLCH(l: 0.2, c: average.c, h: average.h - 2 * warmth(average.h)),
            glyph: OKLCH(l: min(0.45, average.l * 0.85), c: average.c, h: average.h - warmth(average.h)),
            text: OKLCH(l: 0.96, c: min(0.06, average.c * 0.5), h: average.h)
        )
    }

    /// Each row of the mesh, top to bottom: the lightness added, as Apple's
    /// ground is darker along the top edge, where the title sits, and
    /// brightest in the middle, which is what makes it glow; and how far
    /// yellows warm, as Apple's gold deepens to amber towards the bottom.
    private nonisolated static let rows: [(lift: Double, warmth: Double)] = [(-0.07, 1), (0.04, 1), (-0.03, 2.5)]

    /// Fitted to Apple Music: a step darker, so a bright cover stays bright,
    /// and a third more saturated relative to what sRGB allows, so it stays
    /// vivid. Pale and grey covers stop darker, as light text on a light grey
    /// ground is unreadable and looks washed out.
    nonisolated static func shade(_ colour: OKLCH) -> OKLCH {
        let ceiling = 0.5 + 0.3 * colour.vividness
        let l = min(ceiling, max(min(colour.l, 0.25), colour.l - 0.12))
        return OKLCH(l: l, c: min(1, colour.vividness * 1.3) * OKLCH.maxChroma(l: l, h: colour.h), h: colour.h)
    }

    /// Degrees a hue turns towards orange as it darkens: yellows only, which
    /// otherwise read as olive.
    private nonisolated static func warmth(_ h: Double) -> Double {
        8 * max(0, 1 - abs(h - 85) / 20)
    }

    /// Mixed in sRGB, as a blur would mix them.
    private nonisolated static func mix(_ a: OKLCH, _ b: OKLCH, by t: Double) -> OKLCH {
        let (x, y) = (a.srgb, b.srgb)
        return OKLCH(red: x.red + (y.red - x.red) * t, green: x.green + (y.green - x.green) * t, blue: x.blue + (y.blue - x.blue) * t)
    }

    /// The cover's average colour, and the averages of a 3×3 grid whose edge
    /// cells are a quarter wide and the middle one half, so each matches a
    /// mesh point's surroundings. `rgba` is a `side`×`side` premultiplied
    /// 8-bit RGBA bitmap from the top row down, as `pixels(of:side:)` draws it.
    nonisolated static func regions(rgba: [UInt8], side: Int) -> Regions? {
        guard side >= 8, rgba.count >= side * side * 4 else { return nil }
        func band(_ i: Int) -> Int { i < side / 4 ? 0 : i < side - side / 4 ? 1 : 2 }
        var cells = Array(repeating: Blend(), count: 9)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                guard rgba[i + 3] >= 128 else { continue }
                let alpha = Double(rgba[i + 3])
                cells[band(y) * 3 + band(x)].add(
                    red: Double(rgba[i]) / alpha,
                    green: Double(rgba[i + 1]) / alpha,
                    blue: Double(rgba[i + 2]) / alpha
                )
            }
        }
        guard let whole = cells.reduce(Blend(), +).colour else { return nil }
        return Regions(average: whole, mesh: cells.map { $0.colour ?? whole })
    }

    /// Running totals for one stretch of the cover. Lightness is averaged as
    /// stored (gamma-encoded), as Apple's is: a linear average comes out
    /// paler. Hue and chroma are weighted towards colourful pixels, so Count
    /// on Me's cream road doesn't turn its gold yellow-green, while a busy
    /// cover's colours still blend.
    private nonisolated struct Blend {
        var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
        var a = 0.0, b = 0.0, weight = 0.0

        mutating func add(red: Double, green: Double, blue: Double) {
            self.red += red
            self.green += green
            self.blue += blue
            count += 1
            let lab = OKLCH.oklab(red: red, green: green, blue: blue)
            let w = 0.02 + hypot(lab.a, lab.b)
            a += w * lab.a
            b += w * lab.b
            weight += w
        }

        static func + (x: Blend, y: Blend) -> Blend {
            Blend(
                red: x.red + y.red, green: x.green + y.green, blue: x.blue + y.blue, count: x.count + y.count,
                a: x.a + y.a, b: x.b + y.b, weight: x.weight + y.weight
            )
        }

        /// `nil` with no pixels to average.
        var colour: OKLCH? {
            guard count > 0 else { return nil }
            let l = OKLCH(red: red / count, green: green / count, blue: blue / count).l
            return OKLCH(l: l, a: a / weight, b: b / weight)
        }
    }

    /// The image drawn into a small sRGB bitmap.
    nonisolated static func pixels(of data: Data, side: Int) -> [UInt8]? {
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
    /// The fill of settled controls (the speed wheel's rim, Practice's chips)
    /// on a bright cover, where the usual light glass washes out. `nil` keeps
    /// the light glass.
    @Entry var smokedFill: Color? = nil
}
