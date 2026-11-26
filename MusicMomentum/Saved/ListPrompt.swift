//
//  ListPrompt.swift
//  MusicMomentum
//

import Foundation

enum ListPrompt: Identifiable {
    case create(addingSongs: [SavedSong] = [])
    case rename(PracticeList)
    case delete(PracticeList)

    var id: String {
        switch self {
        case .create: "create"
        case let .rename(list): "rename-\(list.listID)"
        case let .delete(list): "delete-\(list.listID)"
        }
    }
}
