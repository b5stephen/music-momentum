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

    private static let characters: Set<String> = [" ", "a", "l", "m", "s", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    /// ←, →, ↓, ↑.
    private static let arrows: Set<UInt16> = [123, 124, 125, 126]
    /// Return and the keypad's Enter.
    private static let returns: Set<UInt16> = [36, 76]
    /// Escape, which Discard A–B Loop also answers.
    private static let escape: UInt16 = 53

    static func install() {
        guard monitors.isEmpty else { return }

        // AppKit offers every key to the menu before the first responder, so
        // without this ← in the sidebar search moved the playhead instead of
        // the caret. Return is the Markers menu's Rename, so a field gets it
        // too or it could never submit; but not in a sheet, whose Return is
        // Open and whose menus are off. Escape is Discard A–B Loop's, so a
        // field gets that too, to cancel its edit.
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌥↑ and ⌥↓ change the speed by 1%, and in a field move the caret;
            // ⌥Return is Edit Marker Times.
            let option = event.modifierFlags.contains(.option)
            guard event.modifierFlags.isDisjoint(with: [.command, .control]),
                  option ? arrows.contains(event.keyCode) || returns.contains(event.keyCode) : isPlaybackKey(event),
                  let window = event.window,
                  window.firstResponder is NSText,
                  !returns.contains(event.keyCode) || window.sheetParent == nil
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
            || returns.contains(event.keyCode)
            || event.keyCode == escape
            || characters.contains(event.charactersIgnoringModifiers?.lowercased() ?? "")
    }
}
#endif
