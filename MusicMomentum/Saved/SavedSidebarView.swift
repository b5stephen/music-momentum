//
//  SavedSidebarView.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

#if os(macOS)
import MusicKit
import SwiftData
import SwiftUI

/// Saved as the Mac window's source list: a header carrying the list scope,
/// Manage, Sort and Add, then the songs, with the search field as the list's
/// first row so it scrolls away with them. It sits translucent over the
/// artwork mesh, so it draws no background of its own.
struct SavedSidebarView: View {
    let controller: PlaybackController
    /// Stands in for `controller.selectedSong` in previews, since `Song` has
    /// no public initialiser.
    var previewCurrentID: String?
    /// Opens the picker that adds a song without loading it.
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \SavedSong.lastPracticed, order: .reverse)
    private var recentlyChanged: [SavedSong]
    @Query(sort: [SortDescriptor(\PracticeList.sortOrder), SortDescriptor(\PracticeList.createdAt)])
    private var lists: [PracticeList]
    @AppStorage("savedSongOrder") private var order: SongOrder = .title
    @AppStorage("savedListFilter") private var filterStorage = ""
    @AppStorage(SavedLayout.storageKey) private var layout: SavedLayout = .songs
    /// State, not `@AppStorage`, so the toggle's animation reaches the List.
    @State private var collapsed = ListFolder.Collapsed.stored

    @State private var filter: ListFilter = .all
    @State private var hasLoadedFilter = false
    @State private var searchTerm = ""
    @State private var loadingID: String?
    @State private var lookupError: String?
    @State private var listPrompt: ListPrompt?
    @State private var addingSongsToList: PracticeList?

    @Environment(\.scenePhase) private var scenePhase
    /// Settled at the moments SavedSongsView settles it, and as the search
    /// or filter changes, so a narrow result lists flat.
    @State private var settledCount: Int?

    private var showsFolders: Bool { layout == .lists && !lists.isEmpty }

    private var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// In Lists the folders do the filtering; the scope is kept for Songs.
    private var songs: [SavedSong] {
        (showsFolders ? ListFilter.all : filter).apply(to: recentlyChanged, searchTerm: searchTerm)
    }

    private var folders: [ListFolder] {
        ListFolder.folders(lists: lists, songs: order.sorted(songs), isSearching: isSearching)
    }

    private func isExpanded(_ folder: ListFolder) -> Bool {
        isSearching || !collapsed.ids.contains(folder.id)
    }

    private var unfiledCount: Int {
        recentlyChanged.filter(\.isUnfiled).count
    }

    private var activeSingleList: PracticeList? {
        guard !showsFolders, let id = filter.singleListID else { return nil }
        return lists.first { $0.listID == id }
    }

    private var isGrouped: Bool { !showsFolders && SongSection.groups(songCount: settledCount ?? songs.count) }

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
                        filteredEmptyView
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    if showsFolders {
                        // The header is the section's first row, not its
                        // header: the Mac's List rules off every section
                        // header edge to edge, which showed between closed
                        // folders and no separator modifier hid.
                        ForEach(folders) { folder in
                            Section {
                                // A row sits about 11pt further in than a
                                // section header, so 7 puts the chevron where
                                // Songs' letter headings start.
                                folderHeader(folder)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 7, bottom: 2, trailing: 8))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                if isExpanded(folder) {
                                    ForEach(folder.songs) { row($0, in: folder) }
                                    if folder.songs.isEmpty, let list = folder.list {
                                        emptyFolderRow(list)
                                    }
                                }
                            }
                        }
                    } else {
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
                }
                .animation(.snappy, value: layout)
                .animation(.snappy, value: collapsed.ids)
                .animation(.snappy, value: order)
                .animation(.snappy, value: isGrouped)
                .animation(.snappy, value: filter)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            if !hasLoadedFilter {
                hasLoadedFilter = true
                // A combination saved before the sidebar went to one list
                // at a time widens to All rather than showing an unnamed mix.
                if let restored = ListFilter(rawStorage: filterStorage), restored.selectedListIDs.count <= 1 {
                    filter = restored.reconciled(with: lists)
                }
            }
            settleGrouping()
        }
        .onChange(of: order) { settleGrouping() }
        .onChange(of: filter) { _, next in
            filterStorage = next.rawStorage
            settleGrouping()
        }
        .onChange(of: searchTerm) { settleGrouping() }
        .onChange(of: layout) { settleGrouping() }
        .onChange(of: collapsed.ids) { collapsed.store() }
        .onChange(of: lists) { _, updated in
            let reconciled = filter.reconciled(with: updated)
            if reconciled != filter { filter = reconciled }
            settleGrouping()
        }
        .onChange(of: scenePhase) { if scenePhase == .active { settleGrouping() } }
        .focusedSceneValue(\.newListAction, NewListAction { listPrompt = .create() })
        .listPrompts($listPrompt) { newList, hadInitialSongs in
            if !hadInitialSongs, !showsFolders {
                filter = .lists(ids: [newList.listID], match: filter.matchMode)
            }
        }
        .sheet(item: $addingSongsToList) { list in
            AddSongsToListSheet(list: list)
                .frame(minWidth: 400, minHeight: 440)
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

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
    }

    @ViewBuilder
    private var filteredEmptyView: some View {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: 8) {
            Text(!term.isEmpty ? "No matches" : activeSingleList.map { "No songs in \($0.name)" } ?? "No matching songs")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if term.isEmpty {
                if let list = activeSingleList {
                    Button("Add Songs\u{2026}") { addingSongsToList = list }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if filter.isActive {
                    Button("Show All Songs") { filter = .all }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 20)
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

    /// The header's title is the scope, so the sidebar needs no chip row
    /// repeating it; combining lists is left to the Manage window.
    private var scopeTitle: String {
        if showsFolders { return "Lists" }
        if let list = activeSingleList { return list.name }
        if filter == .unfiled { return "Not in a List" }
        return lists.isEmpty ? "Saved" : "All Songs"
    }

    private var header: some View {
        HStack(spacing: 2) {
            Menu {
                if !showsFolders {
                    Button {
                        filter = .all
                    } label: {
                        scopeItemLabel("All Songs (\(recentlyChanged.count))", selected: filter == .all)
                    }

                    if unfiledCount > 0 || filter == .unfiled {
                        Button {
                            filter = .unfiled
                        } label: {
                            scopeItemLabel("Not in a List (\(unfiledCount))", selected: filter == .unfiled)
                        }
                    }

                    if !lists.isEmpty {
                        Divider()
                        ForEach(lists) { list in
                            Button {
                                filter = filter.toggling(listID: list.listID, multiSelect: false)
                            } label: {
                                scopeItemLabel("\(list.name) (\(list.songCount))", selected: filter.contains(listID: list.listID))
                            }
                        }
                    }

                    Divider()
                }
                Button { listPrompt = .create() } label: {
                    Label("New List\u{2026}", systemImage: "folder.badge.plus")
                }
                if let list = activeSingleList {
                    Button { addingSongsToList = list } label: {
                        Label("Add Songs to \u{201C}\(list.name)\u{201D}\u{2026}", systemImage: "plus.circle")
                    }
                    Button { listPrompt = .rename(list) } label: {
                        Label("Rename \u{201C}\(list.name)\u{201D}\u{2026}", systemImage: "pencil")
                    }
                    Button(role: .destructive) { listPrompt = .delete(list) } label: {
                        Label("Delete \u{201C}\(list.name)\u{201D}", systemImage: "trash")
                    }
                }
                if !lists.isEmpty {
                    Divider()
                    Picker("View As", selection: $layout) {
                        ForEach(SavedLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Divider()
                Button {
                    openWindow(id: ManageSavedSongsView.windowID)
                } label: {
                    Label("Manage Saved Songs\u{2026}", systemImage: "rectangle.3.group")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(scopeTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.75)
                }
                .foregroundStyle(.secondary)
                .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(showsFolders ? "Lists" : "Filter by list")

            Spacer(minLength: 0)

            Button {
                openWindow(id: ManageSavedSongsView.windowID)
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Manage Saved Songs (\u{21E7}\u{2318}L)")
            .accessibilityLabel("Manage Saved Songs")

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

    @ViewBuilder
    private func scopeItemLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    // MARK: - Folders

    private func folderHeader(_ folder: ListFolder) -> some View {
        let isOpen = isExpanded(folder)
        return Button {
            withAnimation(.snappy) { collapsed.toggle(folder.id) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .opacity(isSearching ? 0 : 1)
                    .frame(width: 10)
                Text(folder.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(folder.songs.count)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.trailing, 10)
            .padding(.vertical, 3)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isSearching)
        .contextMenu {
            if let list = folder.list {
                Button("Add Songs\u{2026}") { addingSongsToList = list }
                Button("Rename\u{2026}") { listPrompt = .rename(list) }
                Divider()
                Button("Delete List", role: .destructive) { listPrompt = .delete(list) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.title), \(folder.songs.count) songs")
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        .accessibilityAddTraits(.isHeader)
    }

    private func emptyFolderRow(_ list: PracticeList) -> some View {
        Button("Add Songs\u{2026}") { addingSongsToList = list }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .listRowInsets(EdgeInsets(top: 4, leading: 23, bottom: 6, trailing: 8))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func settleGrouping() {
        settledCount = songs.count
    }

    /// `folder` is set in Lists, where the row's list is the folder it's
    /// under rather than the scope's.
    private func row(_ song: SavedSong, in folder: ListFolder? = nil) -> some View {
        let list = folder == nil ? activeSingleList : folder?.list
        return SavedSidebarRow(
            song: song,
            isLoading: loadingID == song.songID,
            isLoaded: isLoaded(song),
            isPlaying: controller.isPlaying
        ) { practice(song) }
        .contextMenu { contextMenu(for: song, in: list) }
        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func contextMenu(for song: SavedSong, in list: PracticeList?) -> some View {
        Button { practice(song) } label: { Label("Practice", systemImage: "play") }
        let markers = song.sortedMarkers
        if !markers.isEmpty {
            Menu {
                ForEach(markers) { marker in
                    Button(marker.name) { practice(song, jumpingTo: marker) }
                }
            } label: {
                Label("Practice From", systemImage: "arrow.turn.down.right")
            }
        }
        SavedListMenu(song: song, lists: lists) {
            listPrompt = .create(addingSongs: [song])
        }
        if let list {
            Button {
                PracticeList.remove([song], from: list, in: modelContext)
            } label: {
                Label("Remove from \u{201C}\(list.name)\u{201D}", systemImage: "minus.circle")
            }
        }
        Divider()
        Button("Delete", role: .destructive) { controller.delete(song, in: modelContext) }
    }

    private func isLoaded(_ song: SavedSong) -> Bool {
        if let selected = controller.selectedSong { return song.matches(selected) }
        return previewCurrentID == song.songID
    }

    private func practice(_ song: SavedSong, jumpingTo marker: SongMarker? = nil) {
        loadingID = song.songID
        Task {
            // A newer pick's row owns the spinner by now.
            defer { if loadingID == song.songID { loadingID = nil } }
            guard await controller.requestAuthorizationIfNeeded() else {
                lookupError = "Allow Apple Music access in System Settings to practice this song."
                return
            }
            do {
                guard try await controller.select(saved: song) else { return }
            } catch {
                lookupError = error is SongGoneError
                    ? error.localizedDescription
                    : "Couldn't find that song: \(error.localizedDescription)"
                return
            }
            if let marker { controller.jump(to: marker) }
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
    let s1 = SavedSong.save(songID: "1", title: "Harbour Lights", artistName: "Mara Ellis", artworkData: nil, speed: 0.75, in: context)
    let s2 = SavedSong.save(songID: "2", title: "Slow Burn Avenue", artistName: "The Kettle Lines", artworkData: nil, speed: 0.6, in: context)
    SavedSong.save(songID: "3", title: "Paper Moons", artistName: "June Okafor", artworkData: nil, speed: 0.8, in: context)
    SavedSong.save(songID: "4", title: "Night Ferry", artistName: "Low Tide Club", artworkData: nil, speed: 0.7, in: context)
    let list = PracticeList.create(name: "Level 1", in: context)
    PracticeList.add([s1, s2], to: list, in: context)
    return container
}
#endif
