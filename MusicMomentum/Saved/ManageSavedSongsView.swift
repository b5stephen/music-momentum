//
//  ManageSavedSongsView.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

#if os(macOS)
import MusicKit
import SwiftData
import SwiftUI

/// Dedicated macOS library window for bulk-organizing saved songs into lists,
/// checking speeds and markers, and opening songs in Practice.
struct ManageSavedSongsView: View {
    static let windowID = "manage-saved"

    let controller: PlaybackController
    var previewCurrentID: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \SavedSong.lastPracticed, order: .reverse)
    private var allSongs: [SavedSong]
    @Query(sort: [SortDescriptor(\PracticeList.sortOrder), SortDescriptor(\PracticeList.createdAt)])
    private var lists: [PracticeList]

    private enum SidebarItem: Hashable {
        case all
        case unfiled
        case practiced
        case list(String)
    }

    private struct TableSong: Identifiable {
        let id: PersistentIdentifier
        let song: SavedSong
        let titleKey: String
        let artist: String
        let speed: Double
        let markerCount: Int
        let practicedAt: Date
    }

    /// Held in state rather than built in a binding's getter: a fresh `id` on
    /// every redraw made the sheet re-present and drop its unsaved ticks.
    private struct SongSelectionBatch: Identifiable {
        let id = UUID()
        let songs: [SavedSong]
    }

    nonisolated private struct TableSort: SortComparator, Hashable, Sendable {
        enum Field: Hashable, Sendable {
            case title, speed, markers, practiced
        }

        var field: Field
        var order: SortOrder = .forward

        func compare(_ lhs: TableSong, _ rhs: TableSong) -> ComparisonResult {
            let base: ComparisonResult
            switch field {
            case .title:
                base = lhs.titleKey.localizedStandardCompare(rhs.titleKey)
            case .speed:
                base = lhs.speed < rhs.speed ? .orderedAscending : (lhs.speed > rhs.speed ? .orderedDescending : .orderedSame)
            case .markers:
                base = lhs.markerCount < rhs.markerCount ? .orderedAscending : (lhs.markerCount > rhs.markerCount ? .orderedDescending : .orderedSame)
            case .practiced:
                base = lhs.practicedAt < rhs.practicedAt ? .orderedAscending : (lhs.practicedAt > rhs.practicedAt ? .orderedDescending : .orderedSame)
            }
            guard order == .reverse else { return base }
            return switch base {
            case .orderedAscending: .orderedDescending
            case .orderedDescending: .orderedAscending
            case .orderedSame: .orderedSame
            }
        }
    }

    @State private var sidebarItem: SidebarItem? = .all
    @State private var extraFilterIDs = Set<String>()
    @State private var matchMode: ListFilter.MatchMode = .all
    @State private var searchTerm = ""
    @State private var selection = Set<PersistentIdentifier>()
    @State private var sortOrder = [TableSort(field: .title)]
    @State private var listPrompt: ListPrompt?
    @State private var showingSongPicker = false
    @State private var assigning: SongSelectionBatch?
    @State private var addingSongsToList: PracticeList?
    @State private var speedEditingSong: SavedSong?
    @State private var listPopoverSong: SavedSong?
    @State private var lookupError: String?
    /// Matched by eye to the Library rows' default insets.
    private static let listRowPadding = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)

    private var activeList: PracticeList? {
        guard case let .list(id) = sidebarItem else { return nil }
        return lists.first { $0.listID == id }
    }

    private var unfiledCount: Int {
        allSongs.filter(\.isUnfiled).count
    }

    private var practicedCount: Int {
        allSongs.filter { $0.practicedAt != nil }.count
    }

    private var displayedSongs: [SavedSong] {
        let base: [SavedSong]
        switch sidebarItem ?? .all {
        case .all:
            base = extraFilterIDs.isEmpty
                ? allSongs
                : ListFilter.lists(ids: extraFilterIDs, match: matchMode).apply(to: allSongs)
        case .unfiled:
            base = allSongs.filter(\.isUnfiled)
        case .practiced:
            base = allSongs.filter { $0.practicedAt != nil }
        case let .list(id):
            var ids: Set<String> = [id]
            ids.formUnion(extraFilterIDs)
            base = ListFilter.lists(ids: ids, match: matchMode).apply(to: allSongs)
        }

        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return base }
        return base.filter { song in
            song.title.localizedStandardContains(term)
                || song.artistName.localizedStandardContains(term)
                || song.lists.contains { $0.name.localizedStandardContains(term) }
        }
    }

    private var sortedRows: [TableSong] {
        displayedSongs.map { song in
            TableSong(
                id: song.persistentModelID,
                song: song,
                titleKey: String(SongSection.sortingName(song.title)),
                artist: String(SongSection.sortingName(song.artistName)),
                speed: song.speed,
                markerCount: (song.markers ?? []).count,
                practicedAt: song.practicedAt ?? .distantPast
            )
        }
        .sorted(using: sortOrder)
    }

    private var selectedSongs: [SavedSong] {
        displayedSongs.filter { selection.contains($0.persistentModelID) }
    }

    var body: some View {
        splitView
            .navigationTitle(detailTitle)
            .searchable(text: $searchTerm, prompt: "Search songs, artists, or lists")
            .toolbar { toolbarContent }
            .focusedSceneValue(\.newListAction, NewListAction { listPrompt = .create() })
            .listPrompts($listPrompt) { newList, hadInitialSongs in
                if !hadInitialSongs {
                    sidebarItem = .list(newList.listID)
                }
            }
            .sheet(isPresented: $showingSongPicker) { songPickerSheet }
            .sheet(item: $addingSongsToList) { list in
                AddSongsToListSheet(list: list)
                    .frame(minWidth: 420, minHeight: 460)
            }
            .sheet(item: $assigning) { batch in
                AssignListsSheet(songs: batch.songs)
                    .frame(minWidth: 360, minHeight: 380)
            }
            .alert("Couldn't open that song", isPresented: lookupAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lookupError ?? "")
            }
            .onChange(of: lists) { _, updated in
                let validIDs = Set(updated.map(\.listID))
                extraFilterIDs.formIntersection(validIDs)
                if case let .list(id) = sidebarItem, !validIDs.contains(id) {
                    sidebarItem = .all
                }
            }
            .onChange(of: sidebarItem) { _, _ in
                selection.removeAll()
            }
    }

    private var splitView: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            detail
        }
    }

    private var songPickerSheet: some View {
        let targetList = activeList
        return SongPickerView(title: "Add Song to Saved", confirmTitle: "Add") { song in
            let saved = SavedSong.add(song: song, in: modelContext)
            if let targetList {
                PracticeList.add([saved], to: targetList, in: modelContext)
            }
        }
    }

    private var lookupAlertBinding: Binding<Bool> {
        Binding(
            get: { lookupError != nil },
            set: { if !$0 { lookupError = nil } }
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $sidebarItem) {
            Section("Library") {
                sidebarRow("All Songs", icon: "bookmark", count: allSongs.count)
                    .tag(SidebarItem.all)
                sidebarRow("Unfiled", icon: "tray", count: unfiledCount)
                    .tag(SidebarItem.unfiled)
                sidebarRow("Recently Practiced", icon: "clock", count: practicedCount)
                    .tag(SidebarItem.practiced)
            }

            Section("Lists") {
                ForEach(lists) { list in
                    // The row's insets sat outside the drop target, so the
                    // drop highlight only came on with the pointer over the
                    // label. The insets move inside the row's content instead.
                    sidebarRow(list.name, icon: "folder", count: list.songCount)
                        .padding(Self.listRowPadding)
                        .contentShape(.rect)
                        .tag(SidebarItem.list(list.listID))
                        .contextMenu {
                            Button { addingSongsToList = list } label: {
                                Label("Add Songs\u{2026}", systemImage: "plus.circle")
                            }
                            Button { listPrompt = .rename(list) } label: {
                                Label("Rename\u{2026}", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) { listPrompt = .delete(list) } label: {
                                Label("Delete List", systemImage: "trash")
                            }
                        }
                        .dropDestination(for: String.self) { items, _ in
                            assignDraggedIDs(items, to: list)
                        }
                        .listRowInsets(EdgeInsets())
                }
                .onMove { source, destination in
                    var reordered = lists
                    reordered.move(fromOffsets: source, toOffset: destination)
                    PracticeList.reorder(reordered, in: modelContext)
                }

                Button {
                    listPrompt = .create()
                } label: {
                    Label("New List\u{2026}", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(_ title: String, icon: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            if !extraFilterIDs.isEmpty {
                combinedFilterStrip
            }

            if allSongs.isEmpty {
                ContentUnavailableView {
                    Label("No saved songs yet", systemImage: "bookmark")
                } description: {
                    Text("Save a song to adjust its speed, add markers, and organize it into lists.")
                } actions: {
                    Button("Add Song") { addSong() }
                        .buttonStyle(CallToActionButtonStyle())
                        .disabled(!controller.canUseMusic)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedSongs.isEmpty {
                emptyFilterState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(selection: $selection, sortOrder: $sortOrder) {
                    TableColumn("Song", sortUsing: TableSort(field: .title)) { item in
                        songCell(item.song)
                    }
                    .width(min: 220, ideal: 290)

                    TableColumn("Lists") { item in
                        listsCell(item.song)
                    }
                    .width(min: 180, ideal: 260)

                    TableColumn("Speed", sortUsing: TableSort(field: .speed)) { item in
                        speedCell(item.song)
                    }
                    .width(min: 70, ideal: 80)

                    TableColumn("Markers", sortUsing: TableSort(field: .markers)) { item in
                        Text(markerSummary(for: item.song))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 95, ideal: 120)

                    TableColumn("Last Practiced", sortUsing: TableSort(field: .practiced)) { item in
                        practicedCell(item.song)
                    }
                    .width(min: 105, ideal: 130)
                } rows: {
                    ForEach(sortedRows) { item in
                        TableRow(item)
                            .draggable(dragPayload(for: item))
                            .contextMenu { rowContextMenu(for: item.song) }
                    }
                }
                .onKeyPress(.return) {
                    guard selectedSongs.count == 1, let song = selectedSongs.first else { return .ignored }
                    openInPractice(song)
                    return .handled
                }
            }

            if !selection.isEmpty {
                bulkBar
            }
        }
    }

    private var combinedFilterStrip: some View {
        HStack(spacing: 8) {
            Text("Filtered by:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(lists.filter { extraFilterIDs.contains($0.listID) }) { list in
                Button {
                    extraFilterIDs.remove(list.listID)
                } label: {
                    HStack(spacing: 4) {
                        Text(list.name)
                            .font(.caption.weight(.medium))
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.accentText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.14), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            if extraFilterIDs.count > 1 || activeList != nil {
                Picker("Match", selection: $matchMode) {
                    Text("Match All").tag(ListFilter.MatchMode.all)
                    Text("Match Any").tag(ListFilter.MatchMode.any)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            Spacer()
            Button("Clear") { extraFilterIDs.removeAll() }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private var emptyFilterState: some View {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            ContentUnavailableView.search(text: term)
        } else if let list = activeList {
            ContentUnavailableView {
                Label("No songs in \(list.name)", systemImage: "folder")
            } description: {
                Text("Drag songs onto \u{201C}\(list.name)\u{201D} in the sidebar, or add existing saved songs.")
            } actions: {
                Button("Add Songs\u{2026}") { addingSongsToList = list }
                    .buttonStyle(CallToActionButtonStyle())
            }
        } else {
            ContentUnavailableView("No matching songs", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private func songCell(_ song: SavedSong) -> some View {
        HStack(spacing: 10) {
            SavedSongArtwork(song: song, side: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(song.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if isLoaded(song) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .onTapGesture(count: 2) { openInPractice(song) }
    }

    private func listsCell(_ song: SavedSong) -> some View {
        HStack(spacing: 6) {
            ForEach(song.lists.prefix(3)) { list in
                HStack(spacing: 4) {
                    Text(list.name)
                        .font(.caption)
                        .lineLimit(1)
                    Button {
                        PracticeList.remove([song], from: list, in: modelContext)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .opacity(0.6)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from \(list.name)")
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: .capsule)
            }

            if song.lists.count > 3 {
                Text("+\(song.lists.count - 3)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                listPopoverSong = song
            } label: {
                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Assign lists")
            .popover(isPresented: Binding(
                get: { listPopoverSong?.persistentModelID == song.persistentModelID },
                set: { if !$0 { listPopoverSong = nil } }
            )) {
                ListMembershipPopover(song: song, lists: lists) {
                    listPopoverSong = nil
                    listPrompt = .create(addingSongs: [song])
                }
            }
        }
    }

    private func speedCell(_ song: SavedSong) -> some View {
        Button {
            speedEditingSong = song
        } label: {
            Text("\(song.percent)%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { speedEditingSong?.persistentModelID == song.persistentModelID },
            set: { if !$0 { speedEditingSong = nil } }
        )) {
            SpeedPopover(song: song) { newSpeed in
                save(speed: newSpeed, for: song)
            }
        }
    }

    private func practicedCell(_ song: SavedSong) -> some View {
        Group {
            if let date = song.practicedAt {
                Text(date, style: .relative)
            } else {
                Text("Never")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var bulkBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedSongs.count) selected")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Add to Lists\u{2026}") {
                assigning = SongSelectionBatch(songs: selectedSongs)
            }

            if let list = activeList {
                Button("Remove from \u{201C}\(list.name)\u{201D}") {
                    PracticeList.remove(selectedSongs, from: list, in: modelContext)
                    selection.removeAll()
                }
            }

            Menu("Set Speed") {
                ForEach(SpeedInput.menuSpeeds, id: \.self) { percent in
                    Button("\(percent)%") {
                        let rate = Double(percent) / 100
                        for song in selectedSongs { save(speed: rate, for: song) }
                    }
                }
            }

            Button("Delete", role: .destructive) {
                for song in selectedSongs { controller.delete(song, in: modelContext) }
                selection.removeAll()
            }

            Button("Clear") { selection.removeAll() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            // A bare list of names gave no hint that picking one filters
            // the table, so the menu says what it does, and the picks show
            // as removable tags under the toolbar.
            Menu {
                if lists.isEmpty {
                    Text("No lists yet")
                } else {
                    Section(activeList == nil ? "Show songs in" : "Also filter by") {
                        ForEach(lists.filter { $0.listID != activeList?.listID }) { list in
                            Toggle(list.name, isOn: Binding(
                                get: { extraFilterIDs.contains(list.listID) },
                                set: { isOn in
                                    if isOn {
                                        extraFilterIDs.insert(list.listID)
                                    } else {
                                        extraFilterIDs.remove(list.listID)
                                    }
                                }
                            ))
                        }
                    }
                    if extraFilterIDs.count > 1 || (activeList != nil && !extraFilterIDs.isEmpty) {
                        Picker("Match", selection: $matchMode) {
                            ForEach(ListFilter.MatchMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    if !extraFilterIDs.isEmpty {
                        Divider()
                        Button("Clear Filters") { extraFilterIDs.removeAll() }
                    }
                }
            } label: {
                // Coral while a filter is on, per "coral means on".
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(extraFilterIDs.isEmpty ? Color.secondary : Color.accentColor)
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("Filter by List")
            .help(extraFilterIDs.isEmpty
                ? "Filter by list: show only songs in the lists you pick"
                : "Filtered by \(extraFilterIDs.count) \(extraFilterIDs.count == 1 ? "list" : "lists")")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                if let song = selectedSongs.first { openInPractice(song) }
            } label: {
                Label("Open in Practice", systemImage: "play")
            }
            .disabled(selectedSongs.count != 1)
            .help("Load the selected song into Practice")
        }

        ToolbarItem(placement: .primaryAction) {
            if let list = activeList {
                Menu {
                    Button("Add from Saved\u{2026}") { addingSongsToList = list }
                    Button("Add from Apple Music\u{2026}") { addSong() }
                        .disabled(!controller.canUseMusic)
                } label: {
                    Label("Add Songs", systemImage: "plus")
                }
            } else {
                Button { addSong() } label: {
                    Label("Add Song", systemImage: "plus")
                }
                .disabled(!controller.canUseMusic)
            }
        }
    }

    @ViewBuilder
    private func rowContextMenu(for song: SavedSong) -> some View {
        Button { openInPractice(song) } label: { Label("Open in Practice", systemImage: "play") }
        SavedListMenu(song: song, lists: lists) {
            listPrompt = .create(addingSongs: [song])
        }
        if let list = activeList {
            Button {
                PracticeList.remove([song], from: list, in: modelContext)
            } label: {
                Label("Remove from \u{201C}\(list.name)\u{201D}", systemImage: "minus.circle")
            }
        }
        Divider()
        Button("Delete", role: .destructive) { controller.delete(song, in: modelContext) }
    }

    private var detailTitle: String {
        switch sidebarItem ?? .all {
        case .all: "All Saved Songs"
        case .unfiled: "Unfiled Songs"
        case .practiced: "Recently Practiced"
        case let .list(id): lists.first { $0.listID == id }?.name ?? "Saved Songs"
        }
    }

    // MARK: - Helpers

    private func markerSummary(for song: SavedSong) -> String {
        let markers = song.markers ?? []
        let loops = markers.filter(\.isClip).count
        let points = markers.count - loops
        switch (loops, points) {
        case (0, 0): return "\u{2014}"
        case let (l, 0): return l == 1 ? "1 loop" : "\(l) loops"
        case let (0, p): return p == 1 ? "1 marker" : "\(p) markers"
        case let (l, p): return "\(l)L \u{00B7} \(p)M"
        }
    }

    private func isLoaded(_ song: SavedSong) -> Bool {
        if let selected = controller.selectedSong { return song.matches(selected) }
        return previewCurrentID == song.songID
    }

    private func dragPayload(for item: TableSong) -> String {
        if selection.contains(item.id) {
            return selectedSongs.map(\.songID).joined(separator: "\n")
        }
        return item.song.songID
    }

    private func assignDraggedIDs(_ payloads: [String], to list: PracticeList) -> Bool {
        let ids = Set(payloads.flatMap { $0.split(separator: "\n").map(String.init) })
        let songs = allSongs.filter { ids.contains($0.songID) }
        guard !songs.isEmpty else { return false }
        PracticeList.add(songs, to: list, in: modelContext)
        return true
    }

    private func addSong() {
        Task {
            if await controller.requestAuthorizationIfNeeded() {
                showingSongPicker = true
            }
        }
    }

    private func save(speed: Double, for song: SavedSong) {
        song.speed = speed
        SavedSong.touch(song, in: modelContext)
        if let selected = controller.selectedSong, song.matches(selected) {
            controller.playbackRate = speed
        }
    }

    private func openInPractice(_ song: SavedSong) {
        Task {
            guard await controller.requestAuthorizationIfNeeded() else {
                lookupError = "Allow Apple Music access in System Settings to practice this song."
                return
            }
            do {
                guard try await controller.select(saved: song) else { return }
                openWindow(id: "main")
            } catch {
                lookupError = error is SongGoneError
                    ? error.localizedDescription
                    : "Couldn't find that song: \(error.localizedDescription)"
            }
        }
    }
}

private struct ListMembershipPopover: View {
    let song: SavedSong
    let lists: [PracticeList]
    let onNewList: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lists")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if lists.isEmpty {
                Text("No lists yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lists) { list in
                    let included = song.isInList(list)
                    Button {
                        if included {
                            PracticeList.remove([song], from: list, in: modelContext)
                        } else {
                            PracticeList.add([song], to: list, in: modelContext)
                        }
                    } label: {
                        HStack {
                            Image(systemName: included ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(included ? Color.accentText : Color.secondary)
                            Text(list.name)
                            Spacer()
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            Button {
                onNewList()
            } label: {
                Label("New List\u{2026}", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(minWidth: 180)
    }
}

private struct SpeedPopover: View {
    let song: SavedSong
    let onCommit: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var percent: Int

    init(song: SavedSong, onCommit: @escaping (Double) -> Void) {
        self.song = song
        self.onCommit = onCommit
        _percent = State(initialValue: song.percent)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("\(percent)%")
                .font(.title3.weight(.bold).monospacedDigit())

            Slider(
                value: Binding(
                    get: { Double(percent) },
                    set: { percent = Int($0.rounded()) }
                ),
                in: PlaybackController.speedRange.lowerBound * 100...PlaybackController.speedRange.upperBound * 100,
                step: 1
            )
            .frame(width: 170)

            HStack(spacing: 6) {
                ForEach(SpeedInput.presets, id: \.self) { preset in
                    Button("\(preset)%") {
                        percent = preset
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onCommit(Double(percent) / 100)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }
}

// MARK: - Previews

#Preview("Manage saved songs", traits: .fixedLayout(width: 980, height: 640)) {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let s1 = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: context)
    let s2 = SavedSong.save(songID: "2", title: "Little Wing", artistName: "Jimi Hendrix", artworkData: nil, speed: 0.6, in: context)
    SavedSong.save(songID: "3", title: "Autumn Leaves", artistName: "Miles Davis", artworkData: nil, speed: 0.85, in: context)
    SongMarker.add(to: s2, name: "Intro", startTime: 0, endTime: 22, in: context)
    let acoustic = PracticeList.create(name: "Acoustic", in: context)
    let level2 = PracticeList.create(name: "Level 2", in: context)
    PracticeList.add([s1], to: acoustic, in: context)
    PracticeList.add([s1, s2], to: level2, in: context)

    return ManageSavedSongsView(controller: PlaybackController(), previewCurrentID: "2")
        .modelContainer(container)
}

#Preview("Empty library", traits: .fixedLayout(width: 980, height: 640)) {
    ManageSavedSongsView(controller: PlaybackController())
        .modelContainer(try! AppSchema.inMemoryContainer())
}
#endif
