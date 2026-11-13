//
//  FillButtonStyle.swift
//  MusicMomentum
//

import SwiftUI

/// The nudge and cue buttons: a capsule on the lightest system fill, which
/// keeps them quieter than `.bordered` and leaves the coral to looping. Loop
/// fills solid when on.
struct FillButtonStyle: ButtonStyle {
    var isOn = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .background(isOn ? Color.accentColor : Color.tertiarySystemFill, in: Capsule())
            .foregroundStyle(isOn ? AnyShapeStyle(Color.onAccent) : AnyShapeStyle(.primary))
            .opacity(configuration.isPressed ? 0.5 : isEnabled ? 1 : 0.4)
    }
}
