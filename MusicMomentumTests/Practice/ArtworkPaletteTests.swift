//
//  ArtworkPaletteTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// The practice screen's ground is derived, not picked, so the covers that
/// went wrong before are pinned here: a yellow that turned olive and a pale
/// border chosen over the cover's subject.
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

    @Test("A vivid yellow stays bright and warms as it darkens")
    func vividYellow() {
        let cover = colour(0xE0A30C)
        let ground = ArtworkPalette.ground(for: cover)
        #expect(ground.top.l > 0.7)
        #expect(ground.top.vividness > 0.9)
        #expect(ground.bottom.l < ground.top.l - 0.2)
        #expect(ground.bottom.h < ground.top.h - 8)
    }

    @Test("A dark red keeps its lightness and carries light text")
    func darkRed() {
        let cover = colour(0x87302F)
        let ground = ArtworkPalette.ground(for: cover)
        #expect(abs(ground.top.l - cover.l) < 0.001)
        #expect(contrast(ground.text, ground.top) >= 4.5)
    }

    @Test("Muted and pale covers darken")
    func mutedDarkens() {
        #expect(ArtworkPalette.ground(for: colour(0xF5E7B5)).top.l <= 0.77)
        #expect(ArtworkPalette.ground(for: colour(0xA89A8A)).top.l <= 0.46)
    }

    @Test("Grey stays grey")
    func greyStaysGrey() {
        let ground = ArtworkPalette.ground(for: colour(0x5F5F5F))
        #expect(ground.top.c < 0.005)
        #expect(ground.bottom.c < 0.005)
        #expect(ground.text.c < 0.005)
    }

    private func pixels(_ runs: [(hex: UInt32, count: Int)]) -> [UInt8] {
        runs.flatMap { run in
            Array(repeating: [UInt8(run.hex >> 16 & 0xFF), UInt8(run.hex >> 8 & 0xFF), UInt8(run.hex & 0xFF), 255], count: run.count)
                .flatMap { $0 }
        }
    }

    @Test("Picks the vivid subject over a larger pale border")
    func subjectOverBorder() throws {
        let dominant = try #require(ArtworkPalette.dominantColour(rgba: pixels([(0xF5E7B5, 600), (0xE0A30C, 400)])))
        #expect(abs(dominant.h - colour(0xE0A30C).h) < 6)
    }

    @Test("A black-and-white cover comes out grey")
    func blackAndWhite() throws {
        let dominant = try #require(ArtworkPalette.dominantColour(rgba: pixels([(0x202020, 500), (0xD0D0D0, 300), (0x6A6A6A, 200)])))
        #expect(dominant.c < 0.01)
    }

    @Test("Ignores transparent pixels and empty images")
    func transparent() {
        #expect(ArtworkPalette.dominantColour(rgba: []) == nil)
        #expect(ArtworkPalette.dominantColour(rgba: [255, 0, 0, 0]) == nil)
    }
}
