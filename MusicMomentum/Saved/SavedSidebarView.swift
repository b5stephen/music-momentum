//
//  SavedSidebarView.swift
//  MusicMomentum
//

#if os(macOS)
import MusicKit
import SwiftData
import SwiftUI

/// Saved as the Mac window's source list: a search field, a header carrying
/// Sort and Add, and a row per song. It sits translucent over the artwork
/// mesh, so it draws no background of its own.
struct SavedSidebarView: View {
    let controller: PlaybackController
    /// Stands in for `controller.selectedSong` in previews, since `Song` has
    /// no public initialiser.
    var previewCurrentID: String?
    /// Opens the picker that adds a song without loading it.
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSong.lastPracticed, order: .reverse)
    private var recentlyChanged: [SavedSong]
    @AppStorage("savedSongOrder") private var order: SongOrder = .changed
    @State private var searchTerm = ""
    @State private var loadingID: String?
    @State private var lookupError: String?

    private var songs: [SavedSong] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = order.sorted(recentlyChanged)
        guard !term.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedStandardContains(term) || $0.artistName.localizedStandardContains(term)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 14)

            header
                .padding(.leading, 20)
                .padding(.trailing, 10)
                .padding(.bottom, 6)

            if songs.isEmpty {
                Text(recentlyChanged.isEmpty ? "No saved songs yet" : "No matches")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 24)
            } else {
                List(songs) { song in
                    SavedSidebarRow(
                        song: song,
                        isLoading: loadingID == song.songID,
                        isLoaded: isLoaded(song),
                        isPlaying: controller.isPlaying
                    ) { practice(song) }
                    .contextMenu {
                        Button("Delete", role: .destructive) { controller.delete(song, in: modelContext) }
                    }
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .alert(
            "Couldn't open that song",
            isPresented: .init(
                get: { lookupError != nil },
                set: { if !$0 { lookupError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lookupError ?? "")
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchTerm)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .accessibilityLabel("Search saved songs")
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.primary.opacity(0.08), in: .capsule)
        .overlay { Capsule().strokeBorder(.primary.opacity(0.07), lineWidth: 1) }
    }

    private var header: some View {
        HStack(spacing: 2) {
            Text("Saved")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)

            Menu {
                Picker("Sort By", selection: $order) {
                    ForEach(SongOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Sort by: \(order.title)")
            .accessibilityLabel("Sort")

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(!controller.canUseMusic)
            .help("Add a song to Saved without opening it (\u{21E7}\u{2318}N)")
            .accessibilityLabel("Add Song")
        }
    }

    private func isLoaded(_ song: SavedSong) -> Bool {
        if let selected = controller.selectedSong { return song.matches(selected) }
        return previewCurrentID == song.songID
    }

    private func practice(_ song: SavedSong) {
        loadingID = song.songID
        Task {
            defer { loadingID = nil }
            guard await controller.requestAuthorizationIfNeeded() else {
                lookupError = "Allow Apple Music access in System Settings to practice this song."
                return
            }
            do {
                try await controller.select(saved: song)
            } catch {
                lookupError = error is SongGoneError
                    ? error.localizedDescription
                    : "Couldn't find that song: \(error.localizedDescription)"
            }
        }
    }
}

/// The loaded song carries a speaker, not a highlight: a panel behind it was
/// tried and dropped on iOS.
private struct SavedSidebarRow: View {
    let song: SavedSong
    let isLoading: Bool
    let isLoaded: Bool
    let isPlaying: Bool
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                SavedSongArtwork(song: song, side: 36, isLoading: isLoading)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(song.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        if isLoaded {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                                .opacity(0.85)
                                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                                .accessibilityLabel("In practice")
                        }
                    }
                    Text(song.artistName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text("\(song.percent)%")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.primary.opacity(isHovered ? 0.08 : 0), in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Open \(song.title)")
    }
}

// MARK: - Previews

#Preview("Saved sidebar", traits: .fixedLayout(width: 272, height: 520)) {
    SavedSidebarView(controller: PlaybackController(), previewCurrentID: "2") {}
        .modelContainer(previewContainer())
}

#Preview("Empty sidebar", traits: .fixedLayout(width: 272, height: 320)) {
    SavedSidebarView(controller: PlaybackController()) {}
        .modelContainer(try! AppSchema.inMemoryContainer())
}

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    SavedSong.save(songID: "1", title: "Harbour Lights", artistName: "Mara Ellis", artworkData: nil, speed: 0.75, in: context)
    SavedSong.save(songID: "2", title: "Slow Burn Avenue", artistName: "The Kettle Lines", artworkData: nil, speed: 0.6, in: context)
    SavedSong.save(songID: "3", title: "Paper Moons", artistName: "June Okafor", artworkData: nil, speed: 0.8, in: context)
    SavedSong.save(songID: "4", title: "Night Ferry", artistName: "Low Tide Club", artworkData: nil, speed: 0.7, in: context)
    return container
}
#endif
