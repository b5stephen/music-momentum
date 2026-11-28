//
//  ListFolder.swift
//  MusicMomentum
//

import Foundation
import SwiftData

/// One collapsible folder in Saved's Lists view: every song, a list's songs,
/// or the songs in none.
struct ListFolder: Identifiable {
    nonisolated static let allID = "all"
    nonisolated static let unfiledID = "unfiled"

    let id: String
    /// Nil for All Songs and for the folder of songs in no list.
    let list: PracticeList?
    var songs: [SavedSong]

    var isAll: Bool { id == Self.allID }

    var title: String { isAll ? "All Songs" : list?.name ?? "Not in a List" }

    /// All Songs first, then every list gets a folder, in the lists' order,
    /// then the unfiled songs when there are any. A song in several lists is
    /// in each of their folders, keeping the order `songs` arrives in.
    /// Searching, a folder with no match is left out, since a header with
    /// nothing under it reads as a match, and so is All Songs: every match
    /// already shows under its list or the unfiled songs, and searching
    /// opens every folder, so it would list each one twice.
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
        if isSearching { return folders.filter { !$0.songs.isEmpty } }
        if !songs.isEmpty {
            folders.insert(ListFolder(id: allID, list: nil, songs: songs), at: 0)
        }
        return folders
    }

    /// A row's selection tag: the same song can sit in two folders, and a tag
    /// of the song alone ticked it in both at once.
    struct Row: Hashable {
        let folderID: String
        let song: PersistentIdentifier
    }

    /// The folders the user turned from how they start, per device: a list
    /// starts open, so a new one shows itself, while All Songs starts closed,
    /// or a big library pushed every list off the screen. The views hold it
    /// in state and write it back.
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

        func isOpen(_ id: String) -> Bool {
            id == ListFolder.allID ? ids.contains(id) : !ids.contains(id)
        }

        mutating func toggle(_ id: String) {
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        }
    }
}
