//
//  WindowAccessor.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

/// Hands the `NSWindow` a view ends up in to `onWindow`, for the few things
/// SwiftUI's scenes can't say.
struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = Anchor()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class Anchor: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            if let window { onWindow?(window) }
        }
    }
}
#endif
