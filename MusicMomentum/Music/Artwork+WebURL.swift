//
//  Artwork+WebURL.swift
//  MusicMomentum
//

import Foundation
import MusicKit

nonisolated extension Artwork {
    /// `nil` for a library song's artwork, which points at the device's own
    /// library (`musicKit://…`): it can't be downloaded, and `ArtworkImage`
    /// on any other device silently fails to draw it. Only catalog artwork is
    /// served over the web.
    func webURL(side: Int) -> URL? {
        guard let url = url(width: side, height: side), ["https", "http"].contains(url.scheme) else { return nil }
        return url
    }
}
