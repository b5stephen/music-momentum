//
//  SaveSongButton.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI

/// The end of a song row: a + that puts the song in the environment's
/// `saveTarget` without opening it, or a tick once it's there. The row's own
/// tap still opens the song, so trying a song and keeping one are two
/// controls rather than a rule about which screen the picker came from.
///
/// The tick only reports: taking a song out of Saved can delete its markers,
/// so that stays in Saved, which asks first.
struct SaveSongButton: View {
    private let songID: String
    private let catalogID: String?
    private let title: String
    /// `nil` for a row that's already a saved song.
    private let song: Song?
    /// Hover or selection; on the Mac the + shows only then, as Music's does,
    /// so a long album isn't a column of plus signs. The tick always shows.
    var isRowActive = true

    @Environment(\.saveTarget) private var target
    @Environment(\.saveFeedback) private var feedback
    @Environment(\.modelContext) private var modelContext
    @Query private var matches: [SavedSong]
    @State private var justAdded = false

    init(song: Song, isRowActive: Bool = true) {
        self.init(songID: song.id.rawValue, catalogID: song.catalogID, title: song.title, song: song, isRowActive: isRowActive)
    }

    /// A saved song's row already says it's saved, so it skips "In Saved".
    init(saved: SavedSong, isRowActive: Bool = true) {
        self.init(songID: saved.songID, catalogID: saved.catalogID, title: saved.title, song: nil, isRowActive: isRowActive)
    }

    private init(songID: String, catalogID: String?, title: String, song: Song?, isRowActive: Bool) {
        self.songID = songID
        self.catalogID = catalogID
        self.title = title
        self.song = song
        self.isRowActive = isRowActive
        // `SavedSong.find`'s rule: a library ID saved on another device only
        // matches through the catalog ID.
        if let catalogID {
            let wanted: String? = catalogID
            _matches = Query(filter: #Predicate<SavedSong> {
                $0.songID == songID || $0.songID == catalogID || $0.catalogID == wanted
            })
        } else {
            _matches = Query(filter: #Predicate<SavedSong> { $0.songID == songID })
        }
    }

    var body: some View {
        if let target {
            let saved = matches.first
            if target.contains(saved) {
                tick(in: target)
            } else {
                HStack(spacing: 6) {
                    // In a list, a song that's saved already only joins the
                    // list, which the + alone wouldn't say.
                    if target.list != nil, saved != nil, song != nil {
                        Text("In Saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    plus(in: target, saved: saved)
                }
            }
        }
    }

    private func tick(in target: SaveTarget) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: Self.glyphSize, weight: .semibold))
            .foregroundStyle(justAdded ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .frame(width: Self.side, height: Self.side)
            .contentTransition(.symbolEffect(.replace))
            .help("In \(target.name)")
            .accessibilityLabel("In \(target.name)")
    }

    private func plus(in target: SaveTarget, saved: SavedSong?) -> some View {
        Button {
            add(to: target, saved: saved)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: Self.glyphSize, weight: .bold))
                .foregroundStyle(.tint)
                .frame(width: Self.circle, height: Self.circle)
                .background(.tint.opacity(0.15), in: .circle)
                .frame(width: Self.side, height: Self.side)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .opacity(isRowActive ? 1 : 0)
        #endif
        .help("Add to \(target.name) without opening it")
        .accessibilityLabel("Add \(title) to \(target.name)")
    }

    private func add(to target: SaveTarget, saved: SavedSong?) {
        let wasSaved = saved != nil
        if let saved {
            target.add(saved, in: modelContext)
        } else if let song {
            target.add(song, in: modelContext)
        } else {
            return
        }
        withAnimation(.snappy) { justAdded = true }
        let destination = target.list == nil || wasSaved ? target.name : "Saved and \(target.name)"
        feedback?.show("Added \u{201C}\(title)\u{201D} to \(destination)")
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.4)) { justAdded = false }
        }
    }

    #if os(macOS)
    private static let side: CGFloat = 24
    private static let circle: CGFloat = 20
    private static let glyphSize: CGFloat = 10
    #else
    /// A 44pt target around a 28pt mark.
    private static let side: CGFloat = 44
    private static let circle: CGFloat = 28
    private static let glyphSize: CGFloat = 13
    #endif
}
