//
//  SavedLayout.swift
//  MusicMomentum
//

import Foundation

/// How Saved reads: one run of songs narrowed by the list filter, or a
/// collapsible folder per list. Per device, like the sort.
enum SavedLayout: String, CaseIterable, Identifiable {
    case songs, lists

    nonisolated static let storageKey = "savedLayout"

    var id: Self { self }

    var title: String {
        switch self {
        case .songs: "Songs"
        case .lists: "Lists"
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note.list"
        case .lists: "folder"
        }
    }
}
