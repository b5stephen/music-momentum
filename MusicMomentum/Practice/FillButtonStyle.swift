//
//  FillButtonStyle.swift
//  MusicMomentum
//

import SwiftUI

/// The sheet's buttons: a capsule on a system fill, which keeps them quieter
/// than `.bordered` and leaves the coral to looping. Loop fills solid when on.
/// `.nudge` sits on a card, so it takes the lightest fill; `.action` sits on
/// the sheet's own background and takes the next one up.
struct FillButtonStyle: ButtonStyle {
    enum Size {
        case nudge, action

        var height: CGFloat { self == .nudge ? 44 : 48 }
        var fill: Color { self == .nudge ? .tertiarySystemFill : .secondarySystemFill }
    }

    var size: Size = .nudge
    var isOn = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: size.height)
            .background(isOn ? Color.accentColor : size.fill, in: Capsule())
            .foregroundStyle(isOn ? AnyShapeStyle(Color.onAccent) : AnyShapeStyle(.primary))
            .opacity(configuration.isPressed ? 0.5 : isEnabled ? 1 : 0.4)
    }
}
