//
//  PlayerCard.swift
//  MusicMomentum
//

import SwiftUI

/// What the naming prompt and the Undo toast float on over the player: the
/// ground's own darker shade (`onInk`, the screen's background style) with
/// a hairline of the ink. Glass let the Play | Loop control show through
/// and read as clutter.
struct PlayerCard<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
            .background(.background, in: shape)
            .overlay { shape.stroke(.primary.opacity(0.18), lineWidth: 1) }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}
