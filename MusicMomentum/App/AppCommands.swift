//
//  AppCommands.swift
//  MusicMomentum
//

import SwiftUI

/// The menus: the Mac's menu bar, and iPadOS's, plus the shortcuts any
/// hardware keyboard on iOS gets. Their state comes from the focused scene's
/// `PracticeActions` and `WindowActions`, or the mini player's while it's
/// open, so with no window (or a sheet up) they grey out.
///
/// Single keys (Space, the arrows, L, M, 1-9) are plain menu key equivalents, not
/// `.onKeyPress`, so they work wherever focus is and Space never presses a
/// focused button. On the Mac the menu sees a key before a text field does,
/// so `TextFieldFocus` hands them to a field being edited; UIKit gives a text
/// field its keys first by itself. The sheets are shut out separately: an
/// item is disabled while one is up.
///
/// Not here, because SwiftUI already supplies it: Show Sidebar (⌃⌘S) in View.
struct AppCommands: Commands {
    @FocusedValue(\.practiceActions) private var focusedPractice
    @FocusedValue(\.windowActions) private var window
    @FocusedValue(\.isSavedSheetOpen) private var isSavedSheetOpen
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    let miniPlayer: MiniPlayerSwitch
    #endif

    /// The mini player is borderless, and a borderless window is never key,
    /// so it never has focused values: while it's open, its actions stand in.
    private var practice: PracticeActions? {
        #if os(macOS)
        focusedPractice ?? (miniPlayer.isMiniOpen ? miniPlayer.actions : nil)
        #else
        focusedPractice
        #endif
    }

    private var isSheetOpen: Bool { window?.isSheetOpen == true || isSavedSheetOpen == true }

    private var canPractise: Bool {
        guard let practice else { return false }
        return practice.hasSong && !practice.isBlocked && !isSheetOpen
    }

    private var canSeek: Bool { canPractise && practice?.hasDuration == true }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Change Song\u{2026}") { window?.changeSong() }
                .keyboardShortcut("o")
                .disabled(window?.canPickSong != true || isSheetOpen)
            Button("Add Song to Saved\u{2026}") { window?.addSong() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(window?.canPickSong != true || isSheetOpen)
        }

        CommandMenu("Playback") {
            Button(practice?.isPlaying == true ? "Pause" : "Play") { practice?.playPause() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!canPractise)
            Button("Back 10 Seconds") { practice?.skip(-10) }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!canSeek)
            Button("Forward 10 Seconds") { practice?.skip(10) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!canSeek)
            Button("Restart") { practice?.restart() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!canSeek)

            Divider()

            Toggle("Loop", isOn: Binding(get: { practice?.isLoopOn == true }, set: { _ in practice?.toggleLoop() }))
                .keyboardShortcut("l", modifiers: [])
                .disabled(!canSeek)
            Menu("Loop Clip") {
                ForEach(1...9, id: \.self) { number in
                    let names = practice?.clipNames ?? []
                    Button(number <= names.count ? names[number - 1] : "Clip \(number)") { practice?.loopClip(number) }
                        .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: [])
                        .disabled(!canSeek || number > names.count)
                }
            }
            Button("Mark This Point\u{2026}") { practice?.mark() }
                .keyboardShortcut("m", modifiers: [])
                .disabled(!canSeek || practice?.canMark != true)

            Divider()

            Button("Speed Up") { practice?.stepSpeed(true) }
                .keyboardShortcut(.upArrow, modifiers: [])
                .disabled(!canPractise)
            Button("Slow Down") { practice?.stepSpeed(false) }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(!canPractise)
            Button("Save Speed") { practice?.saveSpeed() }
                .keyboardShortcut("s")
                .disabled(!canPractise || practice?.canSaveSpeed != true)
        }

        #if os(macOS)
        // Only the Mac's timeline zooms.
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Zoom Timeline In") { practice?.zoomIn() }
                .keyboardShortcut("+")
                .disabled(!canSeek || practice?.canZoomIn != true)
            Button("Zoom Timeline Out") { practice?.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!canSeek || practice?.canZoomOut != true)
            Button("Fit Timeline to Song") { practice?.zoomToFit() }
                .keyboardShortcut("0")
                .disabled(!canSeek || practice?.canZoomOut != true)
        }

        CommandGroup(after: .windowArrangement) {
            Button(miniPlayer.isMiniOpen ? "Show Main Window" : "Mini Player") {
                miniPlayer.toggle(open: openWindow, dismiss: dismissWindow)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
            .disabled(!miniPlayer.isMiniOpen && practice?.hasSong != true)
        }
        #endif
    }
}
