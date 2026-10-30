//
//  PlaybackController+Delete.swift
//  MusicMomentum
//

import SwiftData

extension PlaybackController {
    /// Tells the player about each marker first, so a loop running over one of
    /// them doesn't outlive it.
    func delete(_ song: SavedSong, in context: ModelContext) {
        for marker in song.markers ?? [] { markerDeleted(marker) }
        context.delete(song)
        try? context.save()
    }
}
