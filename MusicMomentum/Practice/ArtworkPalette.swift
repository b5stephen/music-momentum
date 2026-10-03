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
    /// What "on" fills put their glyph in.
    var background: Color
    var foreground: Color

    init(ground: Ground) {
        mesh = ground.mesh.map { Color(cgColor: $0.cgColor) }
        background = Color(cgColor: ground.glyph.cgColor)
        foreground = Color(cgColor: ground.text.cgColor)
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

    /// From the cover image. Library artwork's URLs are device-local
    /// (`musicKit://`) and can't be fetched, so a library song is sampled from
    /// its catalog counterpart's cover. `nil` when neither can be fetched.
    static func sampled(from song: Song) async -> ArtworkPalette? {
        guard let artwork = await fetchableArtwork(of: song),
              let url = artwork.url(width: 64, height: 64),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let rgba = pixels(of: data),
              let regions = regions(rgba: rgba, side: 32)
        else { return nil }
        return ArtworkPalette(ground: ground(for: regions))
    }

    private static func fetchableArtwork(of song: Song) async -> Artwork? {
        func isFetchable(_ artwork: Artwork?) -> Bool {
            ["https", "http"].contains(artwork?.url(width: 64, height: 64)?.scheme)
        }
        if isFetchable(song.artwork) { return song.artwork }
        guard let catalogID = song.catalogID else { return nil }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(catalogID))
        let artwork = try? await request.response().items.first?.artwork
        return isFetchable(artwork) ? artwork : nil
    }

    nonisolated struct Regions: Equatable {
        var average: OKLCH
        /// 3×3, row by row from the top left.
        var mesh: [OKLCH]
    }

    nonisolated struct Ground: Equatable {
        var mesh: [OKLCH]
        var glyph: OKLCH
        var text: OKLCH
    }

    /// Fitted to Apple Music: lightness is compressed to 0.1–0.62 but chroma
    /// is kept, so a cover darkens into its richest shade rather than turning
    /// pale or grey. Each region is pulled halfway to the average, so the mesh
    /// varies the way a heavy blur does without one corner taking over.
    nonisolated static func ground(for regions: Regions) -> Ground {
        func shade(_ colour: OKLCH) -> OKLCH {
            OKLCH(l: min(0.62, 0.105 + 0.56 * colour.l), c: colour.c, h: colour.h)
        }
        let average = shade(regions.average)
        return Ground(
            mesh: regions.mesh.map { mix(average, shade($0)) },
            glyph: OKLCH(l: average.l * 0.85, c: average.c * 0.85, h: average.h),
            text: OKLCH(l: 0.96, c: min(0.06, average.c * 0.5), h: average.h)
        )
    }

    /// Halfway between, in sRGB, as a blur would mix them.
    private nonisolated static func mix(_ a: OKLCH, _ b: OKLCH) -> OKLCH {
        let (x, y) = (a.srgb, b.srgb)
        return OKLCH(red: (x.red + y.red) / 2, green: (x.green + y.green) / 2, blue: (x.blue + y.blue) / 2)
    }

    /// The whole cover's average colour, and the averages of a 3×3 grid whose
    /// edge cells are a quarter wide and the middle one half, so each matches
    /// a mesh point's surroundings. Averaged as stored (gamma-encoded), as
    /// Apple's are: a linear average comes out paler. `rgba` is a `side`×`side`
    /// 8-bit RGBA bitmap from the top row down.
    nonisolated static func regions(rgba: [UInt8], side: Int) -> Regions? {
        guard side >= 4, rgba.count >= side * side * 4 else { return nil }
        func average(rows: Range<Int>, columns: Range<Int>) -> OKLCH? {
            var (r, g, b, n) = (0.0, 0.0, 0.0, 0.0)
            for y in rows {
                for x in columns {
                    let i = (y * side + x) * 4
                    guard rgba[i + 3] >= 128 else { continue }
                    r += Double(rgba[i]); g += Double(rgba[i + 1]); b += Double(rgba[i + 2]); n += 1
                }
            }
            return n > 0 ? OKLCH(red: r / n / 255, green: g / n / 255, blue: b / n / 255) : nil
        }
        guard let whole = average(rows: 0..<side, columns: 0..<side) else { return nil }
        let bounds = [0, side / 4, side - side / 4, side]
        let mesh = (0..<3).flatMap { row in
            (0..<3).map { column in
                average(rows: bounds[row]..<bounds[row + 1], columns: bounds[column]..<bounds[column + 1]) ?? whole
            }
        }
        return Regions(average: whole, mesh: mesh)
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
