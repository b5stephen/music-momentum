//
//  ListFolder.swift
//  MusicMomentum
//

import Foundation
import SwiftData

/// One collapsible folder in Saved's Lists view: a list's songs, or the songs
/// in none.
struct ListFolder: Identifiable {
    nonisolated static let unfiledID = "unfiled"

    let id: String
    /// Nil for the folder of songs in no list.
    let list: PracticeList?
    var songs: [SavedSong]

    var title: String { list?.name ?? "Not in a List" }

    /// Every list gets a folder, in the lists' order, then the unfiled songs
    /// when there are any. A song in several lists is in each of their
    /// folders, keeping the order `songs` arrives in. Searching, a folder
    /// with no match is left out, since a header with nothing under it
    /// reads as a match.
    static func folders(lists: [PracticeList], songs: [SavedSong], isSearching: Bool) -> [ListFolder] {
        var byList: [String: [SavedSong]] = [:]
        var unfiled: [SavedSong] = []
        for song in songs {
            let songLists = song.lists
            if songLists.isEmpty {
                unfiled.append(song)
            } else {
                for list in songLists { byList[list.listID, default: []].append(song) }
            }
        }
        var folders = lists.map { list in
            ListFolder(id: list.listID, list: list, songs: byList[list.listID] ?? [])
        }
        if !unfiled.isEmpty {
            folders.append(ListFolder(id: unfiledID, list: nil, songs: unfiled))
        }
        return isSearching ? folders.filter { !$0.songs.isEmpty } : folders
    }

    /// A row's selection tag: the same song can sit in two folders, and a tag
    /// of the song alone ticked it in both at once.
    struct Row: Hashable {
        let folderID: String
        let song: PersistentIdentifier
    }

    /// The folders the user closed, per device. Stored as the closed ones so
    /// a new list starts open. The views hold it in state and write it back.
    struct Collapsed: RawRepresentable {
        var ids: Set<String>

        init(ids: Set<String> = []) { self.ids = ids }

        init?(rawValue: String) {
            ids = Set(rawValue.split(separator: "\n").map(String.init))
        }

        var rawValue: String { ids.sorted().joined(separator: "\n") }

        nonisolated static let storageKey = "savedCollapsedFolders"

        static var stored: Collapsed {
            Collapsed(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? Collapsed()
        }

        func store() {
            UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
        }

        mutating func toggle(_ id: String) {
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        }
    }
}
