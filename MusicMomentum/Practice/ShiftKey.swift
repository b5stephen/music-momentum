//
//  ShiftKey.swift
//  MusicMomentum
//

#if canImport(UIKit)
import GameController
#else
import AppKit
#endif

/// Whether ⇧ is held on a hardware keyboard, for the knob's 5% snapping.
/// UIKit only reports modifiers on key and gesture events, and a SwiftUI
/// drag carries none, so on iOS the keyboard is asked directly.
@MainActor
enum ShiftKey {
    static var isDown: Bool {
        #if canImport(UIKit)
        guard let keys = GCKeyboard.coalesced?.keyboardInput else { return false }
        return keys.button(forKeyCode: .leftShift)?.isPressed == true
            || keys.button(forKeyCode: .rightShift)?.isPressed == true
        #else
        NSEvent.modifierFlags.contains(.shift)
        #endif
    }

    #if canImport(UIKit)
    /// Calls `handler` as ⇧ goes down or up, so the hover pointer snaps
    /// without the pointer having to move; `nil` stops. There's one keyboard
    /// handler, so only the knob under the pointer holds it.
    static func observe(_ handler: (@MainActor (Bool) -> Void)?) {
        guard let keys = GCKeyboard.coalesced?.keyboardInput else { return }
        guard let handler else {
            keys.keyChangedHandler = nil
            return
        }
        keys.keyChangedHandler = { _, _, code, _ in
            guard code == .leftShift || code == .rightShift else { return }
            MainActor.assumeIsolated { handler(isDown) }
        }
    }
    #endif
}
