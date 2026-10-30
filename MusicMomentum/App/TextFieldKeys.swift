//
//  TextFieldKeys.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit

/// Hands the Playback menu's single keys (Space, the four arrows, L, M, 1-9) to a
/// text field that's being edited. AppKit offers every key to the menu before
/// the first responder, so without this ← in the sidebar search moved the
/// playhead instead of the caret. Only those keys: Return and Escape must
/// still reach a sheet's Open and Cancel while its search is focused.
enum TextFieldKeys {
    private static var monitor: Any?

    private static let characters: Set<String> = [" ", "l", "m", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    /// ←, →, ↓, ↑.
    private static let arrows: Set<UInt16> = [123, 124, 125, 126]

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.isDisjoint(with: [.command, .control, .option]),
                  isPlaybackKey(event),
                  let window = event.window,
                  window.firstResponder is NSText
            else { return event }
            // Straight to the window, which gives it to the field editor,
            // skipping the application's pass through the menu.
            window.sendEvent(event)
            return nil
        }
    }

    private static func isPlaybackKey(_ event: NSEvent) -> Bool {
        arrows.contains(event.keyCode)
            || characters.contains(event.charactersIgnoringModifiers?.lowercased() ?? "")
    }
}
#endif
