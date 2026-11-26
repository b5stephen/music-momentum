//
//  LibraryBrowseView.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI

/// The library before anything is typed: what Music is playing (iOS), what
/// was played lately, the shelves to drill into, and the saved songs being
/// practised. The picker and the Library tab both start here.
struct LibraryBrowseView: View {
    let onSelect: (Song) -> Void

    /// Songs never played still fill the shelf, most recently changed first.
    @Query(sort: [
        SortDescriptor(\SavedSong.practicedAt, order: .reverse),
        SortDescriptor(\SavedSong.lastPracticed, order: .reverse),
    ])
    private var saved: [SavedSong]

    /// `nil` while loading. The section is there from the start either way:
    /// a section inserted above the others once the request landed is the
    /// kind of change that crashed the Mac's AppKit-backed list.
    @State private var recentlyPlayed: [Song]?

    private static let recentLimit = 3
    private static let shelfLimit = 12

    var body: some View {
        List {
            #if os(iOS)
            PlayingInMusicSection(onSelect: onSelect)
            #endif

            Section {
                Group {
                    if let recentlyPlayed, recentlyPlayed.isEmpty {
                        Text("Songs you play in Music show up here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                    } else {
                        RecentlyPlayedShelf(songs: recentlyPlayed, onSelect: onSelect)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } header: {
                    NavigationLink {
                        LibraryPageView(page: .recentlyPlayed, onSelect: onSelect)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Recently Played")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
            }

            Section("Browse Your Library") {
                ForEach([LibraryPage.artists, .albums, .playlists, .songs]) { page in
                    NavigationLink {
                        LibraryPageView(page: page, onSelect: onSelect)
                    } label: {
                        ShelfRow(title: page.title, systemImage: page.systemImage)
                    }
                }
            }

            if !saved.isEmpty {
                Section("Practising Lately") {
                    ForEach(saved.prefix(Self.recentLimit)) { song in
                        SavedPickRow(song: song, onSelect: onSelect)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .task { await loadRecentlyPlayed() }
    }

    /// Failing quietly, as an empty shelf: it's a shortcut, and the shelves
    /// below still reach everything.
    private func loadRecentlyPlayed() async {
        guard recentlyPlayed == nil else { return }
        var request = MusicRecentlyPlayedRequest<Song>()
        request.limit = Self.shelfLimit
        let songs = (try? await request.response().items).map(Array.init) ?? []
        // Cards fade in over their placeholders; the one-line empty state
        // swaps in at once, as a cross-fade from the taller cards smeared.
        if songs.isEmpty {
            recentlyPlayed = songs
        } else {
            withAnimation(.snappy) { recentlyPlayed = songs }
        }
    }
}

// MARK: - Recently played

/// Covers across, as Music's own shelves are; the full list is a tap on the
/// heading away.
private struct RecentlyPlayedShelf: View {
    /// `nil` while loading, which draws blank cards of the same size.
    let songs: [Song]?
    let onSelect: (Song) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                if let songs {
                    ForEach(songs) { song in
                        RecentlyPlayedCard(song: song, onSelect: onSelect)
                    }
                } else {
                    ForEach(0..<6, id: \.self) { _ in
                        RecentlyPlayedCard.placeholder
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Self.inset)
            .padding(.vertical, 6)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    #if os(macOS)
    private static let inset: CGFloat = 10
    #else
    private static let inset: CGFloat = 20
    #endif
}

private struct RecentlyPlayedCard: View {
    let song: Song
    let onSelect: (Song) -> Void

    @Environment(\.pickedSong) private var picked
    @Environment(\.saveTarget) private var target
    @Environment(\.saveFeedback) private var feedback
    @Environment(\.modelContext) private var modelContext
    @Environment(\.pickActionTitle) private var actionTitle

    var body: some View {
        card
            .contextMenu {
                Button(actionTitle) { onSelect(song) }
                if let target {
                    Button("Add to \(target.name)") {
                        target.add(song, in: modelContext)
                        feedback?.show("Added \u{201C}\(song.title)\u{201D} to \(target.name)")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var card: some View {
        #if os(macOS)
        label
            .contentShape(.rect)
            .onTapGesture(count: 2) { onSelect(song) }
            .simultaneousGesture(TapGesture().onEnded { picked?.song = song; picked?.savedID = nil })
        #else
        Button { onSelect(song) } label: { label }
            .buttonStyle(.plain)
        #endif
    }

    private var isPicked: Bool { picked?.song?.id == song.id }

    private var label: some View {
        VStack(alignment: .leading, spacing: 5) {
            Group {
                if let artwork = song.artwork {
                    ArtworkImage(artwork, width: Self.side, height: Self.side)
                } else {
                    Rectangle().fill(.quaternary)
                        .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                }
            }
            .frame(width: Self.side, height: Self.side)
            // What shows until the cover arrives.
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                if isPicked {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.6), lineWidth: 2)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: Self.side, alignment: .leading)
        }
    }

    static var placeholder: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: side, height: side)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(.quaternary).frame(width: side * 0.8, height: 9)
                Capsule().fill(.quaternary).frame(width: side * 0.5, height: 9).opacity(0.6)
            }
            .padding(.top, 3)
        }
        .accessibilityHidden(true)
    }

    #if os(macOS)
    private static let side: CGFloat = 96
    #else
    private static let side: CGFloat = 112
    #endif
}

// MARK: - Shelf rows

private struct ShelfRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(.quaternary)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                }
            Text(title)
            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Browse root") {
    let container = try! AppSchema.inMemoryContainer()
    SavedSong.save(
        songID: "1", title: "Little Wing", artistName: "Jimi Hendrix",
        artworkData: nil, speed: 0.6, in: ModelContext(container)
    )
    return NavigationStack {
        LibraryBrowseView { _ in }
            .navigationTitle("Choose Song")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
    .environment(\.saveTarget, .saved)
    .modelContainer(container)
}
