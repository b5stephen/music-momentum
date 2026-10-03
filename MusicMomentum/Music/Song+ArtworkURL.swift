//
//  Song+ArtworkURL.swift
//  MusicMomentum
//

import Foundation
import MusicKit

extension Song {
    /// A library song borrows its catalog counterpart's cover. `nil` when
    /// neither can be downloaded.
    func downloadableArtworkURL(side: Int) async -> URL? {
        if let url = artwork?.webURL(side: side) { return url }
        guard let catalogID, let catalogSong = try? await SongLookup.catalogItem(id: catalogID) else { return nil }
        return catalogSong.artwork?.webURL(side: side)
    }
}
