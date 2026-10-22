//
//  UndoToast.swift
//  MusicMomentum
//

import SwiftUI

/// "Deleted Chorus · Undo", a small capsule over the player after the
/// Edit Marker sheet deletes a marker. Announced, so VoiceOver hears Undo is
/// there, and kept longer while VoiceOver is on.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void
    let onExpire: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        HStack(spacing: 4) {
            Text(message)
                .font(.subheadline)
                .lineLimit(1)
            Text("·")
                .foregroundStyle(.secondary)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline.weight(.bold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .modifier(PlayerCard(shape: .capsule))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Puts the marker back")
        .accessibilityAction(named: "Undo", onUndo)
        .task {
            AccessibilityNotification.Announcement("\(message). Undo available.").post()
            try? await Task.sleep(for: voiceOver ? .seconds(12) : .seconds(5))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}

#Preview {
    UndoToast(message: "Deleted Chorus", onUndo: {}, onExpire: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.indigo)
        .foregroundStyle(.white)
}
