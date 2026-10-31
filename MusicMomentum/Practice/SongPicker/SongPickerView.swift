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
    /// the sidebar's +. iOS picks on tap and shows neither button.
    var title = "Choose Song"
    var confirmTitle = "Open"
    let onSelect: (Song) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked = PickedSong()

    @State private var searchTerm = ""
    @State private var scope: SearchScope = .library
    @State private var results: MusicItemCollection<Song> = []
    @State private var isSearching = false
    @State private var searchError: String?

    enum SearchScope: String, CaseIterable, Identifiable {
        case library = "My Library"
        case catalog = "Apple Music"
        var id: Self { self }
    }

    var body: some View {
        #if os(macOS)
        // A sheet's toolbar on the Mac puts the title in its own band under the
        // search field, and lets the list scroll under the source picker and
        // the buttons, so the dialog lays out its own chrome around the stack.
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
        .environment(\.pickedSong, picked)
        .task(id: SearchKey(term: searchTerm, scope: scope)) { await runSearch() }
        .onChange(of: SearchKey(term: searchTerm, scope: scope)) { picked.clear() }
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
                    if isSearching {
                        ToolbarItem(placement: .confirmationAction) { ProgressView() }
                    }
                }
                .safeAreaInset(edge: .top) {
                    sourcePicker
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .searchable(text: $searchTerm, prompt: "Songs, artists, albums")
                .task(id: SearchKey(term: searchTerm, scope: scope)) { await runSearch() }
                .onChange(of: SearchKey(term: searchTerm, scope: scope)) { picked.clear() }
        }
        .environment(\.pickedSong, picked)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if let searchError {
            SearchMessage(kind: .failed(searchError))
        } else if searchTerm.isEmpty, scope == .library {
            LibraryBrowseView { choose($0) }
        } else if searchTerm.isEmpty {
            SearchMessage(kind: .prompt)
        } else if results.isEmpty {
            SearchMessage(kind: .noResults(searchTerm))
        } else {
            List(results) { song in
                SongPickerRow(song: song) { choose($0) } label: {
                    // The album is what tells recordings of one song apart.
                    SongRow(song: song, showsAlbum: true)
                }
            }
            .listStyle(.plain)
        }
    }

    private var sourcePicker: some View {
        Picker("Source", selection: $scope) {
            ForEach(SearchScope.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
            HStack(spacing: 8) {
                SearchField(text: $searchTerm, prompt: "Songs, artists, albums")
                ProgressView()
                    .controlSize(.small)
                    .opacity(isSearching ? 1 : 0)
            }
            sourcePicker
                .fixedSize()
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

    private func runSearch() async {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            searchError = nil
            isSearching = false
            return
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        isSearching = true
        let outcome: Result<MusicItemCollection<Song>, Error>
        do {
            switch scope {
            case .catalog:
                var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
                request.limit = 25
                outcome = .success(try await request.response().songs)
            case .library:
                var request = MusicLibrarySearchRequest(term: term, types: [Song.self])
                request.limit = 25
                outcome = .success(try await request.response().songs)
            }
        } catch {
            outcome = .failure(error)
        }

        // MusicKit reports a request cancelled mid-flight as a connection
        // error, not `CancellationError`. The first catalog search is slow
        // enough to be overtaken by the next keystroke, and used to flash
        // "couldn't connect" until the newer search landed.
        guard !Task.isCancelled else { return }
        isSearching = false

        switch outcome {
        case .success(let songs):
            results = songs
            searchError = nil
        case .failure(let error):
            results = []
            searchError = error.localizedDescription
        }
    }

    private struct SearchKey: Equatable {
        let term: String
        let scope: SearchScope
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

private struct SearchMessage: View {
    enum Kind {
        /// Catalog only; the library is browsed instead.
        case prompt
        case noResults(String)
        case failed(String)
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .prompt:
            ContentUnavailableView(
                "Search Apple Music",
                systemImage: "magnifyingglass",
                description: Text("Or switch to My Library to browse what you already own.")
            )
        case .noResults(let term):
            ContentUnavailableView(
                "No results for \u{201C}\(term)\u{201D}",
                systemImage: "magnifyingglass",
                description: Text("Check the spelling, or try the other source.")
            )
        case .failed(let reason):
            ContentUnavailableView(
                "Search couldn't finish",
                systemImage: "exclamationmark.triangle",
                description: Text(reason)
            )
        }
    }
}

// MARK: - Previews

#Preview("Browsing") {
    SongPickerView { _ in }
        .modelContainer(try! AppSchema.inMemoryContainer())
}

#if os(macOS)
#Preview("Add to Saved, Mac") {
    SongPickerView(title: "Add Song to Saved", confirmTitle: "Add") { _ in }
        .modelContainer(try! AppSchema.inMemoryContainer())
}
#endif

#Preview("Nothing typed") {
    SearchMessage(kind: .prompt)
}

#Preview("No results") {
    SearchMessage(kind: .noResults("blakbird"))
}

#Preview("Search failed") {
    SearchMessage(kind: .failed("The Internet connection appears to be offline."))
}
