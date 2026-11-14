//
//  MarkerNameSuggestions.swift
//  MusicMomentum
//

import Foundation

nonisolated enum MarkerNameSuggestions {
    private static let sectionVocabulary = ["Verse", "Chorus", "Bridge", "Solo", "Pre-chorus", "Outro", "Intro"]
    private static let loopVocabulary = ["Riff", "Lick", "Fill", "Solo", "Run"]
    private static let follows = [
        "Intro": "Verse",
        "Verse": "Chorus",
        "Pre-chorus": "Chorus",
        "Chorus": "Verse",
        "Bridge": "Chorus",
        "Solo": "Chorus",
        "Outro": "Outro",
    ]
    private static let count = 5

    /// `others` are the song's other points; the marker being named is excluded by the caller.
    static func forMarker(at start: TimeInterval, among others: [(name: String, start: TimeInterval)]) -> [String] {
        var guess: String?
        if let previous = others.filter({ $0.start < start }).max(by: { $0.start < $1.start }) {
            if let base = vocabularyEntry(for: baseName(previous.name), in: sectionVocabulary) {
                guess = follows[base]
            }
        } else {
            guess = "Intro"
        }
        var order = sectionVocabulary
        if let guess {
            order = [guess] + sectionVocabulary.filter { $0 != guess }
        }
        return order.prefix(count).map { numbered($0, among: others.map(\.name)) }
    }

    /// "Marker 7" or "Loop 2": what a marker is called until someone names it.
    static func isDefaultName(_ name: String) -> Bool {
        name.wholeMatch(of: /(Marker|Loop) \d+/) != nil
    }

    static func forLoop(among loopNames: [String]) -> [String] {
        loopVocabulary.map { numbered($0, among: loopNames) }
    }

    private static func baseName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let space = trimmed.lastIndex(of: " ") else { return trimmed }
        let tail = trimmed[trimmed.index(after: space)...]
        guard !tail.isEmpty, tail.allSatisfy(\.isASCII), tail.allSatisfy(\.isNumber) else { return trimmed }
        return String(trimmed[..<space]).trimmingCharacters(in: .whitespaces)
    }

    private static func number(of name: String) -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let space = trimmed.lastIndex(of: " "),
              let value = Int(trimmed[trimmed.index(after: space)...]) else { return 1 }
        return value
    }

    private static func vocabularyEntry(for base: String, in vocabulary: [String]) -> String? {
        vocabulary.first { $0.caseInsensitiveCompare(base) == .orderedSame }
    }

    private static func numbered(_ base: String, among names: [String]) -> String {
        let used = names.filter { baseName($0).caseInsensitiveCompare(base) == .orderedSame }
        guard !used.isEmpty else { return base }
        let highest = used.map(number(of:)).max() ?? 1
        return "\(base) \(highest + 1)"
    }
}
