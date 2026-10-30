//
//  InlineNameField.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// A name typed in place on the timeline: renaming a marker, and, in time,
/// naming a clip just dragged out. Return keeps, Escape or clicking away
/// discards, and a blank name is the caller's to interpret.
struct InlineNameField: View {
    let initialText: String
    var width: CGFloat = 140
    var showsHint = true
    /// Preview only: draws the focus ring without waiting for a window.
    var startsFocused = false
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool
    /// Clicking away reads as losing focus, but so does Return; only the
    /// first of the two outcomes counts. Focus also starts out lost.
    @State private var hasFocused = false
    @State private var isFinished = false

    init(
        initialText: String = "",
        width: CGFloat = 140,
        showsHint: Bool = true,
        startsFocused: Bool = false,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialText = initialText
        self.width = width
        self.showsHint = showsHint
        self.startsFocused = startsFocused
        self.onCommit = onCommit
        self.onCancel = onCancel
        _text = State(initialValue: initialText)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text("Name").foregroundStyle(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .focusEffectDisabled()
                .font(.system(size: 12))
                .foregroundStyle(.white)
                // Also the selection colour, which a solid white would hide the text in.
                .tint(.white.opacity(0.45))
                .padding(.horizontal, 9)
                .frame(width: width, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(red: 20 / 255, green: 24 / 255, blue: 26 / 255).opacity(0.94))
                }
                .overlay {
                    // The text colour, not the accent, as on everything else here.
                    if isFocused || startsFocused {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                    }
                }
                .onSubmit { finish { onCommit(text) } }
                .onExitCommand { finish(onCancel) }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        hasFocused = true
                    } else if hasFocused {
                        finish(onCancel)
                    }
                }
                .task { isFocused = true }
            if showsHint {
                Text("Return to keep \u{00B7} Esc to discard")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .fixedSize()
                    // Over a neighbouring clip it would otherwise run into its name.
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Color(red: 20 / 255, green: 24 / 255, blue: 26 / 255).opacity(0.95), in: .capsule)
            }
        }
    }

    private func finish(_ action: () -> Void) {
        guard !isFinished else { return }
        isFinished = true
        action()
    }

    /// The hint's room, for a caller placing the field near an edge.
    static let hintWidth: CGFloat = 184
}

#Preview("Inline name field", traits: .fixedLayout(width: 420, height: 110)) {
    VStack(alignment: .leading, spacing: 16) {
        InlineNameField(initialText: "Bridge riff", startsFocused: true, onCommit: { _ in }, onCancel: {})
        InlineNameField(initialText: "", startsFocused: true, onCommit: { _ in }, onCancel: {})
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color(red: 9 / 255, green: 21 / 255, blue: 23 / 255))
}
#endif
