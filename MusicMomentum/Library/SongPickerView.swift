//
//  SongPickerView.swift
//  MusicMomentum
//
//  Stands in for a `.musicPicker` modifier MusicKit doesn't ship (as of the
//  iOS 26.5 SDK it has no SwiftUI views beyond `ArtworkImage`).
//

import MusicKit
import SwiftData
import SwiftUI

struct SongPickerView: View {
    /// A Mac sheet says what it will do: "Open" from Change Song, "Add" from
    /// a +. iOS picks on tap and shows neither button.
    var title = "Choose Song"
    var confirmTitle = "Open"
    /// Where the rows' + puts a song. An add picker opened from inside a list
    /// targets the list, and its title names it.
    var target: SaveTarget = .saved
    let onSelect: (Song) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked = PickedSong()
    @State private var searchTerm = ""

    /// "Add to Acoustic", or "Add to Saved" outside a list.
    static func addTitle(for target: SaveTarget) -> String {
        "Add to \(target.name)"
    }

    var body: some View {
        #if os(macOS)
        // A sheet's toolbar on the Mac puts the title in its own band under the
        // search field, and lets the list scroll under the buttons, so the
        // dialog lays out its own chrome around the stack.
        VStack(spacing: 0) {
            header
            Divider()
            NavigationStack {
                // A message is only as tall as its text; without this the
                // whole dialog floats in the middle of the sheet.
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            buttons
        }
        .modifier(PickerEnvironment(picked: picked, target: target, actionTitle: confirmTitle))
        .onChange(of: searchTerm) { picked.clear() }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 600)
        #else
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                    }
                }
                .searchable(text: $searchTerm, prompt: Self.searchPrompt)
        }
        .modifier(PickerEnvironment(picked: picked, target: target, actionTitle: confirmTitle))
        #endif
    }

    static let searchPrompt = "Saved, your library and Apple Music"

    @ViewBuilder
    private var content: some View {
        if searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            LibraryBrowseView { choose($0) }
        } else {
            SongSearchResults(term: searchTerm) { choose($0) }
        }
    }

    private func choose(_ song: Song) {
        onSelect(song)
        dismiss()
    }

    #if os(macOS)
    private var header: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
            SearchField(text: $searchTerm, prompt: Self.searchPrompt)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(confirmTitle) {
                if let song = picked.song { choose(song) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(picked.song == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider() }
    }
    #endif
}

/// What every song row inside a picker reads: the Mac's pending pick, where
/// + saves to, what choosing is called, and the line a + raises.
private struct PickerEnvironment: ViewModifier {
    let picked: PickedSong
    let target: SaveTarget
    let actionTitle: String

    func body(content: Content) -> some View {
        content
            .environment(\.pickedSong, picked)
            .environment(\.saveTarget, target)
            .environment(\.pickActionTitle, actionTitle)
            .showsSaveFeedback()
    }
}

#if os(macOS)
/// `.searchable` only lives in a toolbar, which the Mac dialog doesn't have.
private struct SearchField: View {
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

// MARK: - Previews

#Preview("Browsing") {
    SongPickerView { _ in }
        .modelContainer(try! AppSchema.inMemoryContainer())
}

#if os(macOS)
#Preview("Add to Saved, Mac") {
    SongPickerView(title: "Add to Saved", confirmTitle: "Add") { _ in }
        .modelContainer(try! AppSchema.inMemoryContainer())
}
#endif

