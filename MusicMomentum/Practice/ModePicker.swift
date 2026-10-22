//
//  ModePicker.swift
//  MusicMomentum
//

import SwiftUI

/// Play | Loop on the player. Drawn by hand rather than a segmented
/// `Picker`, which can't take the cover's colours: the selected half is a
/// solid capsule of the text colour with the ground's colour as its text.
struct ModePicker: View {
    let selection: PlayerMode
    var onSelect: (PlayerMode) -> Void

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlayerMode.allCases, id: \.self) { mode in
                let isSelected = mode == selection
                Button {
                    guard !isSelected else { return }
                    withAnimation(.snappy(duration: 0.25)) { onSelect(mode) }
                } label: {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(.primary)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        // Reaches past the 34pt track to the 44pt minimum.
                        // An iPhone SE has no height for a taller track.
                        .contentShape(.rect.inset(by: -8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.primary.opacity(0.16), in: .capsule)
        .dynamicTypeSize(...PracticeLayout.headerTypeLimit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
    }
}

#Preview("Play") {
    ModePicker(selection: .play) { _ in }
        .padding()
}

#Preview("Loop, on a cover") {
    @Previewable @State var mode = PlayerMode.loop
    ModePicker(selection: mode) { mode = $0 }
        .padding()
        .foregroundStyle(.white)
        .backgroundStyle(Color(red: 0.13, green: 0.23, blue: 0.29))
        .background(Color(red: 0.13, green: 0.23, blue: 0.29))
}
