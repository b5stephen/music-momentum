//
//  MiniPlayerSwitch.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

/// Swaps the main window and the mini player: opening the mini player hides
/// the main window, and going back closes the mini player and brings it
/// forward again. The main window is hidden, not closed, so Practice (and the
/// cover colours it samples) stays alive while the mini player plays.
@MainActor
@Observable
final class MiniPlayerSwitch {
    static let miniID = "mini-player"
    static let mainID = "main"

    private(set) var isMiniOpen = false
    /// Set by `MacWindow`; weak, so a window the user closed isn't kept alive.
    @ObservationIgnored weak var mainWindow: NSWindow?

    func toggle(open: OpenWindowAction, dismiss: DismissWindowAction) {
        if isMiniOpen {
            dismiss(id: Self.miniID)
            showMain(open: open)
        } else {
            open(id: Self.miniID)
            mainWindow?.orderOut(nil)
        }
    }

    /// Brings the main window forward, opening a new one if the user closed it.
    func showMain(open: OpenWindowAction) {
        NSApp.activate()
        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            open(id: Self.mainID)
        }
    }

    func miniAppeared() {
        isMiniOpen = true
    }

    /// However the mini player went away (its own button, ⌥⌘M, ⌘W), the main
    /// window it hid comes back, so closing it never leaves the app with no
    /// window.
    func miniDisappeared() {
        isMiniOpen = false
        if let mainWindow, !mainWindow.isVisible, !mainWindow.isMiniaturized {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }
}
#endif
