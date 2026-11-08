//
//  SpeedPresetItems.swift
//  MusicMomentum
//

import SwiftUI

/// The one-click speeds, for the Speed menu and the knob's right-click menu:
/// every 5% from 50 to 100, ticked when current, then the way back to the
/// saved speed.
struct SpeedPresetItems: View {
    var percent: Int
    var savedPercent: Int?
    var set: @MainActor (Int) -> Void

    var body: some View {
        ForEach(SpeedInput.menuSpeeds, id: \.self) { preset in
            Toggle("\(preset)%", isOn: Binding(get: { percent == preset }, set: { _ in set(preset) }))
        }
        Divider()
        Button(savedPercent.map { "Saved Speed (\($0)%)" } ?? "Saved Speed") {
            if let savedPercent { set(savedPercent) }
        }
        .disabled(savedPercent == nil || savedPercent == percent)
    }
}
