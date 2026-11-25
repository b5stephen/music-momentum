//
//  SavedSidebarView.swift
//  MusicMomentum
//

#if os(macOS)
import MusicKit
import SwiftData
import SwiftUI

/// Saved as the Mac window's source list: a header carrying Sort and Add,
/// then the songs, with the search field as the list's first row, so it
/// scrolls away with them. It sits translucent over the artwork mesh,
/// so it draws no background of its own.
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
    @AppStorage("savedSongOrder") private var order: SongOrder = .title
    @State private var searchTerm = ""
    @State private var loadingID: String?
    @State private var lookupError: String?

    @Environment(\.scenePhase) private var scenePhase
    /// Settled at the moments SavedSongsView settles it, and as the search
    /// changes, so a search that leaves a few songs lists them flat.
    @State private var settledCount: Int?

    private var songs: [SavedSong] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return recentlyChanged }
        return recentlyChanged.filter {
            $0.title.localizedStandardContains(term) || $0.artistName.localizedStandardContains(term)
        }
    }

    private var isGrouped: Bool { SongSection.groups(songCount: settledCount ?? songs.count) }

    private var sections: [SongSection] {
        isGrouped
            ? order.sections(songs)
            : [SongSection(id: "all", title: "", indexLabel: nil, songs: order.sorted(songs))]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.leading, 20)
                .padding(.trailing, 10)
                .padding(.top, 6)
                .padding(.bottom, 6)

            if recentlyChanged.isEmpty {
                emptyText("No saved songs yet")
            } else {
                List {
                    searchField
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 6, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if songs.isEmpty {
                        emptyText("No matches")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.songs) { song in
                                row(song)
                            }
                        } header: {
                            if isGrouped {
                                Text(section.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .animation(.snappy, value: order)
                .animation(.snappy, value: isGrouped)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear(perform: settleGrouping)
        .onChange(of: order) { settleGrouping() }
        .onChange(of: searchTerm) { settleGrouping() }
        .onChange(of: scenePhase) { if scenePhase == .active { settleGrouping() } }
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

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
    }

    /// Concrete AppKit colours rather than `.secondary` and `.primary`: in a
    /// list row those resolve against the row and came out a different grey
    /// from the field's when it sat above the list.
    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            TextField(
                "Search",
                text: $searchTerm,
                prompt: Text("Search").foregroundStyle(Color(nsColor: .placeholderTextColor))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .labelColor))
            .accessibilityLabel("Search saved songs")
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color(nsColor: .labelColor).opacity(0.08), in: .capsule)
        .overlay { Capsule().strokeBorder(Color(nsColor: .labelColor).opacity(0.07), lineWidth: 1) }
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

    private func settleGrouping() {
        settledCount = songs.count
    }

    private func row(_ song: SavedSong) -> some View {
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

    private func isLoaded(_ song: SavedSong) -> Bool {
        if let selected = controller.selectedSong { return song.matches(selected) }
        return previewCurrentID == song.songID
    }

    private func practice(_ song: SavedSong) {
        loadingID = song.songID
        Task {
            // A newer pick's row owns the spinner by now.
            defer { if loadingID == song.songID { loadingID = nil } }
            guard await controller.requestAuthorizationIfNeeded() else {
                lookupError = "Allow Apple Music access in System Settings to practice this song."
                return
            }
            do {
                _ = try await controller.select(saved: song)
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
