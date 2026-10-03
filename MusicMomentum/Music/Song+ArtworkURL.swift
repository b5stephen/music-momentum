//
//  Song+ArtworkURL.swift
//  MusicMomentum
//

import Foundation
import MusicKit

extension Song {
    /// Where the cover can actually be downloaded from. Library artwork's URLs
    /// are device-local (`musicKit://`), so a library song borrows its catalog
    /// counterpart's cover. `nil` when neither can be fetched.
    func downloadableArtworkURL(side: Int) async -> URL? {
        func downloadable(_ artwork: Artwork?) -> URL? {
            guard let url = artwork?.url(width: side, height: side),
                  ["https", "http"].contains(url.scheme)
            else { return nil }
            return url
        }
        if let url = downloadable(artwork) { return url }
        guard let catalogID, let catalogSong = try? await SongLookup.catalogItem(id: catalogID) else { return nil }
        return downloadable(catalogSong.artwork)
    }
}
