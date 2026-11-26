//
//  PlayingInMusicSection.swift
//  MusicMomentum
//

#if os(iOS)
import Combine
import MusicKit
import SwiftUI

/// The song the Music app has queued, offered first: hearing a song in Music
/// and wanting to work on it is the commonest way in. `SystemMusicPlayer` is
/// unavailable on macOS, where Recently Played stands in.
struct PlayingInMusicSection: View {
    let onSelect: (Song) -> Void

    @State private var song: Song?

    var body: some View {
        Group {
            if let song {
                Section {
                    HStack(spacing: 4) {
                        Button { onSelect(song) } label: { label(song) }
                            .buttonStyle(.plain)
                        SaveSongButton(song: song)
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(SystemMusicPlayer.shared.queue.objectWillChange) {
            // `objectWillChange` fires before the entry changes.
            Task { refresh() }
        }
    }

    private func refresh() {
        guard case .song(let current)? = SystemMusicPlayer.shared.queue.currentEntry?.item else {
            song = nil
            return
        }
        if song?.id != current.id { song = current }
    }

    private func label(_ song: Song) -> some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = song.artwork {
                    ArtworkImage(artwork, width: 56, height: 56)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Label("Playing in Music", systemImage: "music.note")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("Practise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.tint.opacity(0.14), in: .capsule)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Practise \(song.title) by \(song.artistName), playing in Music")
    }
}
#endif
