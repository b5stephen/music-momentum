//
//  LastLoadedSong.swift
//  MusicMomentum
//

import Foundation
import MusicKit

/// The song on the practice screen when the app last ran, so it comes back on
/// launch. Kept apart from the saved list: loading a song isn't saving it.
nonisolated enum LastLoadedSong {
    /// Title, artist and the cover's colours ride along so launch can paint
    /// the screen as the song before MusicKit has found it. Stores from before
    /// they were kept have only the IDs.
    struct Stored: Equatable {
        var songID: String
        var catalogID: String?
        var title: String?
        var artistName: String?
        var ground: ArtworkPalette.Ground?
    }

    private static let songIDKey = "lastLoadedSongID"
    private static let catalogIDKey = "lastLoadedCatalogID"
    private static let titleKey = "lastLoadedTitle"
    private static let artistKey = "lastLoadedArtist"
    private static let groundKey = "lastLoadedGround"

    static func stored(in defaults: UserDefaults = .standard) -> Stored? {
        guard let songID = defaults.string(forKey: songIDKey) else { return nil }
        return Stored(
            songID: songID,
            catalogID: defaults.string(forKey: catalogIDKey),
            title: defaults.string(forKey: titleKey),
            artistName: defaults.string(forKey: artistKey),
            ground: defaults.data(forKey: groundKey).flatMap { try? JSONDecoder().decode(ArtworkPalette.Ground.self, from: $0) }
        )
    }

    /// Another song's colours are dropped, or the next launch would open in them.
    static func remember(
        songID: String,
        catalogID: String?,
        title: String,
        artistName: String,
        in defaults: UserDefaults = .standard
    ) {
        if defaults.string(forKey: songIDKey) != songID {
            defaults.removeObject(forKey: groundKey)
        }
        defaults.set(songID, forKey: songIDKey)
        defaults.set(catalogID, forKey: catalogIDKey)
        defaults.set(title, forKey: titleKey)
        defaults.set(artistName, forKey: artistKey)
    }

    static func remember(_ song: Song) {
        remember(songID: song.id.rawValue, catalogID: song.catalogID, title: song.title, artistName: song.artistName)
    }

    /// Ignored unless `songID` is still the one remembered: a cover sampled
    /// after the user moved on belongs to a song that won't come back.
    static func remember(_ ground: ArtworkPalette.Ground, for songID: String, in defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: songIDKey) == songID,
              let data = try? JSONEncoder().encode(ground)
        else { return }
        defaults.set(data, forKey: groundKey)
    }

    static func forget(in defaults: UserDefaults = .standard) {
        for key in [songIDKey, catalogIDKey, titleKey, artistKey, groundKey] {
            defaults.removeObject(forKey: key)
        }
    }
}

extension LastLoadedSong.Stored {
    @MainActor var palette: ArtworkPalette? { ground.map(ArtworkPalette.init(ground:)) }
}
