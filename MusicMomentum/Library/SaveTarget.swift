//
//  SaveTarget.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI

/// Where a song row's + puts a song: Saved, or one of its lists. A picker
/// opened from inside a list targets that list, and says so in its title, so
/// a song never lands in a list the screen didn't name.
enum SaveTarget: Hashable {
    case saved
    case list(PracticeList)

    var list: PracticeList? {
        if case .list(let list) = self { list } else { nil }
    }

    /// For "Add to …" and "Added to …".
    var name: String { list?.name ?? "Saved" }

    init(list: PracticeList?) {
        self = list.map(SaveTarget.list) ?? .saved
    }

    /// Whether `saved` is already where this target would put it. In a list,
    /// a song that's saved but not in the list still gets a +.
    func contains(_ saved: SavedSong?) -> Bool {
        guard let saved else { return false }
        guard let list else { return true }
        return saved.isInList(list)
    }

    /// Re-adding a saved song keeps its speed and markers (`SavedSong.add`).
    @discardableResult
    func add(_ song: Song, in context: ModelContext) -> SavedSong {
        let saved = SavedSong.add(song: song, in: context)
        add(saved, in: context)
        return saved
    }

    func add(_ saved: SavedSong, in context: ModelContext) {
        if let list { PracticeList.add([saved], to: list, in: context) }
    }
}

extension EnvironmentValues {
    /// `nil` hides the rows' + (previews of a row on its own).
    @Entry var saveTarget: SaveTarget?
}
