//
//  SavedSong.swift
//  MusicMomentum
//

import Foundation
import MusicKit
import SwiftData

/// A song on the practice list, with the speed it's practised at.
///
/// Title, artist and artwork are copied in so the list draws without asking
/// Apple Music. Artwork is the JSON-encoded `Artwork` rather than a URL:
/// `ArtworkImage` draws catalog and library-only covers alike and retries in a
/// way `AsyncImage` in a `List` doesn't — a row rebuilt mid-load under
/// `AsyncImage` sticks in a failure state that looks like loading.
///
/// `songID` is unique by convention only: CloudKit can't enforce `#Unique`,
/// so two devices saving the same song offline sync as two rows until
/// `mergeDuplicates` runs.
@Model
final class SavedSong {
    var songID: String = ""
    /// Stored separately because `songID` may be a library ID (`i.…`), which
    /// stops resolving the moment the user removes the song from their
    /// library. `nil` for a self-imported track with no catalog counterpart.
    var catalogID: String?
    var speed: Double = 1.0
    var title: String = ""
    var artistName: String = ""
    var artworkData: Data?
    /// Bumped on save, speed change and load; the saved list sorts on it.
    var lastPracticed: Date = Date.now
    /// Optional because CloudKit requires every relationship to be.
    @Relationship(deleteRule: .cascade, inverse: \SongMarker.song)
    var markers: [SongMarker]? = []

    init(
        songID: String,
        catalogID: String? = nil,
        speed: Double,
        title: String = "",
        artistName: String = "",
        artworkData: Data? = nil,
        lastPracticed: Date = .now
    ) {
        self.songID = songID
        self.catalogID = catalogID
        self.speed = speed
        self.title = title
        self.artistName = artistName
        self.artworkData = artworkData
        self.lastPracticed = lastPracticed
    }

    var percent: Int { Int((speed * 100).rounded()) }

    var artwork: Artwork? {
        guard let artworkData else { return nil }
        return try? JSONDecoder().decode(Artwork.self, from: artworkData)
    }
}

// MARK: - Storage

extension SavedSong {
    static func find(songID: String, in context: ModelContext) -> SavedSong? {
        let descriptor = FetchDescriptor<SavedSong>(
            predicate: #Predicate { $0.songID == songID }
        )
        return try? context.fetch(descriptor).first
    }

    /// Upserts. Takes plain values rather than a `Song` because MusicKit's
    /// `Song` and `Artwork` have no public initialisers, so tests can't make one.
    @discardableResult
    static func save(
        songID: String,
        catalogID: String? = nil,
        title: String,
        artistName: String,
        artworkData: Data?,
        speed: Double,
        in context: ModelContext
    ) -> SavedSong {
        let song: SavedSong
        if let existing = find(songID: songID, in: context) {
            existing.speed = speed
            // Refresh metadata too: tracks get retitled and artwork replaced.
            existing.title = title
            existing.artistName = artistName
            existing.artworkData = artworkData
            existing.catalogID = catalogID
            song = existing
        } else {
            song = SavedSong(
                songID: songID,
                catalogID: catalogID,
                speed: speed,
                title: title,
                artistName: artistName,
                artworkData: artworkData
            )
            context.insert(song)
        }
        song.lastPracticed = .now
        try? context.save()
        return song
    }

    @discardableResult
    static func save(song: Song, speed: Double, in context: ModelContext) -> SavedSong {
        save(
            songID: song.id.rawValue,
            catalogID: song.catalogID,
            title: song.title,
            artistName: song.artistName,
            artworkData: song.artwork.flatMap { try? JSONEncoder().encode($0) },
            speed: speed,
            in: context
        )
    }

    static func touch(_ song: SavedSong, in context: ModelContext) {
        song.lastPracticed = .now
        try? context.save()
    }

    /// Folds rows sharing a `songID` into the most recently practised one,
    /// keeping every marker. The survivor has to be chosen from synced
    /// fields alone: two devices merging at once must pick the same row, or
    /// each deletes the one the other kept.
    static func mergeDuplicates(in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<SavedSong>()) else { return }
        let groups = Dictionary(grouping: all, by: \.songID).values.filter { $0.count > 1 }
        guard !groups.isEmpty else { return }
        for group in groups {
            let ordered = group.sorted {
                ($0.lastPracticed, $0.speed) > ($1.lastPracticed, $1.speed)
            }
            let keeper = ordered[0]
            for duplicate in ordered.dropFirst() {
                if keeper.catalogID == nil { keeper.catalogID = duplicate.catalogID }
                if keeper.artworkData == nil { keeper.artworkData = duplicate.artworkData }
                for marker in duplicate.markers ?? [] { marker.song = keeper }
                context.delete(duplicate)
            }
        }
        try? context.save()
    }
}

extension SavedSong {
    var sortedMarkers: [SongMarker] {
        (markers ?? []).sorted { $0.startTime < $1.startTime }
    }
}
