//
//  ListFilter.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import Foundation

/// Active filter over saved songs: all songs, unfiled songs, or one or more
/// `PracticeList`s matched by union or intersection.
nonisolated enum ListFilter: Equatable, Hashable, Codable {
    case all
    case unfiled
    case lists(ids: Set<String>, match: MatchMode)

    enum MatchMode: String, Codable, CaseIterable, Identifiable {
        case all
        case any

        var id: Self { self }

        var title: String {
            switch self {
            case .all: "Match All Lists"
            case .any: "Match Any List"
            }
        }
    }

    var isActive: Bool {
        self != .all
    }

    var selectedListIDs: Set<String> {
        switch self {
        case .all, .unfiled: []
        case let .lists(ids, _): ids
        }
    }

    var matchMode: MatchMode {
        switch self {
        case .all, .unfiled: .all
        case let .lists(_, match): match
        }
    }

    var singleListID: String? {
        guard case let .lists(ids, _) = self, ids.count == 1 else { return nil }
        return ids.first
    }

    func contains(listID: String) -> Bool {
        selectedListIDs.contains(listID)
    }

    /// Drops list IDs that no longer exist (for example, deleted on another
    /// device) and falls back to `.all` when none remain.
    func reconciled(with availableLists: [PracticeList]) -> ListFilter {
        guard case let .lists(ids, match) = self else { return self }
        let validIDs = Set(availableLists.map(\.listID))
        let remaining = ids.intersection(validIDs)
        return remaining.isEmpty ? .all : .lists(ids: remaining, match: match)
    }

    func toggling(listID: String, multiSelect: Bool) -> ListFilter {
        if !multiSelect {
            if singleListID == listID { return .all }
            return .lists(ids: [listID], match: matchMode)
        }
        var next = selectedListIDs
        if next.contains(listID) {
            next.remove(listID)
        } else {
            next.insert(listID)
        }
        return next.isEmpty ? .all : .lists(ids: next, match: matchMode)
    }

    func withMatchMode(_ match: MatchMode) -> ListFilter {
        switch self {
        case .all, .unfiled: self
        case let .lists(ids, _): .lists(ids: ids, match: match)
        }
    }

    func matches(_ song: SavedSong) -> Bool {
        switch self {
        case .all:
            return true
        case .unfiled:
            return song.isUnfiled
        case let .lists(ids, match):
            guard !ids.isEmpty else { return true }
            let songListIDs = Set(song.lists.map(\.listID))
            switch match {
            case .all:
                return ids.isSubset(of: songListIDs)
            case .any:
                return !ids.isDisjoint(with: songListIDs)
            }
        }
    }

    func apply(to songs: [SavedSong], searchTerm: String = "") -> [SavedSong] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        return songs.filter { song in
            guard matches(song) else { return false }
            guard !term.isEmpty else { return true }
            return song.title.localizedStandardContains(term)
                || song.artistName.localizedStandardContains(term)
        }
    }

    // MARK: - Persistence

    init?(rawStorage: String) {
        guard let data = rawStorage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ListFilter.self, from: data)
        else { return nil }
        self = decoded
    }

    var rawStorage: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else { return "" }
        return string
    }
}
