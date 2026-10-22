//
//  NamingPrompt.swift
//  MusicMomentum
//

import SwiftUI

/// "Name it?" after Add marker, A·B or Split made a marker: the quick-pick
/// names and Skip on a small card over the player, not a sheet, so
/// marking mid-song never stops to ask. It goes by itself after a few
/// seconds, leaving the marker unnamed; with VoiceOver on it waits for Skip,
/// since a card that vanishes mid-read can't be answered.
struct NamingPrompt: View {
    /// What the new marker is called until it's named, "Marker 3".
    let markerName: String
    let onPick: (String) -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    static let lifetime: Duration = .seconds(8)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Name it?")
                    .font(.subheadline.weight(.semibold))
                Text(markerName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Skip", action: onSkip)
                    .font(.subheadline.weight(.medium))
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)

            QuickNameChips(selected: nil, style: .player, onPick: onPick)
                .padding(.bottom, 10)
        }
        .modifier(PlayerCard(shape: .rect(cornerRadius: 24, style: .continuous)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Name \(markerName)")
        .task {
            guard !voiceOver else { return }
            try? await Task.sleep(for: Self.lifetime)
            guard !Task.isCancelled else { return }
            onSkip()
        }
    }
}

#Preview {
    NamingPrompt(markerName: "Marker 3", onPick: { _ in }, onSkip: {})
        .padding()
        .frame(maxHeight: .infinity)
        .background(.indigo)
        .foregroundStyle(.white)
}
