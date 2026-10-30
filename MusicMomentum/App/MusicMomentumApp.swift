//
//  MusicMomentumApp.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 05/09/2026.
//

import SwiftData
import SwiftUI

@main
struct MusicMomentumApp: App {
    private let container: ModelContainer
    private let model: AppModel
    @State private var palette: ArtworkPalette?
    #if os(macOS)
    @State private var miniPlayer = MiniPlayerSwitch()
    #endif
    #if DEBUG
    @AppStorage(SampleSong.loadedKey) private var sampleSongID = SampleSong.tracks[0].id
    #endif

    init() {
        let container: ModelContainer
        #if DEBUG
        if SampleSong.isRequested {
            container = try! SampleSong.container()
        } else {
            container = try! AppSchema.appContainer()
        }
        #else
        container = try! AppSchema.appContainer()
        #endif
        self.container = container
        model = AppModel(context: container.mainContext)
    }

    /// Stands in for a loaded song; see `SampleSong`.
    private var sampleTrack: PracticeView.Track? {
        #if DEBUG
        SampleSong.isRequested ? SampleSong.track(id: sampleSongID) : nil
        #else
        nil
        #endif
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootTabView(sampleTrack: sampleTrack, controller: model.controller, practicePalette: $palette)
                #if os(macOS)
                .environment(miniPlayer)
                #endif
        }
        .modelContainer(container)
        #if os(macOS)
        // Wide enough to show Saved as a sidebar beside Practice.
        .defaultSize(width: 1180, height: 820)
        .commands { MacCommands(miniPlayer: miniPlayer) }
        #endif

        #if os(macOS)
        // About 450 by 120, so the window is the card: no title bar, not
        // resizable, and above other apps' windows, for playing along beside
        // a DAW or a tab app. Its own menu item is removed for ⌥⌘M's, which
        // also hides the main window.
        Window("Mini Player", id: MiniPlayerSwitch.miniID) {
            NowPlaying(controller: model.controller, palette: palette, sampleTrack: sampleTrack) { track in
                MiniPlayerView(controller: model.controller, track: track)
            }
            .environment(miniPlayer)
            .modelContainer(container)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commandsRemoved()

        MenuBarExtra {
            NowPlaying(controller: model.controller, palette: palette, sampleTrack: sampleTrack) { track in
                MenuBarPanel(controller: model.controller, track: track)
            }
            .environment(miniPlayer)
            .modelContainer(container)
        } label: {
            Image(nsImage: TempoRingGlyph.menuBarImage)
                .accessibilityLabel("Music Momentum")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
