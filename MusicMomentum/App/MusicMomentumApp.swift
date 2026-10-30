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

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            RootTabView(
                sampleTrack: SampleSong.isRequested ? SampleSong.track(id: sampleSongID) : nil,
                controller: model.controller,
                practicePalette: $palette
            )
            #else
            RootTabView(controller: model.controller, practicePalette: $palette)
            #endif
        }
        .modelContainer(container)
        #if os(macOS)
        // Wide enough to show Saved as a sidebar beside Practice.
        .defaultSize(width: 1180, height: 820)
        .commands { MacCommands() }
        #endif
    }
}
