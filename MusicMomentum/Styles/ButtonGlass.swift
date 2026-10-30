//
//  ButtonGlass.swift
//  MusicMomentum
//

import SwiftUI

/// Glass for Practice's buttons, smoked on a bright cover, where clear glass
/// under light text washes out. In a glass panel, a flat fill and hairline.
struct ButtonGlass: ViewModifier {
    @Environment(\.smokedFill) private var smokedFill
    @Environment(\.inGlassPanel) private var inGlassPanel

    func body(content: Content) -> some View {
        if inGlassPanel {
            content
                .background(.primary.opacity(0.1), in: .capsule)
                .overlay { Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 1) }
        } else {
            content.glassEffect(glass.interactive(), in: .capsule)
        }
    }

    private var glass: Glass {
        if let smokedFill { return .regular.tint(smokedFill) }
        return .regular
    }
}
