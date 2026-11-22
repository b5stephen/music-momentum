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
/// Single keys (Space, the arrows, Return, Esc, A, L, M, ⇧M, S, 1-9) are plain menu key equivalents, not
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

        CommandGroup(replacing: .saveItem) {
            Button(practice?.saveTitle ?? "Save Speed") {
                if practice?.canSaveSpeed == true { practice?.saveSpeed() }
                if practice?.canSaveLoop == true { practice?.saveLoop() }
            }
            .keyboardShortcut("s")
            .disabled(!canPractise || (practice?.canSaveSpeed != true && practice?.canSaveLoop != true))
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
        }

        CommandMenu("Markers") {
            Button("Mark") { practice?.mark() }
                .keyboardShortcut("m", modifiers: [])
                .disabled(!canSeek || practice?.canMark != true)
            Button("Mark and Edit\u{2026}") { practice?.markAndEdit() }
                .keyboardShortcut("m", modifiers: .shift)
                .disabled(!canSeek || practice?.canMark != true)

            Divider()

            // One key walks A·B through its steps, as the button does. B also
            // ends a loop, for anyone who reaches for B after A, but stays out
            // of the menu, where it would list Set Loop End twice; with no A
            // set it would be a second way to start one, under the wrong letter.
            Button(practice?.abStep?.title ?? "Set Loop Start") { practice?.pressAB() }
                .keyboardShortcut("a", modifiers: [])
                .disabled(!canSeek || practice?.abStep == nil)
            #if os(iOS)
            // `KeyCommandPriority` hides it.
            Button(PracticeActions.ABStep.setEnd.title) { practice?.pressAB() }
                .keyboardShortcut("b", modifiers: [])
                .disabled(!canSeek || practice?.abStep != .setEnd)
            #else
            let _ = ABEndKey.action = canSeek && practice?.abStep == .setEnd ? practice?.pressAB : nil
            #endif
            Button("Discard A\u{2013}B Loop") { practice?.discardAB() }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!canSeek || practice?.canDiscardAB != true)
            #if os(macOS)
            Divider()
            Button("Rename Marker\u{2026}") { practice?.renameMarker() }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!canSeek || practice?.canMark != true || practice?.canRenameMarker != true)
            Button("Edit Marker Times\u{2026}") { practice?.editMarkerTimes() }
                .keyboardShortcut(.return, modifiers: .option)
                .disabled(!canSeek || practice?.canMark != true || practice?.canRenameMarker != true)
            #endif

            Divider()

            Menu("Saved Loops") {
                let names = practice?.clipNames ?? []
                if names.isEmpty {
                    Button("No Saved Loops") {}.disabled(true)
                } else {
                    ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                        Button(name) { practice?.loopClip(index + 1) }
                            // Only 1–9 have keys; Character("10") would trap.
                            .keyboardShortcut(index < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: []) : nil)
                            .disabled(!canSeek)
                    }
                }
            }
        }

        CommandMenu("Speed") {
            Button("Speed Up") { practice?.stepSpeed(true) }
                .keyboardShortcut(.upArrow, modifiers: [])
                .disabled(!canPractise)
            Button("Slow Down") { practice?.stepSpeed(false) }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(!canPractise)
            Button("Speed Up 1%") { practice?.nudgeSpeed(true) }
                .keyboardShortcut(.upArrow, modifiers: .option)
                .disabled(!canPractise)
            Button("Slow Down 1%") { practice?.nudgeSpeed(false) }
                .keyboardShortcut(.downArrow, modifiers: .option)
                .disabled(!canPractise)
            Button("Set Speed\u{2026}") { practice?.editSpeed() }
                .keyboardShortcut("s", modifiers: [])
                .disabled(!canPractise || practice?.canEditSpeed != true)

            Divider()

            SpeedPresetItems(percent: practice?.speedPercent ?? 100, savedPercent: practice?.savedSpeedPercent) {
                practice?.setSpeed($0)
            }
            .disabled(!canPractise)
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
