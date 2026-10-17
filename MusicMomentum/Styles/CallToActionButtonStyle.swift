//
//  CallToActionButtonStyle.swift
//  MusicMomentum
//

import SwiftUI

/// An empty screen's one button, such as Choose a Song or Add Song. Tinted
/// rather than solid, so it's the same coral as the save prompt and speed
/// pills: a solid fill reads as a brighter, other colour. Drawn by hand
/// because `.bordered` turns grey once its text is recoloured. Practice's and
/// Saved's were drawn apart and came out different sizes, one with an icon.
struct CallToActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.accentText)
            .frame(height: 50)
            .padding(.horizontal, 30)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}
