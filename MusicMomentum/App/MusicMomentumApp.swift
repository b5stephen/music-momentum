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
    #if DEBUG
    @AppStorage(SampleSong.loadedKey) private var sampleSongID = SampleSong.tracks[0].id
    #endif

    init() {
        #if DEBUG
        if SampleSong.isRequested {
            container = try! SampleSong.container()
            return
        }
        #endif
        container = try! AppSchema.appContainer()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            RootTabView(sampleTrack: SampleSong.isRequested ? SampleSong.track(id: sampleSongID) : nil)
            #else
            RootTabView()
            #endif
        }
        .modelContainer(container)
        #if os(macOS)
        // Wide enough to show Saved as a sidebar beside Practice.
        .defaultSize(width: 1180, height: 820)
        #endif
    }
}
