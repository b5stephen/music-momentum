//
//  SampleSong.swift
//  MusicMomentum
//

#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// Loads a few songs so the app can be resized and screenshotted in a
/// simulator, which can't play Apple Music. They're made up, never real
/// ones, because they end up in App Store screenshots, and each has a length
/// so marking works. It runs on an in-memory store so the samples never sync
/// to iCloud, which is why switching it on or off needs a relaunch; which
/// sample is loaded switches live. Switched from the debug menu, or for one
/// launch with the `-SampleSong YES` argument.
enum SampleSong {
    private static let key = "SampleSong"
    static let loadedKey = "SampleSongLoaded"

    static let isRequested = UserDefaults.standard.bool(forKey: key)

    static func setRequested(_ requested: Bool) {
        UserDefaults.standard.set(requested, forKey: key)
    }

    private struct Sample {
        let id: String
        let title: String
        let artistName: String
        let speed: Double
        let duration: TimeInterval
        let ground: (red: Double, green: Double, blue: Double)
        let design: SampleCover.Design
        let markers: [(name: String, time: TimeInterval)]
    }

    /// Most recently changed first, as Saved lists them.
    private static let samples = [
        Sample(
            id: "1", title: "Paper Lanterns", artistName: "The Quiet Harbors", speed: 0.6, duration: 145,
            ground: (red: 0.53, green: 0.19, blue: 0.18), design: .lanterns,
            markers: [("Intro", 0), ("Verse", 22), ("Chorus", 58), ("Solo", 96), ("Outro", 112)]
        ),
        Sample(
            id: "2", title: "Copper Sky", artistName: "Mara Lindqvist", speed: 0.75, duration: 138,
            ground: (red: 0.16, green: 0.24, blue: 0.42), design: .sun,
            markers: [("Intro", 0), ("Verse", 18), ("Chorus", 50), ("Bridge", 82), ("Chorus 2", 101)]
        ),
        Sample(
            id: "3", title: "Slow Tide Waltz", artistName: "Juniper & the Owls", speed: 1.0, duration: 388,
            ground: (red: 0.15, green: 0.16, blue: 0.18), design: .waves,
            markers: [("Intro", 0), ("Verse", 54), ("Chorus", 140), ("Verse 2", 210), ("Outro", 330)]
        ),
        Sample(
            id: "4", title: "Northbound Lights", artistName: "Theo Calloway", speed: 0.85, duration: 222,
            ground: (red: 0.72, green: 0.58, blue: 0.40), design: .road,
            markers: [("Verse", 16), ("Chorus", 70), ("Outro", 196)]
        ),
        Sample(
            id: "5", title: "Dust on the Fretboard", artistName: "Ramona Vale", speed: 0.5, duration: 391,
            ground: (red: 0.85, green: 0.52, blue: 0.22), design: .fretboard,
            markers: [("Intro", 0), ("Verse", 52), ("", 90), ("Solo", 260), ("Outro Duet", 340)]
        ),
        Sample(
            id: "6", title: "Half Moon Motel", artistName: "The Velvet Arcade", speed: 0.7, duration: 264,
            ground: (red: 0.20, green: 0.45, blue: 0.48), design: .moon,
            markers: []
        ),
    ]

    static let tracks = samples.map {
        PracticeView.Track(
            id: $0.id, title: $0.title, artistName: $0.artistName,
            palette: ArtworkPalette(cover: OKLCH(red: $0.ground.red, green: $0.ground.green, blue: $0.ground.blue))
        )
    }

    /// The loaded sample, falling back to the first for an unknown ID.
    static func track(id: String) -> PracticeView.Track {
        tracks.first { $0.id == id } ?? tracks[0]
    }

    static func duration(of id: String) -> TimeInterval? {
        samples.first { $0.id == id }?.duration
    }

    static func speed(of id: String) -> Double? {
        samples.first { $0.id == id }?.speed
    }

    static let covers = samples.map {
        SampleCover(design: $0.design, ground: Color(red: $0.ground.red, green: $0.ground.green, blue: $0.ground.blue))
    }

    /// `nil` outside sample mode, where an ID like "1" is someone's real song.
    static func cover(for id: String) -> SampleCover? {
        guard isRequested, let index = samples.firstIndex(where: { $0.id == id }) else { return nil }
        return covers[index]
    }

    @MainActor
    static func container() throws -> ModelContainer {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext
        // Saved oldest first, so the list comes out in `samples` order.
        for sample in samples.reversed() {
            let song = SavedSong.save(
                songID: sample.id, title: sample.title, artistName: sample.artistName,
                artworkData: nil, speed: sample.speed, in: context
            )
            for marker in sample.markers {
                SongMarker.add(to: song, name: marker.name, at: marker.time, in: context)
            }
        }
        return container
    }
}
#endif
