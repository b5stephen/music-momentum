//
//  ArtworkRepair.swift
//  MusicMomentum
//

import Foundation
import MusicKit
import SwiftData

/// Swaps device-local library artwork for the catalog's, so a song saved
/// from one device's library shows its cover on the others. Whichever device
/// runs it first writes the catalog artwork, and sync carries it everywhere.
enum ArtworkRepair {
    static func run(in context: ModelContext) async {
        guard MusicAuthorization.currentStatus == .authorized,
              let all = try? context.fetch(FetchDescriptor<SavedSong>())
        else { return }
        let broken = all.filter { $0.catalogID != nil && !$0.hasPortableArtwork }
        guard !broken.isEmpty else { return }

        let ids = Set(broken.compactMap(\.catalogID)).map { MusicItemID($0) }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: ids)
        guard let catalog = try? await request.response().items else { return }

        for song in broken {
            guard let match = catalog.first(where: { $0.id.rawValue == song.catalogID }),
                  let artwork = match.artwork,
                  let data = try? JSONEncoder().encode(artwork)
            else { continue }
            SavedSong.setArtwork(data, for: song, in: context)
        }
    }
}
