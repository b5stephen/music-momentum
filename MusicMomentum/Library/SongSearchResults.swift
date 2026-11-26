//
//  SongSearchResults.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI

/// One search over everything, in the order a song is likeliest to be
/// wanted: Saved, then the library, then Apple Music. A source switch used
/// to choose between the last two, and a song searched for in the wrong one
/// simply wasn't there. A song is listed once, under the first section it's
/// in, so a saved song shows its markers and speed rather than a bare twin.
struct SongSearchResults: View {
    let term: String
    let onSelect: (Song) -> Void

    @Query(sort: \SavedSong.title) private var saved: [SavedSong]
    @State private var library: Outcome = .idle
    @State private var catalog: Outcome = .idle
    @State private var showsAllCatalog = false

    private static let catalogPreview = 5

    private enum Outcome {
        case idle, loading
        case loaded([Song])
        case failed(String)

        var songs: [Song] {
            if case .loaded(let songs) = self { songs } else { [] }
        }

        var isLoading: Bool {
            if case .loading = self { true } else { false }
        }
    }

    private var trimmed: String { term.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var savedMatches: [SavedSong] {
        saved.filter {
            $0.title.localizedStandardContains(trimmed) || $0.artistName.localizedStandardContains(trimmed)
        }
    }

    private var libraryMatches: [Song] {
        let savedSongs = savedMatches
        return library.songs.filter { song in !savedSongs.contains { $0.matches(song) } }
    }

    /// A library song carries its catalog ID, so the same recording found in
    /// both is listed under the library.
    private var catalogMatches: [Song] {
        let savedSongs = savedMatches
        let libraryCatalogIDs = Set(library.songs.compactMap(\.catalogID))
        return catalog.songs.filter { song in
            !savedSongs.contains { $0.matches(song) } && !libraryCatalogIDs.contains(song.id.rawValue)
        }
    }

    private var hasNothing: Bool {
        savedMatches.isEmpty && libraryMatches.isEmpty && catalogMatches.isEmpty
            && !library.isLoading && !catalog.isLoading
    }

    var body: some View {
        Group {
            if hasNothing, case .failed(let reason) = catalog, case .failed = library {
                SearchMessage(kind: .failed(reason))
            } else if hasNothing, !isIdle {
                SearchMessage(kind: .noResults(trimmed))
            } else {
                results
            }
        }
        .task(id: trimmed) { await search() }
    }

    private var isIdle: Bool {
        if case .idle = library { return true }
        return false
    }

    /// A `List` on iOS. On the Mac, sections appearing and filling as the
    /// two searches land crashed SwiftUI's AppKit-backed list mid-diff
    /// (`TableViewListCore_Mac2`), so the Mac lays the rows out itself.
    @ViewBuilder
    private var results: some View {
        #if os(macOS)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                sections
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        #else
        List { sections }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        #endif
    }

    @ViewBuilder
    private var sections: some View {
        if !savedMatches.isEmpty {
            Section {
                ForEach(savedMatches) { song in
                    SavedPickRow(song: song, showsMarkers: true, onSelect: onSelect)
                }
            } header: {
                SectionTitle("Saved")
            }
        }

        section("Your Library", outcome: library, songs: libraryMatches)

        section(
            "Apple Music",
            outcome: catalog,
            songs: showsAllCatalog ? catalogMatches : Array(catalogMatches.prefix(Self.catalogPreview))
        )
        if !showsAllCatalog, catalogMatches.count > Self.catalogPreview {
            Button("Show More from Apple Music") {
                withAnimation(.snappy) { showsAllCatalog = true }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .padding(.vertical, 6)
            .padding(.leading, Self.messageInset)
            .listRowSeparator(.hidden)
        }
    }

    #if os(macOS)
    private static let messageInset: CGFloat = 6
    #else
    private static let messageInset: CGFloat = 0
    #endif

    @ViewBuilder
    private func section(_ title: String, outcome: Outcome, songs: [Song]) -> some View {
        switch outcome {
        case .idle:
            EmptyView()
        case .loading:
            Section {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Searching\u{2026}").foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.leading, Self.messageInset)
                .listRowSeparator(.hidden)
            } header: {
                SectionTitle(title)
            }
        case .failed(let reason):
            Section {
                Label("Couldn't search: \(reason)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.leading, Self.messageInset)
                    .listRowSeparator(.hidden)
            } header: {
                SectionTitle(title)
            }
        case .loaded:
            if !songs.isEmpty {
                Section {
                    ForEach(songs) { song in
                        SongPickerRow(song: song, onSelect: onSelect) {
                            // The album is what tells recordings of one song apart.
                            SongRow(song: song, showsAlbum: true)
                        }
                    }
                } header: {
                    SectionTitle(title)
                }
            }
        }
    }

    private func search() async {
        let term = trimmed
        showsAllCatalog = false
        guard !term.isEmpty else {
            library = .idle
            catalog = .idle
            return
        }

        // Shown through the pause too, so a typed term never sits over an
        // empty list.
        library = .loading
        catalog = .loading
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        async let libraryOutcome = Self.outcome {
            var request = MusicLibrarySearchRequest(term: term, types: [Song.self])
            request.limit = 25
            return Array(try await request.response().songs)
        }
        async let catalogOutcome = Self.outcome {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 25
            return Array(try await request.response().songs)
        }
        let (libraryResult, catalogResult) = await (libraryOutcome, catalogOutcome)

        // MusicKit reports a request cancelled mid-flight as a connection
        // error, not `CancellationError`. The first catalog search is slow
        // enough to be overtaken by the next keystroke, and used to flash
        // "couldn't connect" until the newer search landed.
        guard !Task.isCancelled else { return }
        withAnimation(.snappy) {
            library = libraryResult
            catalog = catalogResult
        }
    }

    private static func outcome(_ run: () async throws -> [Song]) async -> Outcome {
        do {
            return .loaded(try await run())
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

/// A plain list's section header on iOS; on the Mac, where there's no list,
/// the sidebar's small headings.
private struct SectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        #if os(macOS)
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
        #else
        Text(title)
        #endif
    }
}

private struct SearchMessage: View {
    enum Kind {
        case noResults(String)
        case failed(String)
    }

    let kind: Kind

    var body: some View {
        switch kind {
        case .noResults(let term):
            ContentUnavailableView(
                "No results for \u{201C}\(term)\u{201D}",
                systemImage: "magnifyingglass",
                description: Text("Nothing in Saved, your library or Apple Music matches. Check the spelling.")
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

@MainActor
private func searchPreview(inList: Bool) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    SavedSong.save(songID: "1", title: "Dreams", artistName: "Fleetwood Mac", artworkData: nil, speed: 0.8, in: context)
    let list = PracticeList.create(name: "Acoustic", in: context)
    return SongSearchResults(term: "dreams") { _ in }
        .environment(\.saveTarget, inList ? .list(list) : .saved)
        .showsSaveFeedback()
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
        .modelContainer(container)
}

#Preview("Searching Saved, library and Apple Music") {
    searchPreview(inList: false)
}

#Preview("Searching to add to a list") {
    searchPreview(inList: true)
}

#Preview("No results") {
    SearchMessage(kind: .noResults("blakbird"))
}

#Preview("Search failed") {
    SearchMessage(kind: .failed("The Internet connection appears to be offline."))
}
