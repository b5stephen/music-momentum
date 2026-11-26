//
//  LibraryPageView.swift
//  MusicMomentum
//
//  `MusicLibrarySearchRequest` needs a term; `MusicLibraryRequest` returns the
//  library itself, so the user can drill artist → album → song without typing.
//

import MusicKit
import SwiftUI

/// The shelves of the user's library a picker, the Library tab and the Mac
/// window's sidebar all open.
enum LibraryPage: String, CaseIterable, Identifiable, Hashable {
    case recentlyPlayed, artists, albums, songs, playlists

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyPlayed: "Recently Played"
        case .artists: "Artists"
        case .albums: "Albums"
        case .songs: "Songs"
        case .playlists: "Playlists"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyPlayed: "clock.arrow.circlepath"
        case .artists: "music.microphone"
        case .albums: "square.stack"
        case .songs: "music.note"
        case .playlists: "music.note.list"
        }
    }
}

/// One shelf, with its own drill-down: an artist's albums, an album's or a
/// playlist's tracks.
struct LibraryPageView: View {
    let page: LibraryPage
    let onSelect: (Song) -> Void

    var body: some View {
        switch page {
        case .recentlyPlayed: recentlyPlayedList
        case .artists: artistsList
        case .albums: albumsList
        case .songs: songsList
        case .playlists: playlistsList
        }
    }

    /// Practice in this app leaves no listening history
    /// (`affectsListeningHistory`), so this is what was played in Music.
    private var recentlyPlayedList: some View {
        PagedLibraryList(
            title: "Recently Played",
            shelf: "recently played songs",
            emptyTitle: "Nothing played lately",
            emptyMessage: "Songs you play in Music on this Apple ID show up here.",
            // Its collection claims a next batch, but asking for it is a
            // fatal error inside MusicKit ("non decodable music item type"),
            // so it's one request of the most it allows.
            pages: false
        ) {
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = 30
            return try await request.response().items
        } row: { song in
            SongPickerRow(song: song, onSelect: onSelect) {
                SongRow(song: song, showsAlbum: true)
            }
        }
    }

    private var artistsList: some View {
        PagedLibraryList(
            title: "Artists",
            shelf: "artists",
            emptyTitle: "No artists yet",
            emptyMessage: "Artists you add to your library on this Apple ID show up here."
        ) {
            var request = MusicLibraryRequest<Artist>()
            request.sort(by: \.name, ascending: true)
            return try await request.response().items
        } row: { artist in
            NavigationLink {
                albumsList(by: artist)
            } label: {
                ArtistRow(artist: artist)
            }
        }
    }

    private func albumsList(by artist: Artist) -> some View {
        PagedLibraryList(
            title: artist.name,
            shelf: "albums",
            emptyTitle: "No albums yet",
            emptyMessage: "Nothing by this artist is in your library on this Apple ID."
        ) {
            var request = MusicLibraryRequest<Album>()
            request.filter(matching: \.artists, contains: artist)
            request.sort(by: \.title, ascending: true)
            return try await request.response().items
        } row: { album in
            NavigationLink {
                trackList(of: album)
            } label: {
                AlbumRow(album: album)
            }
        }
    }

    private var albumsList: some View {
        PagedLibraryList(
            title: "Albums",
            shelf: "albums",
            emptyTitle: "No albums yet",
            emptyMessage: "Albums you add to your library on this Apple ID show up here."
        ) {
            var request = MusicLibraryRequest<Album>()
            request.sort(by: \.title, ascending: true)
            return try await request.response().items
        } row: { album in
            NavigationLink {
                trackList(of: album)
            } label: {
                AlbumRow(album: album)
            }
        }
    }

    private var playlistsList: some View {
        PagedLibraryList(
            title: "Playlists",
            shelf: "playlists",
            emptyTitle: "No playlists yet",
            emptyMessage: "Playlists you make or follow on this Apple ID show up here."
        ) {
            var request = MusicLibraryRequest<Playlist>()
            request.sort(by: \.name, ascending: true)
            return try await request.response().items
        } row: { playlist in
            NavigationLink {
                trackList(of: playlist)
            } label: {
                PlaylistRow(playlist: playlist)
            }
        }
    }

    private var songsList: some View {
        PagedLibraryList(
            title: "Songs",
            shelf: "songs",
            emptyTitle: "No songs yet",
            emptyMessage: "Songs you add to your library on this Apple ID show up here."
        ) {
            var request = MusicLibraryRequest<Song>()
            request.sort(by: \.title, ascending: true)
            return try await request.response().items
        } row: { song in
            SongPickerRow(song: song, onSelect: onSelect) {
                SongRow(song: song, showsAlbum: true)
            }
        }
    }

    private func trackList(of album: Album) -> some View {
        trackList(title: album.title) {
            try await album.with([.tracks], preferredSource: .library).tracks ?? []
        }
    }

    private func trackList(of playlist: Playlist) -> some View {
        trackList(title: playlist.name) {
            try await playlist.with([.tracks], preferredSource: .library).tracks ?? []
        }
    }

    private func trackList(
        title: String,
        load: @escaping () async throws -> MusicItemCollection<Track>
    ) -> some View {
        PagedLibraryList(
            title: title,
            shelf: "tracks",
            emptyTitle: "No tracks here",
            emptyMessage: "This one has nothing in it to play.",
            load: load
        ) { track in
            // Music videos are greyed out rather than hidden so track numbers
            // don't appear to skip.
            if case .song(let song) = track {
                SongPickerRow(song: song, onSelect: onSelect) {
                    TrackRow(track: track)
                }
            } else {
                Button {} label: {
                    TrackRow(track: track)
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
        }
    }
}

// MARK: - Paging

/// Loads a `MusicItemCollection` a batch at a time, and owns the loading,
/// empty and failure states.
private struct PagedLibraryList<Item: MusicItem & Identifiable, Row: View>: View {
    let title: String
    /// Plural, lower case: "Couldn't load your albums".
    let shelf: String
    let emptyTitle: String
    let emptyMessage: String
    var pages = true
    let load: () async throws -> MusicItemCollection<Item>
    @ViewBuilder let row: (Item) -> Row

    /// `nil` until the first batch lands, as distinct from empty.
    @State private var items: MusicItemCollection<Item>?
    @State private var errorMessage: String?
    @State private var isLoadingMore = false

    var body: some View {
        #if os(macOS)
        // The Mac's toolbar title is small and a sheet shows none, so the
        // page names itself, as Music's pages do.
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)
            content
        }
        .navigationTitle(title)
        .task { await loadFirstBatch() }
        #else
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadFirstBatch() }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load your \(shelf)", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") {
                        self.errorMessage = nil
                        Task { await loadFirstBatch() }
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            } else if let items {
                if items.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "music.note",
                        description: Text(emptyMessage)
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            row(item)
                                #if os(macOS)
                                // Hover is the row's edge, as in the sidebar.
                                .listRowSeparator(.hidden)
                                #endif
                        }
                        if pages, items.hasNextBatch {
                            // Rows are built lazily, so this only fetches once
                            // the user scrolls to it.
                            VStack(spacing: 12) {
                                SkeletonRow().opacity(0.5)
                                SkeletonRow().opacity(0.25)
                            }
                            .listRowSeparator(.hidden)
                            .task(id: items.count) { await loadMore() }
                        }
                    }
                    .listStyle(.plain)
                    // Over the Mac window's cover mesh as well as in a sheet.
                    .scrollContentBackground(.hidden)
                }
            } else {
                List(0..<5, id: \.self) { index in
                    SkeletonRow()
                        .opacity(1 - Double(index) * 0.18)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .allowsHitTesting(false)
                .accessibilityLabel("Loading \(shelf)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadFirstBatch() async {
        guard items == nil else { return }
        do {
            items = try await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard pages, let current = items, current.hasNextBatch, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            if let next = try await current.nextBatch() {
                items? += next
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Same metrics as the real rows, so nothing moves when content arrives.
private struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 7) {
                bar(span: 6)
                bar(span: 4)
                    .opacity(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func bar(span: Int) -> some View {
        Capsule()
            .fill(.quaternary)
            .frame(height: 11)
            .containerRelativeFrame(.horizontal, count: 10, span: span, spacing: 0)
    }
}

// MARK: - Rows

private struct ArtistRow: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            LibraryArtwork(artwork: artist.artwork, fallback: "music.microphone")
            Text(artist.name).lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct AlbumRow: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            LibraryArtwork(artwork: album.artwork, fallback: "square.stack")
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title).lineLimit(1)
                Text(album.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            LibraryArtwork(artwork: playlist.artwork, fallback: "music.note.list")
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name).lineLimit(1)
                if let curator = playlist.curatorName, !curator.isEmpty {
                    Text(curator)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            LibraryArtwork(artwork: track.artwork, fallback: "music.note")
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).lineLimit(1)
                Text(track.isSong ? track.artistName : "Music video")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct LibraryArtwork: View {
    let artwork: Artwork?
    let fallback: String

    var body: some View {
        if let artwork {
            ArtworkImage(artwork, width: 48, height: 48)
                // What shows until the cover arrives.
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 48, height: 48)
                .overlay { Image(systemName: fallback).foregroundStyle(.secondary) }
        }
    }
}

private extension Track {
    var isSong: Bool {
        if case .song = self { return true }
        return false
    }
}

// MARK: - Previews

private func albumsPreview(
    load: @escaping () async throws -> MusicItemCollection<Album>
) -> some View {
    NavigationStack {
        PagedLibraryList(
            title: "Albums",
            shelf: "albums",
            emptyTitle: "No albums yet",
            emptyMessage: "Albums you add to your library on this Apple ID show up here.",
            load: load
        ) { album in
            AlbumRow(album: album)
        }
    }
}

#Preview("Loading") {
    albumsPreview {
        try await Task.sleep(for: .seconds(600))
        return []
    }
}

#Preview("Empty") {
    albumsPreview { [] }
}

#Preview("Failed") {
    albumsPreview { throw URLError(.notConnectedToInternet) }
}
