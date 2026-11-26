//
//  PracticeListEntry.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import Foundation
import SwiftData

/// Links a `SavedSong` to a `PracticeList`, holding a fractional `position`
/// so custom per-list song ordering works without changing the CloudKit schema.
@Model
final class PracticeListEntry {
    var position: Double = 0
    var addedAt: Date = Date.now
    var list: PracticeList?
    var song: SavedSong?

    init(
        position: Double = 0,
        addedAt: Date = .now,
        list: PracticeList? = nil,
        song: SavedSong? = nil
    ) {
        self.position = position
        self.addedAt = addedAt
        self.list = list
        self.song = song
    }
}
