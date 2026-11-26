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
    #else
    @UIApplicationDelegateAdaptor private var keyCommandPriority: KeyCommandPriority
    #endif
    #if DEBUG
    @AppStorage(SampleSong.loadedKey) private var sampleSongID = SampleSong.tracks[0].id
    #endif

    init() {
        let container: ModelContainer
        #if DEBUG
        if Self.isRunningForPreviews {
            container = try! AppSchema.inMemoryContainer()
        } else if SampleSong.isRequested {
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

    /// A Mac preview launches the whole app, windows and all, beside the
    /// `#Preview`, and one of the app's lists crashed SwiftUI on every
    /// preview, even on an empty store. So under previews the app's windows
    /// stay empty and the store is in memory, never the iCloud one.
    private static let isRunningForPreviews =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    @ViewBuilder
    private func unlessPreviewing(@ViewBuilder _ content: () -> some View) -> some View {
        if !Self.isRunningForPreviews { content() }
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
            unlessPreviewing {
                RootTabView(sampleTrack: sampleTrack, controller: model.controller, practicePalette: $palette)
                    #if os(macOS)
                    .environment(miniPlayer)
                    #endif
            }
        }
        .modelContainer(container)
        #if os(macOS)
        // Wide enough to show Saved as a sidebar beside Practice.
        .defaultSize(width: 1180, height: 820)
        .commands { AppCommands(miniPlayer: miniPlayer) }
        #else
        .commands { AppCommands() }
        #endif

        #if os(macOS)
        // About 450 by 120, so the window is the card: no title bar, not
        // resizable, and above other apps' windows, for playing along beside
        // a DAW or a tab app. Its own menu item is removed for ⌥⌘M's, which
        // also hides the main window.
        Window("Mini Player", id: MiniPlayerSwitch.miniID) {
            unlessPreviewing {
                NowPlaying(controller: model.controller, palette: palette, sampleTrack: sampleTrack) { track in
                    MiniPlayerView(controller: model.controller, track: track)
                }
                .environment(miniPlayer)
                .modelContainer(container)
            }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commandsRemoved()

        MenuBarExtra {
            unlessPreviewing {
                NowPlaying(controller: model.controller, palette: palette, sampleTrack: sampleTrack) { track in
                    MenuBarPanel(controller: model.controller, track: track)
                }
                .environment(miniPlayer)
                .modelContainer(container)
            }
        } label: {
            Image(nsImage: TempoRingGlyph.menuBarImage)
                .accessibilityLabel("Music Momentum")
        }
        .menuBarExtraStyle(.window)

        Window("Manage Saved Songs", id: ManageSavedSongsView.windowID) {
            unlessPreviewing {
                ManageSavedSongsView(controller: model.controller, previewCurrentID: sampleTrack?.id)
                    .environment(miniPlayer)
                    .modelContainer(container)
            }
        }
        .defaultSize(width: 980, height: 640)
        .defaultLaunchBehavior(.suppressed)
        #endif
    }
}
