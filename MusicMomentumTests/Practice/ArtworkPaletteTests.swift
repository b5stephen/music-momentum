//
//  ArtworkPaletteTests.swift
//  MusicMomentumTests
//

import Foundation
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
        func luminance(_ c: OKLCH) -> Double {
            let linear = [c.srgb.red, c.srgb.green, c.srgb.blue].map {
                $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    @Test("Round-trips sRGB", arguments: [0xE0A30C, 0x87302F, 0x5A92C2, 0x3F3F40] as [UInt32])
    func roundTrips(hex: UInt32) {
        let back = colour(hex).srgb
        #expect(abs(back.red * 255 - Double(hex >> 16 & 0xFF)) < 0.5)
        #expect(abs(back.green * 255 - Double(hex >> 8 & 0xFF)) < 0.5)
        #expect(abs(back.blue * 255 - Double(hex & 0xFF)) < 0.5)
    }

    private func ground(_ hex: UInt32) -> ArtworkPalette.Ground {
        let cover = colour(hex)
        return ArtworkPalette.ground(for: .init(average: cover, mesh: Array(repeating: cover, count: 9)))
    }

    @Test("A bright cover darkens into its richest shade")
    func brightGold() {
        // Count on Me's average; Apple Music paints it L 0.60, C 0.12.
        let cover = colour(0xF7D273)
        let top = ground(0xF7D273).mesh[0]
        #expect(abs(top.l - 0.6) < 0.02)
        #expect(abs(top.c - cover.c) < 0.005)
        #expect(top.vividness > 0.9)
    }

    @Test("A dark red keeps its hue and chroma and carries light text")
    func darkRed() {
        let cover = colour(0x973F37)
        let ground = ground(0x973F37)
        #expect(abs(ground.mesh[4].h - cover.h) < 1)
        #expect(abs(ground.mesh[4].c - cover.c) < 0.005)
        #expect(ground.mesh[4].l < cover.l - 0.08)
        #expect(contrast(ground.text, ground.mesh[4]) >= 4.5)
    }

    @Test("Even a white cover stays dark enough for light text")
    func whiteDarkens() {
        #expect(ground(0xFFFFFF).mesh[0].l <= 0.62)
        #expect(contrast(ground(0xFFFFFF).text, ground(0xFFFFFF).mesh[0]) >= 3)
    }

    @Test("Grey stays grey")
    func greyStaysGrey() {
        let ground = ground(0x5F5F5F)
        #expect(ground.mesh.allSatisfy { $0.c < 0.005 })
        #expect(ground.text.c < 0.005)
    }

    @Test("Each mesh point sits halfway between its region and the whole cover")
    func meshPullsToAverage() throws {
        let red = colour(0xC03020), blue = colour(0x2050C0)
        let regions = ArtworkPalette.Regions(average: colour(0x704070), mesh: [red] + Array(repeating: blue, count: 8))
        let ground = ArtworkPalette.ground(for: regions)
        let corner = ground.mesh[0], other = ground.mesh[8]
        #expect(corner.h < 60 || corner.h > 300)
        #expect(abs(corner.h - other.h) > 60)
        #expect(corner.c < ArtworkPalette.ground(for: .init(average: red, mesh: [red])).mesh[0].c)
    }

    /// A `side`×`side` bitmap whose left half is `left` and right half `right`.
    private func halves(_ left: UInt32, _ right: UInt32, side: Int = 8) -> [UInt8] {
        (0..<side * side).flatMap { i -> [UInt8] in
            let hex = i % side < side / 2 ? left : right
            return [UInt8(hex >> 16 & 0xFF), UInt8(hex >> 8 & 0xFF), UInt8(hex & 0xFF), 255]
        }
    }

    @Test("Averages the whole cover as stored, and each region apart")
    func regions() throws {
        let regions = try #require(ArtworkPalette.regions(rgba: halves(0xFF0000, 0x0000FF), side: 8))
        let purple = colour(0x800080)
        #expect(abs(regions.average.l - purple.l) < 0.01)
        #expect(abs(regions.average.h - purple.h) < 2)
        #expect(abs(regions.mesh[0].h - colour(0xFF0000).h) < 1)
        #expect(abs(regions.mesh[2].h - colour(0x0000FF).h) < 1)
        #expect(abs(regions.mesh[4].h - purple.h) < 2)
        #expect(regions.mesh[6] == regions.mesh[0])
    }

    @Test("Ignores transparent pixels and empty images")
    func transparent() {
        #expect(ArtworkPalette.regions(rgba: [], side: 4) == nil)
        #expect(ArtworkPalette.regions(rgba: Array(repeating: 0, count: 64), side: 4) == nil)
    }
}
