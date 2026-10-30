//
//  SpeedDragInput.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

extension View {
    /// Lets a mouse set `speed` by dragging up or down, or by scrolling over
    /// the view, for the knob and anything else that shows the speed.
    func speedDragInput(speed: Binding<Double>, range: ClosedRange<Double>) -> some View {
        modifier(SpeedDragInput(speed: speed, range: range))
    }
}

/// Up is faster; holding ⇧ takes `SpeedInput.shiftStep` percent at a time.
/// The drag starts after a few points, so a click is left to whatever taps
/// the view.
struct SpeedDragInput: ViewModifier {
    @Binding var speed: Double
    var range: ClosedRange<Double>

    /// The speed when the drag began, or when ⇧ last went down or up, so
    /// changing gear mid-drag carries on from where the knob is.
    @State private var anchor: Double?
    @State private var anchorTravel: CGFloat = 0
    @State private var anchorShift = false
    /// Unrounded, so a slow scroll adds up rather than rounding to nothing.
    @State private var scrolled: Double?

    private var percentRange: ClosedRange<Int> {
        Int((range.lowerBound * 100).rounded())...Int((range.upperBound * 100).rounded())
    }

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in drag(travel: -value.translation.height) }
                    .onEnded { _ in anchor = nil }
            )
            .modifier(ScrollWheel(onChanged: scroll(by:), onEnded: { scrolled = nil }))
    }

    private func drag(travel: CGFloat) {
        let shift = NSEvent.modifierFlags.contains(.shift)
        if anchor == nil {
            // The first event is already a few points in; counting from
            // there keeps the speed from jumping when the drag begins.
            anchor = (speed * 100).rounded()
            anchorTravel = travel
            anchorShift = shift
        } else if shift != anchorShift, let anchor {
            self.anchor = Double(SpeedInput.dragged(from: anchor, travel: travel - anchorTravel, shift: anchorShift, in: percentRange))
            anchorTravel = travel
            anchorShift = shift
        }
        guard let anchor else { return }
        set(percent: SpeedInput.dragged(from: anchor, travel: travel - anchorTravel, shift: shift, in: percentRange))
    }

    /// Up or right is faster, in whichever direction the system's natural
    /// scrolling setting reports the fingers moving.
    private func scroll(by translation: CGSize) {
        let start = scrolled ?? (speed * 100).rounded()
        let amount = (translation.width - translation.height) / SpeedInput.pointsPerPercent
        let next = min(max(start + amount, Double(percentRange.lowerBound)), Double(percentRange.upperBound))
        scrolled = next
        set(percent: Int(next.rounded()))
    }

    private func set(percent: Int) {
        let value = Double(percent) / 100
        if value != speed { speed = value }
    }
}

/// SwiftUI on the Mac has no scroll-wheel gesture, so scrolls are read off
/// the window's event stream while the pointer is over the view, and
/// swallowed there so the page doesn't scroll as well. Deltas come in the
/// same direction as UIKit's pan translation.
private struct ScrollWheel: ViewModifier {
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void
    @State private var isHovering = false
    @State private var monitor: Any?

    /// A mouse wheel reports lines, not points.
    private static let pointsPerLine: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    let handled = MainActor.assumeIsolated { handle(event) }
                    return handled ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard isHovering else { return false }
        // Momentum after the fingers lift would fling the speed past
        // where they stopped it.
        guard event.momentumPhase.isEmpty else { return true }
        let scale = event.hasPreciseScrollingDeltas ? 1 : Self.pointsPerLine
        onChanged(CGSize(width: event.scrollingDeltaX * scale, height: event.scrollingDeltaY * scale))
        // A mouse wheel's clicks have no phase; each is a whole scroll.
        if event.phase.isEmpty || event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            onEnded()
        }
        return true
    }
}

#Preview("Speed chip") {
    @Previewable @State var speed = 0.75
    Text("\(Int((speed * 100).rounded()))%")
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .monospacedDigit()
        .padding(.horizontal, 11)
        .frame(height: 28)
        .glassEffect(.regular, in: .capsule)
        .speedDragInput(speed: $speed, range: 0.3...1.0)
        .padding()
}
#endif
