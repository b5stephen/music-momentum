//
//  PracticeListEntry.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import Foundation
import SwiftData

/// `position` is a `Double` so a song can be moved between two others by
/// writing one record, rather than renumbering the list across devices.
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
