//
//  SavedSongsView.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI

struct SavedSongsView: View {
    let controller: PlaybackController
    /// Beside the floating practice card, which already names the screen's
    /// job and offers the way to pick a song.
    var isBesidePractice = false
    /// Brings the practice tab forward.
    let onPractice: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSong.lastPracticed, order: .reverse)
    private var recentlyChanged: [SavedSong]
    /// Per device rather than synced: it's how this screen is read, not data.
    @AppStorage("savedSongOrder") private var order: SongOrder = .changed

    private var songs: [SavedSong] { order.sorted(recentlyChanged) }
    /// Beside the card, the rows end as far from the window edge as the card
    /// sits from every edge, so the page reads as one set of margins.
    private var trailingInset: CGFloat { isBesidePractice ? 28 : 16 }

    @State private var showPicker = false
    @State private var editing: SavedSong?
    @State private var loadingID: String?
    @State private var lookupError: String?
    @State private var marking: Marking?

    private struct Marking: Identifiable {
        let song: SavedSong
        /// `nil` when adding one.
        let marker: SongMarker?
        let start: TimeInterval

        /// Carries the marker's identity so opening one marker straight after
        /// another rebuilds the sheet.
        var id: String {
            marker.map { "edit-\($0.persistentModelID.hashValue)" }
                ?? "new-\(song.persistentModelID.hashValue)"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty, isBesidePractice {
                    ContentUnavailableView("No saved songs yet", systemImage: "bookmark")
                } else if songs.isEmpty {
                    ContentUnavailableView {
                        Label("No saved songs yet", systemImage: "bookmark")
                    } description: {
                        Text("Save a song to practice it again at the speed you left it.")
                    } actions: {
                        Button {
                            chooseSong()
                        } label: {
                            Label("Add Song", systemImage: "music.note.list")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.accentText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                        }
                        // Not `.bordered`, which turns grey once its text is recoloured.
                        .buttonStyle(.plain)
                        .disabled(!controller.canUseMusic)
                    }
                } else {
                    // One flat list, not a section per song: section gaps split
                    // a song from its own pills. The separator is drawn by hand
                    // below for the same reason.
                    List {
                        ForEach(songs) { song in
                            let markers = song.sortedMarkers
                            SavedSongRow(
                                song: song,
                                isLoading: loadingID == song.songID,
                                isCurrent: controller.selectedSong?.id.rawValue == song.songID,
                                isPlaying: controller.isPlaying,
                                onPlay: { practice(song) },
                                onEditSpeed: { editing = song },
                                onAddMarker: { openEditor(song) }
                            )
                            .listRowInsets(EdgeInsets(
                                top: 10, leading: 16, bottom: markers.isEmpty ? 10 : 0, trailing: trailingInset
                            ))
                            .listRowSeparator(.hidden)
                            .overlay(alignment: .bottom) {
                                if markers.isEmpty { separator }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(song) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                            if !markers.isEmpty {
                                MarkerPills(
                                    markers: markers,
                                    inset: trailingInset,
                                    leadingInset: SavedSongRow.titleInset,
                                    // A tap edits here; loading the song is the row
                                    // above's job, and still a long press away.
                                    onTap: { openEditor(song, marker: $0) },
                                    jumpTitle: "Practice From Here",
                                    onJump: { practice(song, jumpingTo: $0) },
                                    onDelete: { delete($0) }
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) { separator }
                            }
                        }
                    }
                    .listStyle(.plain)
                    // Otherwise the pill row is stretched to 44pt and the rows
                    // drift apart.
                    .environment(\.defaultMinListRowHeight, 0)
                }
            }
            .navigationTitle(isBesidePractice ? "" : "Saved")
            .navigationBarTitleDisplayMode(isBesidePractice ? .inline : .automatic)
            .toolbar {
                // Hidden rather than disabled: a greyed glyph beside Add read
                // as a second, broken add button.
                if !songs.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Picker("Sort By", selection: $order) {
                                ForEach(SongOrder.allCases) { order in
                                    Text(order.title).tag(order)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        chooseSong()
                    } label: {
                        Label("Add Song", systemImage: "plus")
                    }
                    .disabled(!controller.canUseMusic)
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    DebugMenu()
                }
                #endif
            }
            .sheet(isPresented: $showPicker) {
                SongPickerView(onSelect: add)
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
            .sheet(item: $marking) { marking in
                if let duration = controller.duration {
                    if let marker = marking.marker {
                        MarkerEditorView(
                            marker: marker,
                            duration: duration,
                            controller: controller,
                            onSave: { name, start, end in
                                update(marker, name: name, start: start, end: end)
                            },
                            onDelete: { delete(marker) }
                        )
                    } else {
                        MarkerEditorView(
                            initialStart: marking.start,
                            duration: duration,
                            controller: controller
                        ) { name, start, end in
                            SongMarker.add(
                                to: marking.song,
                                name: name,
                                startTime: start,
                                endTime: end,
                                in: modelContext
                            )
                        }
                    }
                }
            }
            .sheet(item: $editing) { song in
                SpeedEditorSheet(song: song) { speed in
                    save(speed, for: song)
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 0.5)
            .padding(.leading, SavedSongRow.titleInset)
    }

    // MARK: - Actions

    private func chooseSong() {
        Task { showPicker = await controller.requestAuthorizationIfNeeded() }
    }

    /// Re-adding a song keeps its tuned speed rather than resetting to 100%.
    private func add(_ song: Song) {
        if let existing = SavedSong.find(songID: song.id.rawValue, in: modelContext) {
            SavedSong.touch(existing, in: modelContext)
        } else {
            SavedSong.save(song: song, speed: 1.0, in: modelContext)
        }
    }

    /// `select` resets the playhead, so the jump has to come after it even
    /// when the song is already loaded.
    private func practice(_ song: SavedSong, jumpingTo marker: SongMarker? = nil) {
        loadingID = song.songID
        Task {
            // May be the first thing the user does after a reinstall.
            guard await controller.requestAuthorizationIfNeeded() else {
                loadingID = nil
                lookupError = "Allow Apple Music access in Settings to practice this song."
                return
            }
            do {
                try await controller.select(saved: song)
            } catch {
                loadingID = nil
                lookupError = message(for: error)
                return
            }
            loadingID = nil
            if let marker { controller.jump(to: marker) }
            onPractice()
        }
    }

    /// The song has to reach the player first (the editor plays the passage),
    /// but the tab stays put.
    private func openEditor(_ song: SavedSong, marker: SongMarker? = nil) {
        guard controller.selectedSong?.id.rawValue != song.songID else {
            present(song, marker: marker)
            return
        }
        loadingID = song.songID
        Task {
            guard await controller.requestAuthorizationIfNeeded() else {
                loadingID = nil
                lookupError = "Allow Apple Music access in Settings to mark up this song."
                return
            }
            do {
                try await controller.select(saved: song)
            } catch {
                loadingID = nil
                lookupError = message(for: error)
                return
            }
            loadingID = nil
            present(song, marker: marker)
        }
    }

    private func message(for error: Error) -> String {
        error is SongGoneError
            ? error.localizedDescription
            : "Couldn't find that song: \(error.localizedDescription)"
    }

    private func present(_ song: SavedSong, marker: SongMarker?) {
        guard controller.duration != nil else {
            lookupError = "Apple Music didn't say how long that song is, so it can't be marked up."
            return
        }
        let now = controller.pauseForMarking()
        marking = .init(song: song, marker: marker, start: marker?.startTime ?? now)
    }

    private func save(_ speed: Double, for song: SavedSong) {
        song.speed = speed
        SavedSong.touch(song, in: modelContext)
        if controller.selectedSong?.id.rawValue == song.songID {
            controller.playbackRate = speed
        }
    }

    private func delete(_ song: SavedSong) {
        for marker in song.markers ?? [] { controller.markerDeleted(marker) }
        modelContext.delete(song)
        try? modelContext.save()
    }

    private func update(_ marker: SongMarker, name: String, start: TimeInterval, end: TimeInterval?) {
        marker.set(name: name, start: start, end: end)
        try? modelContext.save()
        controller.markerChanged(marker)
    }

    private func delete(_ marker: SongMarker) {
        controller.markerDeleted(marker)
        SongMarker.delete(marker, in: modelContext)
    }
}

// MARK: - Order

private enum SongOrder: String, CaseIterable, Identifiable {
    case changed, practiced, title, artist

    var id: Self { self }

    var title: String {
        switch self {
        case .changed: "Last Changed"
        case .practiced: "Last Practiced"
        case .title: "Title"
        case .artist: "Artist"
        }
    }

    /// Takes the list most recently changed first, which a stable sort keeps
    /// as the tiebreak, including among songs never practised.
    func sorted(_ recentlyChanged: [SavedSong]) -> [SavedSong] {
        switch self {
        case .changed:
            recentlyChanged
        case .practiced:
            recentlyChanged.sorted { ($0.practicedAt ?? .distantPast) > ($1.practicedAt ?? .distantPast) }
        case .title:
            recentlyChanged.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist:
            recentlyChanged.sorted {
                switch $0.artistName.localizedStandardCompare($1.artistName) {
                case .orderedSame: $0.title.localizedStandardCompare($1.title) == .orderedAscending
                case let result: result == .orderedAscending
                }
            }
        }
    }
}

// MARK: - Row

private struct SavedSongRow: View {
    let song: SavedSong
    let isLoading: Bool
    /// Loaded in the practice screen, which on a wide iPad is right beside it.
    let isCurrent: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onEditSpeed: () -> Void
    let onAddMarker: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var markGlyphSize: CGFloat = 16

    /// Artwork plus gap; the pills and separator line up with it.
    static let titleInset: CGFloat = 76

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(song.title)
                        .font(.body)
                        .lineLimit(1)
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                            .accessibilityLabel("In practice")
                    }
                }
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Mark sits after the speed so it doesn't move as the percentage
            // changes width.
            HStack(spacing: 8) {
                Button(action: onEditSpeed) {
                    Text("\(song.percent)%")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentText)
                }
                // A plain button in a `List` row would let the whole row trigger it.
                .buttonStyle(.borderless)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.12), in: .capsule)
                .accessibilityLabel("Speed, \(song.percent) percent")
                .accessibilityHint("Change the practice speed")

                Button(action: onAddMarker) {
                    MarkGlyph()
                        .frame(width: markGlyphSize, height: markGlyphSize)
                        .foregroundStyle(Color.accentText)
                }
                .buttonStyle(.borderless)
                .padding(6)
                .background(.tint.opacity(0.12), in: .circle)
                .accessibilityLabel("Add marker")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Practice", onPlay)
        .accessibilityAction(named: "Add Marker", onAddMarker)
    }

    @ViewBuilder
    private var artwork: some View {
        if isLoading {
            placeholder { ProgressView() }
        } else if let artwork = song.artwork {
            ArtworkImage(artwork, width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 6))
        } else {
            placeholder { Image(systemName: "music.note").foregroundStyle(.secondary) }
        }
    }

    private func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .frame(width: 48, height: 48)
            .overlay(content())
    }
}

// MARK: - Speed editor

/// Changes only land on Done, so a stray spin doesn't rewrite the speed.
private struct SpeedEditorSheet: View {
    let song: SavedSong
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var speed: Double

    init(song: SavedSong, onSave: @escaping (Double) -> Void) {
        self.song = song
        self.onSave = onSave
        _speed = State(initialValue: song.speed)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(song.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // The medium detent is short in landscape and in small iPad
                // windows, so height bounds the wheel as well as width.
                GeometryReader { proxy in
                    SpeedWheelPicker(
                        speed: $speed,
                        diameter: min(min(260, max(160, proxy.size.width - 130)), proxy.size.height)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding()
            .navigationTitle("Practice Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Plain rather than `.confirm`, which fills solid coral; see
                    // MarkerEditorView.
                    Button {
                        onSave(speed)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Save")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Saved songs") {
    let container = try! AppSchema.inMemoryContainer()
    let context = ModelContext(container)
    SavedSong.save(
        songID: "1", title: "Blackbird", artistName: "The Beatles",
        artworkData: nil, speed: 0.75, in: context
    )
    let littleWing = SavedSong.save(
        songID: "2", title: "Little Wing", artistName: "Jimi Hendrix",
        artworkData: nil, speed: 0.6, in: context
    )
    SongMarker.add(to: littleWing, name: "Intro", startTime: 0, endTime: 22, in: context)
    SongMarker.add(to: littleWing, name: "", startTime: 95.5, endTime: nil, in: context)
    SavedSong.save(
        songID: "3", title: "Nothing Else Matters", artistName: "Metallica",
        artworkData: nil, speed: 1.0, in: context
    )

    return SavedSongsView(controller: PlaybackController()) {}
        .modelContainer(container)
}

#Preview("Empty") {
    SavedSongsView(controller: PlaybackController()) {}
        .modelContainer(try! AppSchema.inMemoryContainer())
}

#Preview("Speed editor") {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong(songID: "1", speed: 0.75, title: "Blackbird", artistName: "The Beatles")
    container.mainContext.insert(song)

    return SpeedEditorSheet(song: song) { _ in }
        .modelContainer(container)
}
