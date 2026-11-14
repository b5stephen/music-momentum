//
//  InlineNameField.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

/// A name typed in place on the timeline: renaming a marker, and, in time,
/// naming a clip just dragged out. Return keeps, Escape or clicking away
/// discards, and a blank name is the caller's to interpret. Suggestions, if
/// any, hang under the field: ↓ and ↑ highlight, Return keeps the highlighted
/// one, and a click keeps the row clicked.
struct InlineNameField: View {
    let initialText: String
    var width: CGFloat = 150
    var showsHint = true
    /// The hint promises Escape leaves `initialText` as it was, rather than discarding.
    var escapeKeeps = false
    /// Preview only: draws the focus ring without waiting for a window.
    var startsFocused = false
    var suggestions: [String] = []
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool
    /// Clicking away reads as losing focus, but so does Return; only the
    /// first of the two outcomes counts. Focus also starts out lost.
    @State private var hasFocused = false
    @State private var isFinished = false
    @State private var highlighted: Int?
    /// A click on a row first takes focus from the field; that mustn't count as clicking away.
    @State private var isOverList = false

    private static let ground = Color(red: 20 / 255, green: 24 / 255, blue: 26 / 255)
    private static let rowHeight: CGFloat = 24

    init(
        initialText: String = "",
        width: CGFloat = 150,
        showsHint: Bool = true,
        escapeKeeps: Bool = false,
        startsFocused: Bool = false,
        suggestions: [String] = [],
        /// The row Return keeps until the user types or arrows, so an offered name is one keystroke away.
        initialHighlight: Int? = nil,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialText = initialText
        self.width = width
        self.showsHint = showsHint
        self.escapeKeeps = escapeKeeps
        self.startsFocused = startsFocused
        self.suggestions = suggestions
        self.onCommit = onCommit
        self.onCancel = onCancel
        _text = State(initialValue: initialText)
        _highlighted = State(initialValue: initialHighlight)
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
                        .fill(Self.ground.opacity(0.94))
                }
                .overlay {
                    // The text colour, not the accent, as on everything else here.
                    if isFocused || startsFocused {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                    }
                }
                .onSubmit {
                    let kept = highlighted.flatMap { suggestions.indices.contains($0) ? suggestions[$0] : nil }
                    finish { onCommit(kept ?? text) }
                }
                .onExitCommand { finish(onCancel) }
                .onKeyPress(.downArrow) { moveHighlight(1) }
                .onKeyPress(.upArrow) { moveHighlight(-1) }
                .onChange(of: text) { highlighted = nil }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        hasFocused = true
                    } else if hasFocused, !isOverList {
                        finish(onCancel)
                    }
                }
                .task {
                    isFocused = true
                    // So typing replaces the old name, whether or not focusing selected it.
                    try? await Task.sleep(for: .milliseconds(50))
                    #if os(macOS)
                    if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isFieldEditor {
                        editor.selectAll(nil)
                    }
                    #endif
                }
                .overlay(alignment: .topLeading) {
                    if !suggestions.isEmpty {
                        suggestionList
                            .offset(y: 26 + 6)
                    }
                }
            if showsHint {
                Text(escapeKeeps ? "Return to keep \u{00B7} Esc keeps \(initialText)" : "Return to keep \u{00B7} Esc to discard")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    // Over a neighbouring clip it would otherwise run into its name.
                    .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    .lineLimit(1)
                    .frame(maxWidth: Self.hintWidth, alignment: .leading)
            }
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, name in
                Button {
                    finish { onCommit(name) }
                } label: {
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(width: width, height: Self.rowHeight, alignment: .leading)
                        .background(.white.opacity(highlighted == index ? 0.18 : 0), in: .rect(cornerRadius: 5))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 14 / 255, green: 20 / 255, blue: 24 / 255).opacity(0.96))
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 10)
        }
        .fixedSize()
        .onHover { isOverList = $0 }
    }

    private func moveHighlight(_ step: Int) -> KeyPress.Result {
        guard !suggestions.isEmpty else { return .ignored }
        let next = (highlighted ?? -1) + step
        highlighted = next < 0 ? nil : min(next, suggestions.count - 1)
        return .handled
    }

    private func finish(_ action: () -> Void) {
        guard !isFinished else { return }
        isFinished = true
        action()
    }

    /// The hint's room, for a caller placing the field near an edge.
    static let hintWidth: CGFloat = 230
}

#Preview("Inline name field with suggestions", traits: .fixedLayout(width: 480, height: 230)) {
    HStack(alignment: .top, spacing: 24) {
        InlineNameField(
            initialText: "Marker 7", escapeKeeps: true, startsFocused: true,
            suggestions: ["Chorus", "Verse 2", "Bridge", "Solo", "Pre-chorus"], initialHighlight: 0, onCommit: { _ in }, onCancel: {}
        )
        InlineNameField(
            initialText: "Marker 7", width: 120, showsHint: false, startsFocused: true,
            suggestions: ["Chorus", "Verse 2", "Bridge", "Solo", "Pre-chorus"], initialHighlight: 1,
            onCommit: { _ in }, onCancel: {}
        )
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(red: 9 / 255, green: 21 / 255, blue: 23 / 255))
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
