//
//  SongPickerRow.swift
//  MusicMomentum
//

import MusicKit
import Observation
import SwiftData
import SwiftUI

/// The song a Mac picker has highlighted but not yet confirmed. A Mac sheet
/// has an Open or Add button, so a click chooses and Return or a double-click
/// confirms; on iOS a tap does both and nothing is held.
@MainActor @Observable
final class PickedSong {
    var song: Song?
    /// The saved song behind a "Practising lately" row, whose `Song` is still
    /// being looked up when it's clicked.
    var savedID: String?

    func clear() {
        song = nil
        savedID = nil
    }
}

extension EnvironmentValues {
    @Entry var pickedSong: PickedSong?
    /// What choosing a row does, for the Mac's context menu: "Open" in Change
    /// Song, "Add" in an add picker, "Practice" in the window's library.
    @Entry var pickActionTitle = "Open"
}

/// A row that picks a song, with `SaveSongButton` at its end.
struct SongPickerRow<Label: View>: View {
    let song: Song
    let onSelect: (Song) -> Void
    @ViewBuilder var label: Label

    @Environment(\.pickedSong) private var picked
    @Environment(\.saveTarget) private var target
    @Environment(\.modelContext) private var modelContext
    @Environment(\.saveFeedback) private var feedback
    @Environment(\.pickActionTitle) private var actionTitle
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            pickArea
            SaveSongButton(song: song, isRowActive: isHovered || isPicked)
        }
        #if os(macOS)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(.primary.opacity(isPicked ? 0.14 : isHovered ? 0.06 : 0), in: .rect(cornerRadius: 6))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(actionTitle) { onSelect(song) }
            if let target {
                Button("Add to \(target.name)") {
                    target.add(song, in: modelContext)
                    feedback?.show("Added \u{201C}\(song.title)\u{201D} to \(target.name)")
                }
            }
        }
        #endif
    }

    private var isPicked: Bool { picked?.song?.id == song.id }

    @ViewBuilder
    private var pickArea: some View {
        #if os(macOS)
        label
            .contentShape(.rect)
            .onTapGesture(count: 2) { onSelect(song) }
            .simultaneousGesture(TapGesture().onEnded { picked?.song = song; picked?.savedID = nil })
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { picked?.song = song }
        #else
        Button {
            onSelect(song)
        } label: {
            label
        }
        .buttonStyle(.plain)
        #endif
    }
}
