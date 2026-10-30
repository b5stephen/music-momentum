//
//  AppModel.swift
//  MusicMomentum
//

import CoreData
import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

/// Owns the one `PlaybackController` and what keeps running around it, so
/// every scene (the Mac's window, mini player and menu bar) shares it rather
/// than any of them owning the player. Closing a window must not stop the
/// song or end the display-sleep hold.
@MainActor
final class AppModel {
    let controller = PlaybackController()
    private var tasks: [Task<Void, Never>] = []
    #if os(macOS)
    private var displayAwake: (any NSObjectProtocol)?
    #endif

    init(context: ModelContext) {
        controller.configure(modelContext: context)
        let controller = controller

        // Duplicates and another device's library artwork only ever arrive by
        // sync, so tidying on each import is enough.
        tasks.append(Task {
            SavedSong.mergeDuplicates(in: context)
            await ArtworkRepair.run(in: context)
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                SavedSong.mergeDuplicates(in: context)
                await ArtworkRepair.run(in: context)
            }
        })

        // Hands are on the guitar, not the screen. iOS ignores this while
        // the app is in the background, so it needs no scene-phase check.
        tasks.append(Task { [weak self] in
            let playing = Observations { @MainActor in controller.isPlaying }
            for await playing in playing {
                self?.keepDisplayAwake(playing)
            }
        })
    }

    private func keepDisplayAwake(_ playing: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = playing
        #elseif os(macOS)
        if playing, displayAwake == nil {
            displayAwake = ProcessInfo.processInfo.beginActivity(options: .idleDisplaySleepDisabled, reason: "Practising")
        } else if !playing, let displayAwake {
            ProcessInfo.processInfo.endActivity(displayAwake)
            self.displayAwake = nil
        }
        #endif
    }
}
