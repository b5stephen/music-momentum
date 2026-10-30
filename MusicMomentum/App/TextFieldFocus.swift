//
//  TextFieldFocus.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit

/// Keeps the main window's text fields from holding on to the keyboard, so
/// the Playback menu's single keys work, and gives them those keys while
/// they're being edited.
@MainActor
enum TextFieldFocus {
    private static var monitors: [Any] = []
    /// Windows already opened, whose focus is now the user's to keep.
    private static var settled: Set<ObjectIdentifier> = []

    private static let characters: Set<String> = [" ", "l", "m", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    /// ←, →, ↓, ↑.
    private static let arrows: Set<UInt16> = [123, 124, 125, 126]

    static func install() {
        guard monitors.isEmpty else { return }

        // AppKit offers every key to the menu before the first responder, so
        // without this ← in the sidebar search moved the playhead instead of
        // the caret. Only these keys: Return and Escape must still reach a
        // sheet's Open and Cancel while its search is focused.
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.isDisjoint(with: [.command, .control, .option]),
                  isPlaybackKey(event),
                  let window = event.window,
                  window.firstResponder is NSText
            else { return event }
            // Straight to the window, which gives it to the field editor,
            // skipping the application's pass through the menu.
            window.sendEvent(event)
            return nil
        } as Any)

        // Most of the window is SwiftUI views that never take focus, so a
        // click on Practice left the search field editing.
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if let window = event.window,
               let editor = window.firstResponder as? NSTextView, editor.isFieldEditor,
               let field = editor.delegate as? NSView,
               !field.convert(field.bounds, to: nil).contains(event.locationInWindow) {
                window.makeFirstResponder(nil)
            }
            return event
        } as Any)

        // AppKit focuses the sidebar search when the window first opens. A
        // sheet's search keeps it, since typing is why the sheet is up.
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow else { return }
            MainActor.assumeIsolated { unfocusOnOpening(window) }
        }
        // The window that called this may already be key.
        if let window = NSApp.keyWindow { unfocusOnOpening(window) }
    }

    private static func unfocusOnOpening(_ window: NSWindow) {
        guard window.sheetParent == nil, settled.insert(ObjectIdentifier(window)).inserted else { return }
        // After SwiftUI has placed its initial focus.
        DispatchQueue.main.async {
            if window.firstResponder is NSText { window.makeFirstResponder(nil) }
        }
    }

    private static func isPlaybackKey(_ event: NSEvent) -> Bool {
        arrows.contains(event.keyCode)
            || characters.contains(event.charactersIgnoringModifiers?.lowercased() ?? "")
    }
}
#endif
