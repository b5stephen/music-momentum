//
//  MacCommands.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// The Mac's menus. Their state comes from the focused window's
/// `PracticeActions` and `WindowActions`, so with no window (or a sheet up)
/// they grey out.
///
/// Single keys (Space, the arrows, L, M, 1-9) are plain menu key equivalents, not
/// `.onKeyPress`, so they work wherever focus is and Space never presses a
/// focused button. The menu sees a key before a text field does, so
/// `TextFieldFocus` hands them to a field being edited. The sheets are shut out
/// separately: an item is disabled while one is up.
///
/// Not here, because SwiftUI already supplies it: Show Sidebar (⌃⌘S) in View.
struct MacCommands: Commands {
    @FocusedValue(\.practiceActions) private var practice
    @FocusedValue(\.windowActions) private var window
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    let miniPlayer: MiniPlayerSwitch

    private var canPractise: Bool {
        guard let practice, let window else { return false }
        return practice.hasSong && !practice.isBlocked && !window.isSheetOpen
    }

    private var canSeek: Bool { canPractise && practice?.hasDuration == true }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Change Song\u{2026}") { window?.changeSong() }
                .keyboardShortcut("o")
                .disabled(window?.canPickSong != true || window?.isSheetOpen == true)
            Button("Add Song to Saved\u{2026}") { window?.addSong() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(window?.canPickSong != true || window?.isSheetOpen == true)
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
    }
}
#endif
