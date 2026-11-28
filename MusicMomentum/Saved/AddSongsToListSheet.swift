//
//  AddSongsToListSheet.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import MusicKit
import SwiftData
import SwiftUI

/// Picks existing `SavedSong`s to add into a specific `PracticeList`.
struct AddSongsToListSheet: View {
    let list: PracticeList
    /// Offers Apple Music for a song not saved yet; the Mac's callers pass none.
    var controller: PlaybackController?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSong.title)
    private var allSongs: [SavedSong]

    @State private var searchTerm = ""
    @State private var selectedIDs = Set<PersistentIdentifier>()
    @State private var seeded = false
    @State private var showingPicker = false
    @State private var scrollTarget: PersistentIdentifier?

    private var filteredSongs: [SavedSong] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return allSongs }
        return allSongs.filter {
            $0.title.localizedStandardContains(term) || $0.artistName.localizedStandardContains(term)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allSongs.isEmpty, controller == nil {
                    ContentUnavailableView("No saved songs yet", systemImage: "bookmark")
                } else {
                    ScrollViewReader { proxy in
                        List {
                            if let controller, searchTerm.isEmpty {
                                appleMusicRow(controller)
                            }
                            ForEach(filteredSongs) { songRow($0) }
                        }
                        .listStyle(.plain)
                        .onChange(of: scrollTarget) { _, target in
                            guard let target else { return }
                            withAnimation { proxy.scrollTo(target, anchor: .center) }
                            scrollTarget = nil
                        }
                    }
                }
            }
            .navigationTitle("Songs in \(list.name)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchTerm, prompt: "Search saved songs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        applyMembership()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Save")
                }
            }
            .sheet(isPresented: $showingPicker) {
                SongPickerView(title: "Add Song to Saved", confirmTitle: "Add") { song in
                    pickFromAppleMusic(song)
                }
            }
            .onAppear {
                guard !seeded else { return }
                seeded = true
                selectedIDs = Set(list.songs.map(\.persistentModelID))
            }
        }
    }

    private func songRow(_ song: SavedSong) -> some View {
        let isSelected = selectedIDs.contains(song.persistentModelID)
        return Button {
            if isSelected {
                selectedIDs.remove(song.persistentModelID)
            } else {
                selectedIDs.insert(song.persistentModelID)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentText : Color.secondary)
                SavedSongArtwork(song: song, side: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .id(song.persistentModelID)
    }

    /// Laid out as the song rows below it, the tile in the artwork's column,
    /// matching Saved's Add Songs row.
    private func appleMusicRow(_ controller: PlaybackController) -> some View {
        Button {
            Task { showingPicker = await controller.requestAuthorizationIfNeeded() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle").hidden()
                Image(systemName: "music.note.list")
                    .font(.body.weight(.medium))
                    .foregroundStyle(controller.canUseMusic ? Color.accentText : Color.tertiaryLabel)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(controller.canUseMusic ? 0.14 : 0.06), in: .rect(cornerRadius: 6))
                Text("Find in Apple Music\u{2026}")
                    .font(.body)
                    .foregroundStyle(controller.canUseMusic ? Color.accentText : Color.tertiaryLabel)
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canUseMusic)
    }

    /// Saved at once, since that's what the picker says, but only ticked
    /// here: the list changes on ✓ like every other row.
    private func pickFromAppleMusic(_ song: Song) {
        let saved = SavedSong.add(song: song, in: modelContext)
        selectedIDs.insert(saved.persistentModelID)
        scrollTarget = saved.persistentModelID
    }

    private func applyMembership() {
        let toAdd = allSongs.filter { selectedIDs.contains($0.persistentModelID) }
        let toRemove = allSongs.filter { !selectedIDs.contains($0.persistentModelID) && $0.isInList(list) }
        PracticeList.add(toAdd, to: list, in: modelContext)
        PracticeList.remove(toRemove, from: list, in: modelContext)
    }
}

#Preview("Add songs to list") {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let list = PracticeList.create(name: "Level 1", in: context)
    let s1 = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: context)
    _ = SavedSong.save(songID: "2", title: "Little Wing", artistName: "Jimi Hendrix", artworkData: nil, speed: 0.6, in: context)
    PracticeList.add([s1], to: list, in: context)

    return AddSongsToListSheet(list: list, controller: PlaybackController())
        .modelContainer(container)
}
