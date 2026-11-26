//
//  MacLibraryView.swift
//  MusicMomentum
//

#if os(macOS)
import MusicKit
import SwiftUI

/// The library in the Mac window's main area, in place of Practice, over the
/// same cover mesh. A page at a time from the sidebar, or the results of the
/// window's toolbar search over Saved, the library and Apple Music.
///
/// A click picks a row and a double-click practises it, as in the picker;
/// Return stays with Practice's own Rename Marker.
struct MacLibraryView: View {
    let page: LibraryPage
    let target: SaveTarget
    /// Owned by the window: a `.searchable` this deep, inside the split
    /// view's detail and this stack, never reached the window's toolbar.
    @Binding var searchTerm: String
    let onSelect: (Song) -> Void

    @State private var picked = PickedSong()

    private var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    SongSearchResults(term: searchTerm, onSelect: onSelect)
                        .navigationTitle("Search")
                } else {
                    LibraryPageView(page: page, onSelect: onSelect)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A sidebar pick starts that page afresh rather than inside the last
        // page's album.
        .id(page)
        .onChange(of: searchTerm) { picked.clear() }
        .onChange(of: page) { searchTerm = "" }
        .environment(\.pickedSong, picked)
        .environment(\.saveTarget, target)
        .environment(\.pickActionTitle, "Practice")
        .showsSaveFeedback()
    }
}
#endif
