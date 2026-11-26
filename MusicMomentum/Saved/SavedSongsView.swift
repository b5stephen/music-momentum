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
    /// Stands in for `controller.selectedSong` in previews, since `Song` has
    /// no public initialiser.
    var previewCurrentID: String?
    /// Brings the practice tab forward.
    let onPractice: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSong.lastPracticed, order: .reverse)
    private var recentlyChanged: [SavedSong]
    @Query(sort: [SortDescriptor(\PracticeList.sortOrder), SortDescriptor(\PracticeList.createdAt)])
    private var lists: [PracticeList]
    /// Per device rather than synced: it's how this screen is read, not data.
    @AppStorage("savedSongOrder") private var order: SongOrder = .title
    @AppStorage("savedListFilter") private var filterStorage = ""
    @AppStorage(SavedLayout.storageKey) private var layout: SavedLayout = .songs
    @AppStorage("savedCollapsedFolders") private var collapsed = ListFolder.Collapsed()

    @Environment(\.scenePhase) private var scenePhase
    /// The song count grouping was last decided on. It's settled only when
    /// Saved appears, the sort or filter changes, a song is added or the app
    /// comes back, so deleting the twelfth song doesn't pull the headers out
    /// from under the user mid-edit.
    @State private var settledCount: Int?
    @State private var filter: ListFilter = .all
    @State private var hasLoadedFilter = false
    @State private var searchTerm = ""

    /// With no lists there's nothing to fold, so Lists reads as Songs.
    private var showsFolders: Bool { layout == .lists && !lists.isEmpty }

    private var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The folders are the filter in Lists, so the chips' choice is set
    /// aside rather than cleared, ready for Songs again.
    private var filteredSongs: [SavedSong] {
        (showsFolders ? ListFilter.all : filter).apply(to: recentlyChanged, searchTerm: searchTerm)
    }

    private var folders: [ListFolder] {
        ListFolder.folders(lists: lists, songs: order.sorted(filteredSongs), isSearching: isSearching)
    }

    /// Searching opens every folder, so a match is never hidden in a closed one.
    private func isExpanded(_ folder: ListFolder) -> Bool {
        isSearching || !collapsed.ids.contains(folder.id)
    }

    private var unfiledCount: Int {
        recentlyChanged.filter(\.isUnfiled).count
    }

    /// The rows on screen, so Select All leaves a closed folder's alone.
    private var visibleRows: [ListFolder.Row] {
        guard showsFolders else {
            return filteredSongs.map { ListFolder.Row(folderID: "", song: $0.persistentModelID) }
        }
        return folders.filter(isExpanded).flatMap { folder in
            folder.songs.map { ListFolder.Row(folderID: folder.id, song: $0.persistentModelID) }
        }
    }

    /// Against what's shown, not a count: a selection can outlive a search
    /// that hides some of it.
    private var allVisibleSelected: Bool {
        let rows = visibleRows
        return !rows.isEmpty && rows.allSatisfy(selectedIDs.contains)
    }

    /// Taps only select while selecting; otherwise a tap practises the song
    /// and the List mustn't keep a highlight for it.
    private var selection: Binding<Set<ListFolder.Row>> {
        Binding(
            get: { isSelecting ? selectedIDs : [] },
            set: { if isSelecting { selectedIDs = $0 } }
        )
    }

    private var activeSingleList: PracticeList? {
        guard !showsFolders, let id = filter.singleListID else { return nil }
        return lists.first { $0.listID == id }
    }

    private var isGrouped: Bool { !showsFolders && SongSection.groups(songCount: settledCount ?? filteredSongs.count) }
    private var showsIndex: Bool { isGrouped && order != .practiced }
    /// Ungrouped, one section with no header, so the rows keep their identity
    /// and slide into sections rather than reloading.
    private var sections: [SongSection] {
        isGrouped
            ? order.sections(filteredSongs)
            : [SongSection(id: "all", title: "", indexLabel: nil, songs: order.sorted(filteredSongs))]
    }
    /// Beside the card, the rows end as far from the window edge as the card
    /// sits from every edge, so the page reads as one set of margins.
    /// Clears the side index too, which otherwise sits over the speeds.
    private var trailingInset: CGFloat { (isBesidePractice ? 28 : 16) + (showsIndex ? 14 : 0) }

    @State private var showPicker = false
    @State private var editing: SavedSong?
    @State private var loadingID: String?
    @State private var lookupError: String?
    @State private var marking: Marking?
    @State private var isSelecting = false
    @State private var selectedIDs = Set<ListFolder.Row>()
    @State private var listPrompt: ListPrompt?
    @State private var showingListManager = false
    @State private var addingSongsToList: PracticeList?
    @State private var assigning: SongSelectionBatch?
    #if DEBUG
    /// Hidden while the samples are loaded, since they're for screenshots.
    @State private var showsDebugMenu = !SampleSong.isRequested
    #endif

    /// Held in state rather than built in a binding's getter: a fresh `id` on
    /// every redraw made the sheet re-present and drop its unsaved ticks.
    private struct SongSelectionBatch: Identifiable {
        let id = UUID()
        let songs: [SavedSong]
    }

    private struct Marking: Identifiable {
        let song: SavedSong
        let start: TimeInterval
        /// Set for a loop that isn't saved yet, made from a marker.
        var end: TimeInterval?

        /// Differs for the loop so Make a loop rebuilds the sheet.
        var id: String {
            "new\(end == nil ? "" : "-loop")-\(song.persistentModelID.hashValue)"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recentlyChanged.isEmpty, isBesidePractice {
                    ContentUnavailableView("No saved songs yet", systemImage: "bookmark")
                } else if recentlyChanged.isEmpty {
                    AroundCrease {
                        ContentUnavailableView {
                            emptyLabel
                        } description: {
                            emptyDescription
                        } actions: {
                            addSongButton
                        }
                    } above: {
                        ContentUnavailableView {
                            emptyLabel
                        } description: {
                            emptyDescription
                        }
                    } below: {
                        addSongButton
                    }
                } else {
                    // The List stays the root even when the filter empties it:
                    // wrapped in a stack, it lost the large title. The chips
                    // are its first row, scrolling away as the Mac sidebar's
                    // search field does; in a bar on the List, the bar's edge
                    // blur lay over the large title in a narrow window.
                    List(selection: selection) {
                        if showsFolders {
                            ForEach(folders) { folder in
                                Section {
                                    if isExpanded(folder) {
                                        ForEach(folder.songs) { row($0, in: folder) }
                                        if folder.songs.isEmpty, let list = folder.list {
                                            emptyFolderRow(list)
                                        }
                                    }
                                } header: {
                                    folderHeader(folder)
                                }
                            }
                        } else {
                            if !lists.isEmpty {
                                filterBar
                            }
                            ForEach(sections) { section in
                                if isGrouped {
                                    Section {
                                        ForEach(section.songs) { row($0) }
                                    } header: {
                                        Text(section.title)
                                    }
                                    #if os(iOS)
                                    .sectionIndexLabel(section.indexLabel)
                                    #endif
                                } else {
                                    Section {
                                        ForEach(section.songs) { row($0) }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    #if os(iOS)
                    .listSectionSpacing(0)
                    .listSectionIndexVisibility(showsIndex ? .visible : .hidden)
                    .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
                    #endif
                    .overlay {
                        if filteredSongs.isEmpty {
                            filteredEmptyState
                        }
                    }
                    .animation(.snappy, value: order)
                    .animation(.snappy, value: isGrouped)
                    .animation(.snappy, value: filter)
                    .animation(.snappy, value: layout)
                }
            }
            // Beside the card, the stack's own opaque background (and the
            // rows', cleared above) would box the list off from the cover's glow.
            #if os(iOS)
            .containerBackground(
                isBesidePractice ? AnyShapeStyle(.clear) : AnyShapeStyle(Color.systemBackground),
                for: .navigation
            )
            #endif
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(isBesidePractice ? .inline : .automatic)
            #endif
            .conditionalSearchable(!recentlyChanged.isEmpty, text: $searchTerm)
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { endSelection() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(allVisibleSelected ? "Deselect All" : "Select All") {
                            if allVisibleSelected {
                                selectedIDs.removeAll()
                            } else {
                                selectedIDs = Set(visibleRows)
                            }
                        }
                    }
                    #if os(iOS)
                    ToolbarItemGroup(placement: .bottomBar) { selectionActions }
                    #else
                    ToolbarItemGroup(placement: .automatic) { selectionActions }
                    #endif
                } else {
                    // Hidden rather than disabled: a greyed glyph beside Add read
                    // as a second, broken add button.
                    if !recentlyChanged.isEmpty {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Picker("Sort By", selection: $order) {
                                    ForEach(SongOrder.allCases) { order in
                                        Text(order.title).tag(order)
                                    }
                                }
                                .pickerStyle(.inline)
                            } label: {
                                // An `Image`, not a `Label`: the toolbar drops a
                                // label's foreground style and draws it black.
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .accessibilityLabel("Sort")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        if let list = activeSingleList {
                            Menu {
                                Button {
                                    addingSongsToList = list
                                } label: {
                                    Label("Add from Saved\u{2026}", systemImage: "bookmark")
                                }
                                Button {
                                    chooseSong()
                                } label: {
                                    Label("Add from Apple Music\u{2026}", systemImage: "music.note.list")
                                }
                                .disabled(!controller.canUseMusic)
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .accessibilityLabel("Add Songs")
                        } else {
                            Button {
                                chooseSong()
                            } label: {
                                // Recoloured by hand, so it has to grey itself when disabled.
                                Image(systemName: "plus")
                                    .foregroundStyle(controller.canUseMusic ? Color.accentColor : Color.tertiaryLabel)
                            }
                            .accessibilityLabel("Add Song")
                            .disabled(!controller.canUseMusic)
                        }
                    }
                    if !recentlyChanged.isEmpty || !lists.isEmpty {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                if !filteredSongs.isEmpty {
                                    Button {
                                        isSelecting = true
                                    } label: {
                                        Label("Select Songs", systemImage: "checkmark.circle")
                                    }
                                }
                                Button {
                                    listPrompt = .create()
                                } label: {
                                    Label("New List\u{2026}", systemImage: "folder.badge.plus")
                                }
                                if !lists.isEmpty {
                                    Button {
                                        showingListManager = true
                                    } label: {
                                        Label("Manage Lists\u{2026}", systemImage: "list.bullet")
                                    }
                                    Picker("View As", selection: $layout) {
                                        ForEach(SavedLayout.allCases) { layout in
                                            Label(layout.title, systemImage: layout.systemImage).tag(layout)
                                        }
                                    }
                                    .pickerStyle(.inline)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .accessibilityLabel("More")
                        }
                    }
                    #if DEBUG
                    if showsDebugMenu {
                        ToolbarSpacer(.fixed, placement: .primaryAction)
                        ToolbarItem(placement: .primaryAction) {
                            CloudKitSchemaMenu()
                        }
                    }
                    #endif
                }
            }
            #if DEBUG
            .onShake {
                if SampleSong.isRequested { showsDebugMenu.toggle() }
            }
            #endif
            .sheet(isPresented: $showPicker) {
                let targetList = activeSingleList
                SongPickerView { song in
                    let saved = SavedSong.add(song: song, in: modelContext)
                    if let targetList {
                        PracticeList.add([saved], to: targetList, in: modelContext)
                    }
                }
            }
            .sheet(isPresented: $showingListManager) {
                ListManagerSheet(filter: $filter)
            }
            .sheet(item: $addingSongsToList) { list in
                AddSongsToListSheet(list: list)
            }
            .sheet(item: $assigning) { batch in
                AssignListsSheet(songs: batch.songs)
            }
            .listPrompts($listPrompt) { newList, hadInitialSongs in
                // In Lists the new folder shows itself.
                if !hadInitialSongs, !showsFolders {
                    filter = .lists(ids: [newList.listID], match: filter.matchMode)
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
            .sheet(item: $marking) { marking in
                if let duration = controller.duration {
                    MarkerEditorView(
                        marker: nil,
                        initialStart: marking.start,
                        initialEnd: marking.end,
                        duration: duration,
                        controller: controller,
                        otherPoints: marking.song.pointSpans(excluding: nil),
                        otherLoopNames: marking.song.loopNames(excluding: nil),
                        onSave: { name, start, end in
                            SongMarker.add(
                                to: marking.song,
                                name: name,
                                startTime: start,
                                endTime: end,
                                in: modelContext
                            )
                        },
                        onMakeLoop: { _, start, end in
                            self.marking = .init(song: marking.song, start: start, end: end)
                        },
                        makeLoopMarker: .skipped,
                        onDelete: {}
                    )
                }
            }
            .sheet(item: $editing) { song in
                SpeedEditorSheet(song: song) { speed in
                    save(speed, for: song)
                }
                .presentationDetents([.medium])
            }
            .focusedSceneValue(
                \.isSavedSheetOpen,
                showPicker || marking != nil || editing != nil
                    || showingListManager || addingSongsToList != nil
                    || assigning != nil || listPrompt != nil
            )
            .focusedSceneValue(\.newListAction, NewListAction { listPrompt = .create() })
            .onAppear {
                if !hasLoadedFilter {
                    hasLoadedFilter = true
                    if let restored = ListFilter(rawStorage: filterStorage) {
                        filter = restored.reconciled(with: lists)
                    }
                }
                settleGrouping()
            }
            .onChange(of: order) { settleGrouping() }
            .onChange(of: filter) { _, next in
                filterStorage = next.rawStorage
                selectedIDs.removeAll()
                settleGrouping()
            }
            .onChange(of: searchTerm) { settleGrouping() }
            .onChange(of: layout) {
                selectedIDs.removeAll()
                settleGrouping()
            }
            .onChange(of: lists) { _, updated in
                let reconciled = filter.reconciled(with: updated)
                if reconciled != filter { filter = reconciled }
                settleGrouping()
            }
            .onChange(of: showPicker) { if !showPicker { settleGrouping() } }
            .onChange(of: scenePhase) { if scenePhase == .active { settleGrouping() } }
        }
    }

    private var navigationTitle: String {
        if isBesidePractice { return "" }
        if showsFolders { return "Saved" }
        if let list = activeSingleList { return list.name }
        if filter == .unfiled { return "Unfiled" }
        return "Saved"
    }

    @ViewBuilder
    private var filteredEmptyState: some View {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            ContentUnavailableView.search(text: term)
        } else if let list = activeSingleList {
            ContentUnavailableView {
                Label("No songs in \(list.name)", systemImage: "folder")
            } description: {
                Text("Add songs from Saved or Apple Music to practice here.")
            } actions: {
                Button {
                    addingSongsToList = list
                } label: {
                    Label("Add Songs", systemImage: "plus")
                }
                .buttonStyle(CallToActionButtonStyle())
            }
        } else {
            ContentUnavailableView {
                Label("No matching songs", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No saved songs match the active filters.")
            } actions: {
                Button("Show All Songs") { filter = .all }
                    .buttonStyle(CallToActionButtonStyle())
            }
        }
    }

    private var filterBar: some View {
        ListFilterBar(
            filter: $filter,
            lists: lists,
            unfiledCount: unfiledCount,
            isBesidePractice: isBesidePractice,
            onNewList: { listPrompt = .create() },
            onRenameList: { listPrompt = .rename($0) },
            onAddSongsToList: { addingSongsToList = $0 },
            onDeleteList: { listPrompt = .delete($0) }
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: isBesidePractice ? 28 : 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .selectionDisabled()
    }

    private var selectedSongs: [SavedSong] {
        let songIDs = Set(selectedIDs.map(\.song))
        return filteredSongs.filter { songIDs.contains($0.persistentModelID) }
    }

    /// Each selected row leaves the list it's under: in Lists, a song ticked
    /// in one folder stays in its others.
    private var selectedRemovals: [(list: PracticeList, songs: [SavedSong])] {
        if let list = activeSingleList { return [(list, selectedSongs)] }
        guard showsFolders else { return [] }
        return folders.compactMap { folder in
            guard let list = folder.list else { return nil }
            let songs = folder.songs.filter {
                selectedIDs.contains(ListFolder.Row(folderID: folder.id, song: $0.persistentModelID))
            }
            return songs.isEmpty ? nil : (list, songs)
        }
    }

    @ViewBuilder
    private var selectionActions: some View {
        let selected = selectedSongs
        Button("Add to Lists\u{2026}") {
            assigning = SongSelectionBatch(songs: selected)
        }
        .disabled(selected.isEmpty)

        Spacer()

        if activeSingleList != nil || showsFolders {
            let removals = selectedRemovals
            Button("Remove") {
                for removal in removals {
                    PracticeList.remove(removal.songs, from: removal.list, in: modelContext)
                }
                endSelection()
            }
            .disabled(removals.allSatisfy(\.songs.isEmpty))
        }

        Button("Delete", role: .destructive) {
            for song in selected { delete(song) }
            endSelection()
        }
        .disabled(selected.isEmpty)
    }

    private func endSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    /// `folder` is set in Lists, where the row's list is the folder it's
    /// under rather than the filter's.
    private func row(_ song: SavedSong, in folder: ListFolder? = nil) -> some View {
        let list = folder == nil ? activeSingleList : folder?.list
        return SavedSongRow(
            song: song,
            isLoading: loadingID == song.songID,
            isCurrent: isLoaded(song),
            isPlaying: controller.isPlaying
        )
        // Concrete colours for both levels: a selected row turns `.primary`
        // and `.secondary` white for a highlight these clear rows don't
        // draw, which left the title invisible. The checkmark says it's
        // selected.
        .foregroundStyle(Color.label, Color.secondaryLabel)
        .contentShape(Rectangle())
        .onTapGesture { practice(song) }
        .contextMenu { menu(for: song, in: list) }
        // Selecting, taps fall through to the List so its own checkmarks
        // and two-finger drag pick the rows.
        .allowsHitTesting(!isSelecting)
        .accessibilityAction { practice(song) }
        .accessibilityAction(named: "Change Speed") { editing = song }
        .accessibilityAction(named: "Add Marker") { openEditor(song) }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: trailingInset))
        .alignmentGuide(.listRowSeparatorLeading) { _ in SavedSongRow.titleInset - 16 }
        .listRowBackground(Color.clear)
        .listSectionSeparator(.hidden, edges: .top)
        .tag(ListFolder.Row(folderID: folder?.id ?? "", song: song.persistentModelID))
        .swipeActions(edge: .trailing) {
            if let list {
                // Grey, not orange: orange beside coral reads as the accent,
                // and removing from a list loses nothing.
                Button {
                    PracticeList.remove([song], from: list, in: modelContext)
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                }
                .tint(.gray)
            } else {
                Button(role: .destructive) { delete(song) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Folders

    /// A button the width of the row rather than a disclosure chevron alone,
    /// so a folder opens from anywhere on its header.
    private func folderHeader(_ folder: ListFolder) -> some View {
        let isOpen = isExpanded(folder)
        return Button {
            withAnimation(.snappy) { collapsed.toggle(folder.id) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: folder.list == nil ? "tray" : "folder")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryLabel)
                    .frame(width: 22)
                Text(folder.title)
                    .font(.headline)
                    .foregroundStyle(Color.label)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(folder.songs.count)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Color.secondaryLabel)
                if !isSearching {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.tertiaryLabel)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
            }
            .textCase(nil)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isSearching)
        .contextMenu {
            if let list = folder.list {
                Button { addingSongsToList = list } label: {
                    Label("Add Songs\u{2026}", systemImage: "plus")
                }
                Button { listPrompt = .rename(list) } label: {
                    Label("Rename\u{2026}", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) { listPrompt = .delete(list) } label: {
                    Label("Delete List", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.title), \(folder.songs.count) songs")
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        .accessibilityAddTraits(.isHeader)
    }

    private func emptyFolderRow(_ list: PracticeList) -> some View {
        Button {
            addingSongsToList = list
        } label: {
            Label("Add Songs\u{2026}", systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryLabel)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 10, leading: 46, bottom: 10, trailing: trailingInset))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .selectionDisabled()
    }

    private func settleGrouping() {
        settledCount = filteredSongs.count
    }

    /// Speed and markers live here rather than as chips on the row: a glass
    /// chip and a Mark button on every song outweighed the titles.
    @ViewBuilder
    private func menu(for song: SavedSong, in list: PracticeList?) -> some View {
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
        Button { editing = song } label: { Label("Change Speed\u{2026}", systemImage: "dial.medium") }
        Button { openEditor(song) } label: { Label("Add Marker\u{2026}", systemImage: "plus.circle") }
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
        Button(role: .destructive) { delete(song) } label: { Label("Delete", systemImage: "trash") }
    }

    // MARK: - Empty

    private var emptyLabel: some View {
        Label("No saved songs yet", systemImage: "bookmark")
    }

    private var emptyDescription: some View {
        Text("Save a song to practice it again at the speed you left it.")
    }

    private var addSongButton: some View {
        Button {
            chooseSong()
        } label: {
            Label("Add Song", systemImage: "music.note.list")
        }
        .buttonStyle(CallToActionButtonStyle())
        .disabled(!controller.canUseMusic)
    }

    // MARK: - Actions

    private func chooseSong() {
        Task { showPicker = await controller.requestAuthorizationIfNeeded() }
    }

    /// `select` resets the playhead, so the jump has to come after it even
    /// when the song is already loaded.
    private func practice(_ song: SavedSong, jumpingTo marker: SongMarker? = nil) {
        loadingID = song.songID
        Task {
            defer { clearLoading(song) }
            // May be the first thing the user does after a reinstall.
            guard await controller.requestAuthorizationIfNeeded() else {
                lookupError = "Allow Apple Music access in Settings to practice this song."
                return
            }
            do {
                guard try await controller.select(saved: song) else { return }
            } catch {
                lookupError = message(for: error)
                return
            }
            if let marker { controller.jump(to: marker) }
            onPractice()
        }
    }

    private func isLoaded(_ song: SavedSong) -> Bool {
        if let selected = controller.selectedSong { return song.matches(selected) }
        return previewCurrentID == song.songID
    }

    /// The song has to reach the player first (the editor plays the passage),
    /// but the tab stays put.
    private func openEditor(_ song: SavedSong) {
        guard !isLoaded(song) else {
            present(song)
            return
        }
        loadingID = song.songID
        Task {
            defer { clearLoading(song) }
            guard await controller.requestAuthorizationIfNeeded() else {
                lookupError = "Allow Apple Music access in Settings to mark up this song."
                return
            }
            do {
                guard try await controller.select(saved: song) else { return }
            } catch {
                lookupError = message(for: error)
                return
            }
            present(song)
        }
    }

    /// A newer pick's row owns the spinner by now.
    private func clearLoading(_ song: SavedSong) {
        if loadingID == song.songID { loadingID = nil }
    }

    private func message(for error: Error) -> String {
        error is SongGoneError
            ? error.localizedDescription
            : "Couldn't find that song: \(error.localizedDescription)"
    }

    private func present(_ song: SavedSong) {
        guard controller.duration != nil else {
            lookupError = "Apple Music didn't say how long that song is, so it can't be marked up."
            return
        }
        marking = .init(song: song, start: controller.pauseForMarking())
    }

    private func save(_ speed: Double, for song: SavedSong) {
        song.speed = speed
        SavedSong.touch(song, in: modelContext)
        if let selected = controller.selectedSong, song.matches(selected) {
            controller.playbackRate = speed
        }
    }

    private func delete(_ song: SavedSong) {
        controller.delete(song, in: modelContext)
    }
}

private extension View {
    @ViewBuilder
    func conditionalSearchable(_ active: Bool, text: Binding<String>) -> some View {
        if active {
            searchable(text: text, prompt: "Search saved songs")
        } else {
            self
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

    /// Artwork plus gap; the separator lines up with it.
    nonisolated static let titleInset: CGFloat = 76

    var body: some View {
        HStack(spacing: 12) {
            SavedSongArtwork(song: song, side: 48, isLoading: isLoading)

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

            Text("\(song.percent)%")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(song.percent) percent")
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
                        savedSpeed: song.speed,
                        diameter: min(min(260, max(160, proxy.size.width - 130)), proxy.size.height)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding()
            .navigationTitle("Practice Speed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
    SavedSongsView(controller: PlaybackController()) {}
        .modelContainer(previewContainer())
}

/// The wide iPad's Saved, with Little Wing loaded in the card beside it.
#Preview("Beside the card", traits: .fixedLayout(width: 860, height: 700)) {
    SavedSongsView(controller: PlaybackController(), isBesidePractice: true, previewCurrentID: "2") {}
        .modelContainer(previewContainer())
}

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let blackbird = SavedSong.save(
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
    let acoustic = PracticeList.create(name: "Acoustic", in: context)
    let blues = PracticeList.create(name: "Blues", in: context)
    PracticeList.add([blackbird], to: acoustic, in: context)
    PracticeList.add([littleWing], to: blues, in: context)
    return container
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

/// `ContentUnavailableView` centres itself, which is where a bent foldable's
/// crease runs when it's upright: the headline sat in the fold. Bent, `above`
/// centres in the half over the crease and `below` in the half under it, the
/// one under the hand; flat, it's `whole`.
private struct AroundCrease<Whole: View, Above: View, Below: View>: View {
    @ViewBuilder var whole: Whole
    @ViewBuilder var above: Above
    @ViewBuilder var below: Below
    @State private var crease: ClosedRange<CGFloat>?

    var body: some View {
        Group {
            if let crease {
                VStack(spacing: 0) {
                    above
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: crease.lowerBound)
                    Color.clear
                        .frame(height: crease.upperBound - crease.lowerBound)
                    below
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                whole
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onGeometryChange(for: ClosedRange<CGFloat>?.self) { proxy in
            #if os(iOS)
            guard #available(iOS 27.1, *),
                  let crease = proxy.reservedRegions(kind: .division).first(where: {
                      $0.isActive && $0.frame.width > $0.frame.height
                          && $0.frame.minY > 0 && $0.frame.maxY < proxy.size.height
                  })?.frame
            else { return nil }
            return crease.minY...crease.maxY
            #else
            return nil
            #endif
        } action: { crease = $0 }
    }
}
