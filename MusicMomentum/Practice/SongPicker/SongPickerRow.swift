//
//  SongPickerRow.swift
//  MusicMomentum
//

import MusicKit
import Observation
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
}

/// A row that picks a song.
struct SongPickerRow<Label: View>: View {
    let song: Song
    let onSelect: (Song) -> Void
    @ViewBuilder var label: Label

    @Environment(\.pickedSong) private var picked

    var body: some View {
        #if os(macOS)
        label
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(.primary.opacity(picked?.song?.id == song.id ? 0.14 : 0), in: .rect(cornerRadius: 6))
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
