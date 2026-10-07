//
//  EdgeFade.swift
//  MusicMomentum
//

import SwiftUI

/// Fades a horizontal edge out where content carries on past it. Edges with
/// nothing beyond them stay crisp, so a fade always means there's more.
struct EdgeFade: ViewModifier {
    var leading: Bool
    var trailing: Bool
    var width: CGFloat = 28

    func body(content: Content) -> some View {
        content.mask {
            GeometryReader { proxy in
                let fade = min(0.5, width / max(proxy.size.width, 1))
                LinearGradient(
                    stops: [
                        .init(color: leading ? .clear : .black, location: 0),
                        .init(color: .black, location: fade),
                        .init(color: .black, location: 1 - fade),
                        .init(color: trailing ? .clear : .black, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }
}

extension View {
    func edgeFade(leading: Bool, trailing: Bool, width: CGFloat = 28) -> some View {
        modifier(EdgeFade(leading: leading, trailing: trailing, width: width))
    }
}
