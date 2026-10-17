//
//  SampleSong.swift
//  MusicMomentum
//

#if DEBUG
import Foundation
import SwiftData

/// Loads the previews' song, so the practice screen can be resized in a
/// simulator, which can't play Apple Music. It runs on an in-memory store so
/// the sample never syncs to iCloud, which is why switching it needs a
/// relaunch. Switched from the debug menu, or for one launch with the
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

    @MainActor
    static func container() throws -> ModelContainer {
        let container = try AppSchema.inMemoryContainer()
        let song = SavedSong.save(
            songID: track.id, title: track.title, artistName: track.artistName,
            artworkData: nil, speed: 0.6, in: container.mainContext
        )
        SongMarker.add(to: song, name: "Intro", startTime: 0, endTime: 22, in: container.mainContext)
        SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 112, in: container.mainContext)
        SongMarker.add(to: song, name: "Verse 2", startTime: 150, endTime: nil, in: container.mainContext)
        return container
    }
}
#endif
