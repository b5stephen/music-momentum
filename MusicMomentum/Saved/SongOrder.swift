//
//  SongOrder.swift
//  MusicMomentum
//

import Foundation

enum SongOrder: String, CaseIterable, Identifiable {
    case changed, practiced, title, artist

    var id: Self { self }

    var title: String {
        switch self {
        case .changed: "Last Changed"
        case .practiced: "Last Practiced"
        case .title: "Title"
        case .artist: "Artist"
        }
    }

    /// Takes the list most recently changed first, which a stable sort keeps
    /// as the tiebreak, including among songs never practised.
    func sorted(_ recentlyChanged: [SavedSong]) -> [SavedSong] {
        switch self {
        case .changed:
            recentlyChanged
        case .practiced:
            recentlyChanged.sorted { ($0.practicedAt ?? .distantPast) > ($1.practicedAt ?? .distantPast) }
        case .title:
            recentlyChanged.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist:
            recentlyChanged.sorted {
                switch $0.artistName.localizedStandardCompare($1.artistName) {
                case .orderedSame: $0.title.localizedStandardCompare($1.title) == .orderedAscending
                case let result: result == .orderedAscending
                }
            }
        }
    }
}
