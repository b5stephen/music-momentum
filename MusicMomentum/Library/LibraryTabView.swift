//
//  LibraryTabView.swift
//  MusicMomentum
//

#if os(iOS)
import MusicKit
import SwiftData
import SwiftUI

/// The Library tab: the picker's browse and search as a screen of its own,
/// which keeps its place while the user goes back and forth to Practice. A
/// tap loads a song and switches to Practice without playing it; a row's +
/// keeps it in Saved without leaving.
struct LibraryTabView: View {
    let controller: PlaybackController
    let onPractise: () -> Void

    @State private var searchTerm = ""
    @State private var isAuthorized = true

    var body: some View {
        NavigationStack {
            Group {
                if !isAuthorized {
                    ContentUnavailableView {
                        Label("Apple Music access is off", systemImage: "music.note")
                    } description: {
                        Text("Allow MusicMomentum to use Apple Music in Settings to browse your library.")
                    }
                } else if searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LibraryBrowseView { practise($0) }
                } else {
                    SongSearchResults(term: searchTerm) { practise($0) }
                }
            }
            .navigationTitle("Library")
        }
        .searchable(text: $searchTerm, prompt: SongPickerView.searchPrompt)
        .environment(\.saveTarget, .saved)
        .environment(\.pickActionTitle, "Practise")
        .showsSaveFeedback()
        .task { isAuthorized = await controller.requestAuthorizationIfNeeded() }
    }

    private func practise(_ song: Song) {
        Task { await controller.select(song: song) }
        onPractise()
    }
}

#Preview("Library tab") {
    LibraryTabView(controller: PlaybackController()) {}
        .modelContainer(try! AppSchema.inMemoryContainer())
}
#endif
