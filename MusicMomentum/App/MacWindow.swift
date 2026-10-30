//
//  MacWindow.swift
//  MusicMomentum
//

#if os(macOS)
import MusicKit
import SwiftData
import SwiftUI

/// The Mac window: Saved as a translucent sidebar beside Practice, both over
/// the cover's mesh. Below `sidebarWidth` of room the sidebar collapses and
/// slides over Practice with a dim instead of squeezing it.
struct MacWindow: View {
    let controller: PlaybackController
    /// Stands in for a loaded song; see `SampleSong`.
    var sampleTrack: PracticeView.Track?
    @Binding var palette: ArtworkPalette?

    @Environment(\.modelContext) private var modelContext
    @Environment(MiniPlayerSwitch.self) private var miniPlayer
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var isWide = true
    @State private var sidebarOver: Bool
    @State private var picking: Picking?
    /// A preview has no window to put the background in.
    private let paintsWindow: Bool

    /// Wide enough to keep Practice's own wide layout beside the sidebar.
    nonisolated static var wideWidth: CGFloat { 1180 }
    nonisolated static var minWindowSize: CGSize { CGSize(width: 720, height: 600) }
    static let sidebarWidth: CGFloat = 272

    private enum Picking: Identifiable {
        case change, add
        var id: Self { self }
    }

    init(
        controller: PlaybackController,
        sampleTrack: PracticeView.Track? = nil,
        palette: Binding<ArtworkPalette?>,
        sidebarOver: Bool = false,
        paintsWindow: Bool = true
    ) {
        self.paintsWindow = paintsWindow
        self.controller = controller
        self.sampleTrack = sampleTrack
        _palette = palette
        _sidebarOver = State(initialValue: sidebarOver)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationSplitView(columnVisibility: $columns) {
                sidebar
                    // A shade darker than the mesh behind it; with no cover
                    // colours the system's own sidebar look stands.
                    .background { if palette != nil { Color.black.opacity(0.22) } }
                    .navigationSplitViewColumnWidth(Self.sidebarWidth)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) { sidebarToggle(hide: true) }
                    }
            } detail: {
                PracticeView(
                    controller: controller,
                    previewTrack: sampleTrack,
                    savedIsBeside: true,
                    paintsGround: false
                ) { palette = $0 }
                .toolbar { toolbar }
                .toolbar(removing: .title)
            }
            // The split view's own toggle draws itself "on" while the sidebar
            // shows, filled with the window's tint, which over a cover is its
            // pale text colour: a white button beside the toolbar's glass ones.
            .toolbar(removing: .sidebarToggle)

            if sidebarOver {
                Color.black.opacity(0.32)
                    .contentShape(.rect)
                    .onTapGesture { setSidebarOver(false) }
                    .transition(.opacity)
                    .accessibilityLabel("Close sidebar")
                    .accessibilityAddTraits(.isButton)

                sidebar
                    .frame(width: Self.sidebarWidth)
                    .frame(maxHeight: .infinity)
                    .background {
                        // Over Practice it needs to be solid enough to read
                        // against: the cover's dark shade, mostly opaque.
                        if let palette {
                            Rectangle().fill(.ultraThinMaterial)
                                .overlay { palette.background.opacity(0.86) }
                        } else {
                            Rectangle().fill(.regularMaterial)
                        }
                    }
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(.primary.opacity(0.08)).frame(width: 1)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 30, x: 12)
                    .transition(.move(edge: .leading))
            }
        }
        .modifier(ArtworkGround(palette: palette, isPlaying: controller.isPlaying, paintsWindow: paintsWindow))
        .frame(minWidth: Self.minWindowSize.width, minHeight: Self.minWindowSize.height)
        .onAppear { TextFieldFocus.install() }
        .background(WindowAccessor { miniPlayer.mainWindow = $0 })
        .onGeometryChange(for: Bool.self) { $0.size.width >= Self.wideWidth } action: { wide in
            isWide = wide
            columns = wide ? .all : .detailOnly
            if wide { sidebarOver = false }
        }
        // A narrow window has no room for a column. The toolbar's toggle and
        // View > Show Sidebar both ask for one, and are answered with the
        // overlay instead.
        .onChange(of: columns) { _, columns in
            guard !isWide, columns != .detailOnly else { return }
            self.columns = .detailOnly
            setSidebarOver(!sidebarOver)
        }
        .focusedSceneValue(
            \.windowActions,
            WindowActions(
                canPickSong: controller.canUseMusic,
                isSheetOpen: picking != nil,
                changeSong: { pick(.change) },
                addSong: { pick(.add) }
            )
        )
        // Outside the ground, which would hand the sheet the cover's dark
        // scheme and light text.
        .sheet(item: $picking) { picking in
            switch picking {
            case .change:
                SongPickerView { song in
                    Task { await controller.select(song: song) }
                }
            case .add:
                SongPickerView(title: "Add Song to Saved", confirmTitle: "Add", onSelect: add)
            }
        }
    }

    private var sidebar: some View {
        SavedSidebarView(controller: controller, previewCurrentID: sampleTrack?.id) {
            pick(.add)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !isSidebarColumnShown {
            ToolbarItem(placement: .navigation) { sidebarToggle(hide: false) }
        }
        ToolbarItem(placement: .navigation) {
            Button {
                pick(.change)
            } label: {
                Label("Change Song", systemImage: "music.note")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(!controller.canUseMusic)
            .help("Change song without saving it (\u{2318}O)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                miniPlayer.toggle(open: openWindow, dismiss: dismissWindow)
            } label: {
                Label("Mini Player", systemImage: "pip")
                    .labelStyle(.iconOnly)
            }
            .disabled(sampleTrack == nil && controller.selectedSong == nil)
            .help("Mini player (\u{2325}\u{2318}M)")
        }
    }

    private var isSidebarColumnShown: Bool { isWide && columns != .detailOnly }

    /// Plain like the toolbar's other buttons, so it's the same glass.
    private func sidebarToggle(hide: Bool) -> some View {
        Button {
            if isWide {
                withAnimation { columns = hide ? .detailOnly : .all }
            } else {
                setSidebarOver(!sidebarOver)
            }
        } label: {
            Label(hide ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
                .labelStyle(.iconOnly)
        }
        .help(hide ? "Hide sidebar (\u{2303}\u{2318}S)" : "Show sidebar (\u{2303}\u{2318}S)")
    }

    private func setSidebarOver(_ over: Bool) {
        withAnimation(.snappy(duration: 0.25)) { sidebarOver = over }
    }

    private func pick(_ picking: Picking) {
        Task {
            if await controller.requestAuthorizationIfNeeded() { self.picking = picking }
        }
    }

    /// Re-adding a song keeps its tuned speed rather than resetting to 100%.
    /// It doesn't load the song: that's Change Song's job.
    private func add(_ song: Song) {
        if let existing = SavedSong.find(song: song, in: modelContext) {
            SavedSong.touch(existing, in: modelContext)
        } else {
            SavedSong.save(song: song, speed: 1.0, in: modelContext)
        }
    }
}

// MARK: - Previews

private let previewPalette = ArtworkPalette(cover: OKLCH(red: 0.18, green: 0.42, blue: 0.45))

private let previewTrack = PracticeView.Track(
    id: "2", title: "Slow Burn Avenue", artistName: "The Kettle Lines",
    palette: previewPalette
)

@MainActor
private func previewWindow(
    track: PracticeView.Track?,
    sidebarOver: Bool = false
) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    SavedSong.save(songID: "1", title: "Harbour Lights", artistName: "Mara Ellis", artworkData: nil, speed: 0.75, in: context)
    SavedSong.save(songID: "2", title: "Slow Burn Avenue", artistName: "The Kettle Lines", artworkData: nil, speed: 0.6, in: context)
    SavedSong.save(songID: "3", title: "Paper Moons", artistName: "June Okafor", artworkData: nil, speed: 0.8, in: context)
    SavedSong.save(songID: "4", title: "Night Ferry", artistName: "Low Tide Club", artworkData: nil, speed: 0.7, in: context)
    SavedSong.save(songID: "5", title: "Copper Wire", artistName: "Ada & the Static", artworkData: nil, speed: 0.65, in: context)
    let controller = PlaybackController()
    controller.playbackRate = 0.6
    return PreviewWindow(controller: controller, track: track, sidebarOver: sidebarOver)
        .environment(MiniPlayerSwitch())
        .modelContainer(container)
}

private struct PreviewWindow: View {
    let controller: PlaybackController
    let track: PracticeView.Track?
    let sidebarOver: Bool
    @State private var palette: ArtworkPalette?

    init(controller: PlaybackController, track: PracticeView.Track?, sidebarOver: Bool) {
        self.controller = controller
        self.track = track
        self.sidebarOver = sidebarOver
        _palette = State(initialValue: track?.palette)
    }

    var body: some View {
        MacWindow(
            controller: controller, sampleTrack: track, palette: $palette,
            sidebarOver: sidebarOver, paintsWindow: false
        )
    }
}

#Preview("Wide window", traits: .fixedLayout(width: 1280, height: 820)) {
    previewWindow(track: previewTrack)
}

#Preview("Compact window", traits: .fixedLayout(width: 900, height: 700)) {
    previewWindow(track: previewTrack)
}

#Preview("Compact, sidebar over", traits: .fixedLayout(width: 900, height: 700)) {
    previewWindow(track: previewTrack, sidebarOver: true)
}

#Preview("No song", traits: .fixedLayout(width: 1280, height: 820)) {
    previewWindow(track: nil)
}
#endif
