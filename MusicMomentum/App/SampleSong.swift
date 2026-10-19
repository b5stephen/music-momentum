//
//  SampleSong.swift
//  MusicMomentum
//

#if DEBUG
import Foundation
import SwiftData

/// Loads the previews' song, plus a few more to fill Saved, so the app can be
/// resized and screenshotted in a simulator, which can't play Apple Music. It
/// runs on an in-memory store so the samples never sync to iCloud, which is
/// why switching it needs a relaunch. Switched from the debug menu, or for one launch with the
/// `-SampleSong YES` argument.
enum SampleSong {
    private static let key = "SampleSong"

    static let isRequested = UserDefaults.standard.bool(forKey: key)

    static func setRequested(_ requested: Bool) {
        UserDefaults.standard.set(requested, forKey: key)
    }

    static let track = PracticeView.Track(
        id: "1", title: "Little Wing", artistName: "Jimi Hendrix",
        palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18))
    )

    private static let others: [(String, String, String, Double, [(String, TimeInterval, TimeInterval?)])] = [
        ("2", "Blackbird", "The Beatles", 0.75, [("Intro", 0, 18), ("Bridge", 82, 101)]),
        ("3", "Nothing Else Matters", "Metallica", 1.0, [("Intro", 0, 54)]),
        ("4", "Wonderful Tonight", "Eric Clapton", 0.85, [("Riff", 0, 16), ("Outro", 196, nil)]),
        ("5", "Hotel California", "Eagles", 0.5, [("Verse", 52, 90), ("Solo", 260, 340), ("Outro Duet", 340, 380)]),
        ("6", "Under the Bridge", "Red Hot Chili Peppers", 0.7, []),
    ]

    @MainActor
    static func container() throws -> ModelContainer {
        let container = try AppSchema.inMemoryContainer()
        let context = container.mainContext
        // Saved before Little Wing, so it tops the most-recently-changed list.
        for (id, title, artist, speed, markers) in others {
            let song = SavedSong.save(
                songID: id, title: title, artistName: artist,
                artworkData: nil, speed: speed, in: context
            )
            for (name, start, end) in markers {
                SongMarker.add(to: song, name: name, startTime: start, endTime: end, in: context)
            }
        }
        let song = SavedSong.save(
            songID: track.id, title: track.title, artistName: track.artistName,
            artworkData: nil, speed: 0.6, in: context
        )
        SongMarker.add(to: song, name: "Intro", startTime: 0, endTime: 22, in: context)
        SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 112, in: context)
        SongMarker.add(to: song, name: "Verse 2", startTime: 150, endTime: nil, in: context)
        return container
    }
}
#endif
