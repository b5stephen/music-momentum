//
//  SongSection.swift
//  MusicMomentum
//

import Foundation

/// A run of saved songs under one heading, as `SongOrder.sections` splits them.
struct SongSection: Identifiable {
    let id: String
    let title: String
    /// The letter in the side index; the date order has none.
    let indexLabel: String?
    var songs: [SavedSong]

    /// About a phone screen of rows: a shorter list needs no headers, and
    /// over a few songs each header sat over a single row.
    nonisolated static func groups(songCount: Int) -> Bool {
        songCount >= 12
    }

    struct Heading {
        let id: String
        let title: String
        var indexLabel: String?
    }

    /// Notes' and Mail's buckets: the last month by day range, then this
    /// year's months, then whole years. A date ahead of `now`, from another
    /// device's clock, counts as today.
    nonisolated static func dateHeading(for date: Date, now: Date, calendar: Calendar) -> Heading {
        let today = calendar.startOfDay(for: now)
        if date >= today { return .init(id: "today", title: "Today") }
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: today) ?? today }
        if date >= daysAgo(1) { return .init(id: "yesterday", title: "Yesterday") }
        if date >= daysAgo(7) { return .init(id: "week", title: "Previous 7 Days") }
        if date >= daysAgo(30) { return .init(id: "month", title: "Previous 30 Days") }

        let year = calendar.component(.year, from: date)
        if year == calendar.component(.year, from: now) {
            let month = calendar.component(.month, from: date)
            var style = Date.FormatStyle.dateTime.month(.wide)
            style.calendar = calendar
            style.timeZone = calendar.timeZone
            return .init(id: "month-\(month)", title: date.formatted(style))
        }
        return .init(id: "year-\(year)", title: String(year))
    }

    /// The name Music sorts a title or artist by: a leading "The", "A" or
    /// "An" is skipped, so The Beatles file under B. A name that's only the
    /// article keeps it.
    nonisolated static func sortingName(_ name: String) -> Substring {
        for article in ["The ", "A ", "An "] {
            guard name.count > article.count,
                  name.prefix(article.count).caseInsensitiveCompare(article) == .orderedSame
            else { continue }
            return name.dropFirst(article.count).drop(while: \.isWhitespace)
        }
        return Substring(name)
    }

    /// The title's first letter, folded so "É" files under "E"; anything
    /// that isn't a letter goes under "#", as Music's index does.
    nonisolated static func indexLetter<S: StringProtocol>(for title: S) -> String {
        guard let first = title.first, first.isLetter else { return "#" }
        return String(first)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .uppercased()
    }
}
