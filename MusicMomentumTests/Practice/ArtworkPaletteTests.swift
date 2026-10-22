//
//  ArtworkPaletteTests.swift
//  MusicMomentumTests
//

import Foundation
import MusicKit
import Testing
@testable import MusicMomentum

/// The practice screen's ground is derived, not picked, so the covers that
/// went wrong before are pinned here: a gold cover that came out pale khaki
/// and a blue sky chosen over a mostly brown cover.
@Suite("Artwork palette")
struct ArtworkPaletteTests {
    private func colour(_ hex: UInt32) -> OKLCH {
        OKLCH(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private func contrast(_ a: OKLCH, _ b: OKLCH) -> Double {
        a.contrast(with: b)
    }

    @Test("Contrast matches WCAG's figures")
    func wcagContrast() {
        #expect(abs(contrast(colour(0xFFFFFF), colour(0x000000)) - 21) < 0.01)
        #expect(contrast(colour(0x777777), colour(0xFFFFFF)) < 4.5)
        #expect(contrast(colour(0x767676), colour(0xFFFFFF)) >= 4.5)
    }

    @Test("Round-trips sRGB", arguments: [0xE0A30C, 0x87302F, 0x5A92C2, 0x3F3F40] as [UInt32])
    func roundTrips(hex: UInt32) {
        let back = colour(hex).srgb
        #expect(abs(back.red * 255 - Double(hex >> 16 & 0xFF)) < 0.5)
        #expect(abs(back.green * 255 - Double(hex >> 8 & 0xFF)) < 0.5)
        #expect(abs(back.blue * 255 - Double(hex & 0xFF)) < 0.5)
    }

    @Test("A colour outside sRGB is pulled in, keeping its hue")
    func outOfGamut() {
        let fitted = OKLCH(l: 0.6, c: 0.4, h: 30).srgb
        #expect([fitted.red, fitted.green, fitted.blue].allSatisfy { (0...1).contains($0) })
        #expect(abs(OKLCH(red: fitted.red, green: fitted.green, blue: fitted.blue).h - 30) < 1)
    }

    private func ground(_ hex: UInt32) -> ArtworkPalette.Ground {
        let cover = colour(hex)
        return ArtworkPalette.ground(for: .init(average: cover, mesh: Array(repeating: cover, count: 9)))
    }

    @Test("A bright cover stays bright, vivid and warm")
    func brightGold() {
        // Count on Me's middle; Apple Music paints it around #D8A015.
        let cover = colour(0xF6CE66)
        let shade = ArtworkPalette.shade(cover)
        let top = ground(0xF6CE66).mesh[0]
        #expect(shade.l > 0.7 && shade.l < 0.76)
        #expect(top.vividness > 0.98)
        #expect(top.h < cover.h - 4)
        #expect(ground(0xF6CE66).shadow.h < top.h - 4)
    }

    @Test("Brightest through the middle, darker along the top where the title sits")
    func glow() {
        let mesh = ground(0xF6CE66).mesh
        #expect(mesh[3].l > mesh[0].l + 0.05)
        #expect(mesh[3].l > mesh[6].l)
    }

    @Test("A dark red keeps its hue, stays vivid and carries light text")
    func darkRed() {
        let cover = colour(0x973F37)
        let ground = ground(0x973F37)
        #expect(abs(ground.mesh[4].h - cover.h) < 1)
        #expect(ground.mesh[4].vividness > cover.vividness)
        #expect(ground.mesh[0].l < cover.l - 0.1)
        #expect(!ground.inkIsDark)
        #expect(contrast(ground.ink, ground.mesh[4]) >= 4.5)
    }

    // MARK: - Ink

    @Test("A white cover stays pale, under dark ink")
    func whiteTakesDarkInk() {
        let ground = ground(0xFFFFFF)
        #expect(ground.inkIsDark)
        #expect(ground.ink == ArtworkPalette.darkInk)
        #expect(ground.mesh[4].l > 0.8)
    }

    @Test("A pale cream cover takes dark ink, with the ground on solid ink", arguments: [0xE8DCC6, 0xF5EBC8, 0xD8D0C0] as [UInt32])
    func paleTakesDarkInk(hex: UInt32) {
        let ground = ground(hex)
        #expect(ground.inkIsDark)
        #expect(ground.onInk == ground.mesh[4])
        #expect(contrast(ground.onInk, ground.ink) >= 4.5)
    }

    @Test("A dark cover keeps light ink", arguments: [0x213A4A, 0x202830, 0x1A1A1A, 0x2050C0] as [UInt32])
    func darkKeepsLightInk(hex: UInt32) {
        let ground = ground(hex)
        #expect(!ground.inkIsDark)
        #expect(ground.ink.l > 0.9)
        #expect(ground.onInk.l < 0.5)
    }

    @Test("A vivid gold, too bright for light ink, takes dark ink without being lightened")
    func goldTakesDarkInk() {
        let unlifted = ArtworkPalette.shade(colour(0xF6CE66))
        let ground = ground(0xF6CE66)
        #expect(ground.inkIsDark)
        #expect(abs(ground.mesh[3].l - (unlifted.l + 0.04)) < 0.01)
    }

    @Test("Reds and oranges: dark ones keep light ink, bright ones flip", arguments: [
        (0x973F37, false), (0x87302F, false), (0xC03020, false), (0xFF6640, true), (0xF0A030, true),
    ] as [(UInt32, Bool)])
    func redsAndOranges(hex: UInt32, isDark: Bool) {
        #expect(ground(hex).inkIsDark == isDark)
    }

    @Test("A mid-grey cover near the switch is lifted until dark ink clears 4.5:1")
    func nearTheSwitch() {
        // Light ink falls just short on its middle row, and its darker top
        // row was too dark for dark ink until lifted.
        let ground = ground(0xA6A6A6)
        #expect(ground.inkIsDark)
        #expect(ground.mesh.allSatisfy { contrast(ArtworkPalette.darkInk, $0) >= 4.5 - 0.001 })
    }

    @Test("Whatever the cover, the ink clears 4.5:1 on every point of the ground, and on solid ink")
    func inkAlwaysClears() {
        let steps = stride(from: 0.0, through: 1.0, by: 0.125)
        for r in steps {
            for g in steps {
                for b in steps {
                    let cover = OKLCH(red: r, green: g, blue: b)
                    let ground = ArtworkPalette.ground(for: .init(average: cover, mesh: Array(repeating: cover, count: 9)))
                    #expect(ground.mesh.allSatisfy { contrast(ground.ink, $0) >= 4.5 - 0.001 }, "\(r) \(g) \(b)")
                    #expect(contrast(ground.ink, ground.onInk) >= 4.5, "\(r) \(g) \(b)")
                }
            }
        }
    }

    @Test("A cover without colours has no palette, so Practice keeps the system look and coral")
    @MainActor func noCover() {
        #expect(ArtworkPalette(nil as Artwork?) == nil)
    }

    @Test("A dark cover isn't darkened into black")
    func darkCover() {
        #expect(ArtworkPalette.shade(colour(0x202830)).l >= min(colour(0x202830).l, 0.25) - 0.001)
    }

    @Test("Grey stays grey")
    func greyStaysGrey() {
        let ground = ground(0x5F5F5F)
        #expect(ground.mesh.allSatisfy { $0.c < 0.005 })
        #expect(ground.ink.c < 0.005)
    }

    @Test("Each mesh point leans towards the whole cover")
    func meshPullsToAverage() throws {
        let red = colour(0xC03020), blue = colour(0x2050C0)
        let regions = ArtworkPalette.Regions(average: colour(0x704070), mesh: [red] + Array(repeating: blue, count: 8))
        let ground = ArtworkPalette.ground(for: regions)
        let corner = ground.mesh[0], other = ground.mesh[2]
        #expect(corner.h < 60 || corner.h > 300)
        #expect(abs(corner.h - other.h) > 20)
        let allRed = ArtworkPalette.ground(for: .init(average: red, mesh: Array(repeating: red, count: 9)))
        #expect(corner.c < allRed.mesh[0].c)
    }

    @Test("A pale region keeps the cover's colour")
    func paleRegion() {
        let gold = colour(0xE0A010), cream = colour(0xF5EBC8)
        let ground = ArtworkPalette.ground(for: .init(average: gold, mesh: [cream] + Array(repeating: gold, count: 8)))
        #expect(ground.mesh[0].c >= ground.mesh[2].c - 0.001)
        #expect(abs(ground.mesh[0].h - gold.h) < 15)
    }

    /// A `side`×`side` bitmap whose left half is `left` and right half `right`.
    private func halves(_ left: UInt32, _ right: UInt32, side: Int = 8) -> [UInt8] {
        (0..<side * side).flatMap { i -> [UInt8] in
            let hex = i % side < side / 2 ? left : right
            return [UInt8(hex >> 16 & 0xFF), UInt8(hex >> 8 & 0xFF), UInt8(hex & 0xFF), 255]
        }
    }

    @Test("Averages the whole cover, and each region apart")
    func regions() throws {
        let regions = try #require(ArtworkPalette.regions(rgba: halves(0xFF0000, 0x0000FF), side: 8))
        let purple = colour(0x800080)
        #expect(abs(regions.average.l - purple.l) < 0.01)
        // Weighted towards the more colourful blue, but still purple.
        #expect((270...340).contains(regions.average.h))
        #expect(abs(regions.mesh[0].h - colour(0xFF0000).h) < 1)
        #expect(abs(regions.mesh[2].h - colour(0x0000FF).h) < 1)
        #expect((270...340).contains(regions.mesh[4].h))
        #expect(regions.mesh[6] == regions.mesh[0])
    }

    @Test("A pale part dilutes the hue less than a colourful one")
    func colourfulPixelsLead() throws {
        // A gold cover crossed by a cream road, as Count on Me is.
        let regions = try #require(ArtworkPalette.regions(rgba: halves(0xF5EBC8, 0xF0B020, side: 20), side: 20))
        let (cream, gold) = (colour(0xF5EBC8), colour(0xF0B020))
        #expect(abs(regions.average.h - gold.h) < abs(regions.average.h - cream.h))
    }

    @Test("A pale border barely moves the hue")
    func border() throws {
        let side = 20
        let framed = (0..<side * side).flatMap { i -> [UInt8] in
            let (x, y) = (i % side, i / side)
            let isBorder = min(x, y, side - 1 - x, side - 1 - y) < 3
            return isBorder ? [0xF5, 0xEB, 0xC8, 255] : [0xE0, 0xA0, 0x10, 255]
        }
        let regions = try #require(ArtworkPalette.regions(rgba: framed, side: side))
        #expect(abs(regions.average.h - colour(0xE0A010).h) < 3)
    }

    @Test("A half-transparent pixel counts as its own colour, not darkened")
    func premultiplied() throws {
        let opaque = try #require(ArtworkPalette.regions(rgba: halves(0xF0B020, 0xF0B020), side: 8))
        // 0xF0B020 at alpha 128, premultiplied as CoreGraphics draws it.
        let half: [UInt8] = Array(repeating: [0x78, 0x58, 0x10, 128], count: 64).flatMap { $0 }
        let regions = try #require(ArtworkPalette.regions(rgba: half, side: 8))
        #expect(abs(regions.average.l - opaque.average.l) < 0.01)
        #expect(abs(regions.average.h - opaque.average.h) < 1)
    }

    @Test("Ignores transparent pixels and empty images")
    func transparent() {
        #expect(ArtworkPalette.regions(rgba: [], side: 8) == nil)
        #expect(ArtworkPalette.regions(rgba: Array(repeating: 0, count: 256), side: 8) == nil)
    }
}
