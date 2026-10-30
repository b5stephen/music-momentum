//
//  SavedSongArtwork.swift
//  MusicMomentum
//

import MusicKit
import SwiftUI

/// A saved song's cover, with a spinner in its place while the song loads
/// and a note when it has no artwork.
struct SavedSongArtwork: View {
    let song: SavedSong
    let side: CGFloat
    var isLoading = false

    var body: some View {
        if isLoading {
            placeholder { ProgressView() }
        } else if let artwork = song.artwork {
            ArtworkImage(artwork, width: side, height: side)
                .clipShape(.rect(cornerRadius: 6))
        } else {
            placeholder { Image(systemName: "music.note").foregroundStyle(.secondary) }
                .sampleCover(songID: song.songID, cornerRadius: 6)
        }
    }

    private func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .frame(width: side, height: side)
            .overlay(content())
    }
}

#Preview("Without artwork") {
    HStack(spacing: 12) {
        SavedSongArtwork(song: SavedSong(songID: "1", speed: 0.75, title: "Blackbird", artistName: "The Beatles"), side: 48)
        SavedSongArtwork(song: SavedSong(songID: "1", speed: 0.75, title: "Blackbird", artistName: "The Beatles"), side: 36, isLoading: true)
    }
    .padding()
}
