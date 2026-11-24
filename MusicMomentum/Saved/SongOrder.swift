//
//  SongOrder.swift
//  MusicMomentum
//

import Foundation

/// Each order also decides the list's sections, so there's no separate
/// group-by: grouping by date under a title sort would scatter every section.
enum SongOrder: String, CaseIterable, Identifiable {
    case title, artist, practiced

    var id: Self { self }

    var title: String {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .practiced: "Last Practiced"
        }
    }

    /// Takes the list most recently changed first, which a stable sort keeps
    /// as the tiebreak, including among songs never practised.
    func sorted(_ recentlyChanged: [SavedSong]) -> [SavedSong] {
        switch self {
        case .practiced:
            recentlyChanged.sorted { ($0.practicedAt ?? .distantPast) > ($1.practicedAt ?? .distantPast) }
        case .title:
            recentlyChanged.sorted {
                SongSection.sortingName($0.title).localizedStandardCompare(SongSection.sortingName($1.title)) == .orderedAscending
            }
        case .artist:
            recentlyChanged.sorted {
                switch SongSection.sortingName($0.artistName).localizedStandardCompare(SongSection.sortingName($1.artistName)) {
                case .orderedSame:
                    SongSection.sortingName($0.title).localizedStandardCompare(SongSection.sortingName($1.title)) == .orderedAscending
                case let result: result == .orderedAscending
                }
            }
        }
    }

    /// Sorts, then splits the run wherever the section changes, so sections
    /// come out in the sort's own order.
    func sections(
        _ recentlyChanged: [SavedSong],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [SongSection] {
        var sections: [SongSection] = []
        for song in sorted(recentlyChanged) {
            let heading = heading(for: song, now: now, calendar: calendar)
            if sections.last?.id == heading.id {
                sections[sections.count - 1].songs.append(song)
            } else {
                sections.append(SongSection(
                    id: heading.id, title: heading.title, indexLabel: heading.indexLabel, songs: [song]
                ))
            }
        }
        return sections
    }

    private func heading(for song: SavedSong, now: Date, calendar: Calendar) -> SongSection.Heading {
        switch self {
        case .practiced:
            guard let practicedAt = song.practicedAt else {
                return .init(id: "never", title: "Not Practised Yet")
            }
            return SongSection.dateHeading(for: practicedAt, now: now, calendar: calendar)
        // Letters rather than a section per artist: most artists have one
        // saved song, which put a header over nearly every row.
        case .title, .artist:
            let letter = SongSection.indexLetter(for: SongSection.sortingName(self == .title ? song.title : song.artistName))
            return .init(id: "letter-\(letter)", title: letter, indexLabel: letter)
        }
    }
}
