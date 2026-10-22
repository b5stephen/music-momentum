//
//  QuickName.swift
//  MusicMomentum
//

import Foundation

/// The quick-pick names offered by the Edit Marker sheet and the "Name it?"
/// prompt. A song has more than one verse, so a name already taken gets the
/// next number: the second Verse is "Verse 2".
nonisolated enum QuickName {
    static let all = ["Intro", "Verse", "Chorus", "Bridge", "Solo", "Outro"]

    /// "Verse" and "Verse 2" both select the Verse chip.
    static func matches(_ chip: String, name: String) -> Bool {
        number(of: chip, in: name) != nil
    }

    /// `taken` is the song's other markers' names, not the one being named.
    static func name(for chip: String, taken: [String]) -> String {
        let highest = taken.compactMap { number(of: chip, in: $0) }.max()
        guard let highest else { return chip }
        return "\(chip) \(highest + 1)"
    }

    /// 1 for the bare chip, N for "chip N", `nil` for anything else.
    private static func number(of chip: String, in name: String) -> Int? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.lowercased().hasPrefix(chip.lowercased()) else { return nil }
        let rest = name.dropFirst(chip.count)
        if rest.isEmpty { return 1 }
        guard rest.first == " ", let number = Int(rest.dropFirst()), number > 0 else { return nil }
        return number
    }
}
