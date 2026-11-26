//
//  SavedPickRow.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI

/// A saved song offered for picking ("Practising lately", Saved's search
/// results). Its `Song` has to be looked up first, so the row owns the
/// spinner and the "not in your library any more" state.
struct SavedPickRow: View {
    let song: SavedSong
    var showsMarkers = false
    let onSelect: (Song) -> Void

    @Environment(\.pickedSong) private var picked
    @State private var isLoading = false
    @State private var isMissing = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            pickArea
            SaveSongButton(saved: song, isRowActive: isHovered || isPicked)
        }
        #if os(macOS)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(.primary.opacity(isPicked ? 0.14 : isHovered ? 0.06 : 0), in: .rect(cornerRadius: 6))
        .onHover { isHovered = $0 }
        #endif
    }

    private var isPicked: Bool { picked?.savedID == song.songID }

    private var label: some View {
        SavedPickRowLabel(song: song, showsMarkers: showsMarkers, isLoading: isLoading, isMissing: isMissing)
    }

    @ViewBuilder
    private var pickArea: some View {
        #if os(macOS)
        label
            .contentShape(.rect)
            .onTapGesture(count: 2) { open(confirming: true) }
            .simultaneousGesture(TapGesture().onEnded { open(confirming: false) })
            .accessibilityAddTraits(.isButton)
        #else
        Button {
            open(confirming: true)
        } label: {
            label
        }
        .buttonStyle(.plain)
        #endif
    }

    /// `confirming` is false on a Mac's single click, which only picks the
    /// song for the sheet's Open or Add button.
    private func open(confirming: Bool) {
        isLoading = true
        isMissing = false
        Task {
            let found = try? await SongLookup.song(libraryID: song.songID, catalogID: song.catalogID)
            isLoading = false
            guard let found else {
                isMissing = true
                return
            }
            if confirming {
                onSelect(found)
            } else {
                picked?.song = found
                picked?.savedID = song.songID
            }
        }
    }
}

private struct SavedPickRowLabel: View {
    let song: SavedSong
    let showsMarkers: Bool
    let isLoading: Bool
    let isMissing: Bool

    var body: some View {
        HStack(spacing: 12) {
            SavedSongArtwork(song: song, side: 40, isLoading: isLoading)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                // Yellow on the icon only: red text reads as the coral tint.
                HStack(spacing: 4) {
                    if isMissing {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                    Text(isMissing ? "Not in your library any more" : subtitle)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(song.percent)%")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let count = (song.markers ?? []).count
        guard showsMarkers, count > 0 else { return song.artistName }
        return "\(song.artistName) · \(count) \(count == 1 ? "marker" : "markers")"
    }
}
