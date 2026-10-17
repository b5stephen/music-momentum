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
            RootTabView(sampleTrack: SampleSong.isRequested ? SampleSong.track : nil)
            #else
            RootTabView()
            #endif
        }
        .modelContainer(container)
    }
}
