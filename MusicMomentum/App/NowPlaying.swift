//
//  NowPlaying.swift
//  MusicMomentum
//

#if os(macOS)
import MusicKit
import SwiftUI

/// Hands the scenes that show the loaded song (the mini player, the menu bar)
/// the song's `Track`, read here so they redraw when the song changes. The
/// palette is the one Practice has already worked out and reported to the app.
struct NowPlaying<Content: View>: View {
    let controller: PlaybackController
    let palette: ArtworkPalette?
    /// Stands in for a loaded song; see `SampleSong`.
    var sampleTrack: PracticeView.Track?
    @ViewBuilder var content: (PracticeView.Track?) -> Content

    var body: some View {
        content(track)
    }

    private var track: PracticeView.Track? {
        if let song = controller.selectedSong { return PracticeView.Track(song: song, palette: palette) }
        guard var sampleTrack else { return nil }
        sampleTrack.palette = palette ?? sampleTrack.palette
        return sampleTrack
    }
}

private extension PracticeView.Track {
    init(song: Song, palette: ArtworkPalette?) {
        self.init(
            id: song.id.rawValue,
            catalogID: song.catalogID,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle,
            palette: palette ?? ArtworkPalette(song.artwork),
            artwork: song.artwork
        )
    }
}
#endif
