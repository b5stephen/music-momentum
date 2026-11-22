//
//  ABEndKey.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit

/// B as a second Set Loop End key, without a menu item of its own: SwiftUI
/// can't hide a menu item and keep its key, and a second item listed Set
/// Loop End twice. `AppCommands` sets the action while A waits, from the same
/// focused state its menu uses, so B follows A's item, mini player included.
@MainActor
enum ABEndKey {
    static var action: (@MainActor () -> Void)?
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let action,
                  event.modifierFlags.isDisjoint(with: [.command, .control, .option]),
                  event.charactersIgnoringModifiers?.lowercased() == "b",
                  !(event.window?.firstResponder is NSText)
            else { return event }
            action()
            return nil
        }
    }
}
#endif
