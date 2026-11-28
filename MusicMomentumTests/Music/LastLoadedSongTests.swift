//
//  LastLoadedSongTests.swift
//  MusicMomentumTests
//

import Foundation
import Testing
@testable import MusicMomentum

/// Launch opens in the remembered song's colours before MusicKit finds it, so
/// colours left over from another song would paint the wrong cover.
@Suite("Last loaded song")
struct LastLoadedSongTests {
    let defaults: UserDefaults
    let ground = ArtworkPalette.ground(for: .init(
        average: OKLCH(l: 0.5, c: 0.12, h: 30),
        mesh: (0..<9).map { OKLCH(l: 0.3 + Double($0) * 0.05, c: 0.1, h: Double($0) * 40) }
    ))

    init() {
        defaults = UserDefaults(suiteName: "LastLoadedSongTests.\(UUID().uuidString)")!
    }

    @Test func remembersNameAndColours() {
        LastLoadedSong.remember(songID: "a", catalogID: "1", title: "Night Ferry", artistName: "Low Tide Club", in: defaults)
        LastLoadedSong.remember(ground, for: "a", in: defaults)

        #expect(LastLoadedSong.stored(in: defaults) == .init(
            songID: "a", catalogID: "1", title: "Night Ferry", artistName: "Low Tide Club", ground: ground
        ))
    }

    @Test func anotherSongDropsTheColours() {
        LastLoadedSong.remember(songID: "a", catalogID: nil, title: "A", artistName: "X", in: defaults)
        LastLoadedSong.remember(ground, for: "a", in: defaults)
        LastLoadedSong.remember(songID: "b", catalogID: nil, title: "B", artistName: "Y", in: defaults)

        #expect(LastLoadedSong.stored(in: defaults)?.ground == nil)
    }

    @Test func theSameSongKeepsItsColours() {
        LastLoadedSong.remember(songID: "a", catalogID: nil, title: "A", artistName: "X", in: defaults)
        LastLoadedSong.remember(ground, for: "a", in: defaults)
        LastLoadedSong.remember(songID: "a", catalogID: nil, title: "A", artistName: "X", in: defaults)

        #expect(LastLoadedSong.stored(in: defaults)?.ground == ground)
    }

    @Test func coloursSampledAfterMovingOnAreIgnored() {
        LastLoadedSong.remember(songID: "b", catalogID: nil, title: "B", artistName: "Y", in: defaults)
        LastLoadedSong.remember(ground, for: "a", in: defaults)

        #expect(LastLoadedSong.stored(in: defaults)?.ground == nil)
    }

    @Test func aStoreFromBeforeNamesWereKeptStillRestores() {
        defaults.set("a", forKey: "lastLoadedSongID")

        #expect(LastLoadedSong.stored(in: defaults) == .init(songID: "a"))
    }

    @Test func forgettingClearsEverything() {
        LastLoadedSong.remember(songID: "a", catalogID: "1", title: "A", artistName: "X", in: defaults)
        LastLoadedSong.remember(ground, for: "a", in: defaults)
        LastLoadedSong.forget(in: defaults)

        #expect(LastLoadedSong.stored(in: defaults) == nil)
    }
}
