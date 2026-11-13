//
//  PreciseTimeField.swift
//  MusicMomentum
//

import SwiftUI

/// Only writes back a time it could parse, and only once editing ends.
/// Until then `onType` hears the text, and `nil` once it's committed.
struct PreciseTimeField: View {
    @Binding var time: TimeInterval
    let range: ClosedRange<TimeInterval>
    var onFocus: () -> Void = {}
    var onType: (String?) -> Void = { _ in }

    @State private var text = ""
    @FocusState private var focused: Bool

    #if os(macOS)
    private static let size: CGFloat = 26
    #else
    private static let size: CGFloat = 32
    #endif

    var body: some View {
        TextField("0:00.0", text: $text)
            .font(.system(size: Self.size, weight: .semibold, design: .rounded).monospacedDigit())
            #if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            #else
            .textFieldStyle(.plain)
            .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                commit()
                let step: TimeInterval = press.modifiers.contains(.shift) ? 1 : 0.1
                let nudged = time + (press.key == .upArrow ? step : -step)
                time = max(range.lowerBound, min(nudged, range.upperBound))
                text = PreciseTime.format(time)
                return .handled
            }
            .help("↑ or ↓ for a tenth of a second, with ⇧ for a second")
            #endif
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { focused ? onFocus() : commit() }
            .onChange(of: text) { if focused { onType(text) } }
            .onChange(of: time, initial: true) { if !focused { text = PreciseTime.format(time) } }
            .accessibilityLabel("Time")
            .accessibilityValue(PreciseTime.format(time))
    }

    private func commit() {
        if let parsed = PreciseTime.parse(text) {
            time = max(range.lowerBound, min(parsed, range.upperBound))
        }
        text = PreciseTime.format(time)
        onType(nil)
    }
}
