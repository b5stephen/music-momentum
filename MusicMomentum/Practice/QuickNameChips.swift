//
//  QuickNameChips.swift
//  MusicMomentum
//

import SwiftUI

/// The quick-pick names as a row of chips that scrolls sideways. In a sheet
/// the chosen one is a coral tint; on the player, where there's no coral,
/// chips are the ink at the inactive fill and the chosen one solid ink.
struct QuickNameChips: View {
    enum Style {
        case sheet
        case player
    }

    let selected: String?
    let style: Style
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(QuickName.all, id: \.self) { chip in
                    chipButton(chip)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, style == .sheet ? 16 : 12, for: .scrollContent)
    }

    private func chipButton(_ chip: String) -> some View {
        let isSelected = chip == selected
        return Button {
            onPick(chip)
        } label: {
            Text(chip)
                .font(style == .sheet ? .body : .subheadline.weight(.medium))
                .foregroundStyle(foreground(isSelected))
                .padding(.horizontal, style == .sheet ? 18 : 14)
                .frame(minHeight: 44)
                .background(fill(isSelected), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foreground(_ isSelected: Bool) -> AnyShapeStyle {
        switch (style, isSelected) {
        case (.sheet, true): AnyShapeStyle(Color.accentText)
        case (.sheet, false): AnyShapeStyle(.primary)
        case (.player, true): AnyShapeStyle(.background)
        case (.player, false): AnyShapeStyle(.primary)
        }
    }

    private func fill(_ isSelected: Bool) -> AnyShapeStyle {
        switch (style, isSelected) {
        case (.sheet, true): AnyShapeStyle(Color.accentColor.opacity(0.14))
        case (.sheet, false): AnyShapeStyle(Color(.tertiarySystemFill))
        case (.player, true): AnyShapeStyle(.primary)
        case (.player, false): AnyShapeStyle(.primary.opacity(ArtworkPalette.inactiveInk))
        }
    }
}

#Preview("Sheet") {
    QuickNameChips(selected: "Chorus", style: .sheet) { _ in }
        .padding(.vertical)
}

#Preview("Player") {
    QuickNameChips(selected: nil, style: .player) { _ in }
        .padding(.vertical)
        .background(.indigo)
        .foregroundStyle(.white)
}
