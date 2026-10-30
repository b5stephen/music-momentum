//
//  TimelinePanInput.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

extension View {
    /// Reports two-finger horizontal swipes over the view, in points, when
    /// `isEnabled`. Vertical scrolls, and everything while disabled, pass
    /// through so the page still scrolls.
    func timelinePan(isEnabled: Bool, onPan: @escaping (CGFloat) -> Void) -> some View {
        modifier(TimelinePanInput(isEnabled: isEnabled, onPan: onPan))
    }
}

/// Like `SpeedDragInput`'s scroll wheel, SwiftUI having none: scrolls are
/// read off the window's event stream while the pointer is over the view.
/// Unlike it, only a swipe that is mostly horizontal is taken, and its
/// momentum is kept so a flick coasts.
private struct TimelinePanInput: ViewModifier {
    let isEnabled: Bool
    let onPan: (CGFloat) -> Void

    /// The monitor outlives the body that installed it, so it reads the
    /// latest values from here rather than from a stale copy of `self`.
    private final class Latest {
        var isEnabled = false
        var isHovering = false
        var onPan: (CGFloat) -> Void = { _ in }
    }

    @State private var latest = Latest()
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        latest.isEnabled = isEnabled
        latest.onPan = onPan
        return content
            .onHover { latest.isHovering = $0 }
            .onAppear {
                let latest = latest
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    let handled = MainActor.assumeIsolated { Self.handle(event, latest) }
                    return handled ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    private static func handle(_ event: NSEvent, _ latest: Latest) -> Bool {
        guard latest.isEnabled, latest.isHovering else { return false }
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return false }
        // A mouse wheel reports lines, not points.
        let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        latest.onPan(event.scrollingDeltaX * scale)
        return true
    }
}
#endif
