//
//  CoverArt.swift
//  MusicMomentum
//

import MusicKit
import SwiftUI

/// A song's cover, or a quiet note in its place when it has no artwork.
struct CoverArt: View {
    let artwork: Artwork?
    /// Only for the debug samples, which draw their own cover over the placeholder.
    let songID: String
    let side: CGFloat
    var radius: CGFloat?

    var body: some View {
        let radius = radius ?? side / 8
        if let artwork {
            ArtworkImage(artwork, width: side, height: side)
                .clipShape(.rect(cornerRadius: radius))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: radius)
                .fill(.quaternary)
                .frame(width: side, height: side)
                .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                .sampleCover(songID: songID, cornerRadius: radius)
                .accessibilityHidden(true)
        }
    }
}
