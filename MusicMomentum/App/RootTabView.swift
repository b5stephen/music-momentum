//
//  RootTabView.swift
//  MusicMomentum
//

import CoreData
import SwiftData
import SwiftUI

/// Owns the one `PlaybackController`: both tabs need it, and `TabView` keeps
/// the practice tab alive so switching away doesn't tear down playback.
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var controller = PlaybackController()
    @State private var tab: TabID = .practice

    private enum TabID {
        case practice, saved
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Practice", systemImage: "guitars", value: .practice) {
                PracticeView(controller: controller)
            }

            Tab("Saved", systemImage: "bookmark", value: .saved) {
                SavedSongsView(controller: controller) { tab = .practice }
            }
        }
        .task { controller.configure(modelContext: modelContext) }
        // Duplicates and another device's library artwork only ever arrive by
        // sync, so tidying on each import is enough.
        .task {
            SavedSong.mergeDuplicates(in: modelContext)
            await ArtworkRepair.run(in: modelContext)
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                SavedSong.mergeDuplicates(in: modelContext)
                await ArtworkRepair.run(in: modelContext)
            }
        }
        // Hands are on the guitar, not the screen. iOS ignores this while
        // the app is in the background, so it needs no scene-phase check.
        .onChange(of: controller.isPlaying, initial: true) { _, playing in
            UIApplication.shared.isIdleTimerDisabled = playing
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(try! AppSchema.inMemoryContainer())
}
