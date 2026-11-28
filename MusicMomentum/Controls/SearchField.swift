//
//  SearchField.swift
//  MusicMomentum
//

import SwiftUI

#if os(macOS)
/// `.searchable` only lives in a toolbar, which the Mac dialog doesn't have.
struct SearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.quaternary.opacity(0.6), in: .capsule)
        .onAppear { isFocused = true }
    }
}
#endif
