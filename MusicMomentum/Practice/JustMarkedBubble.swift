//
//  JustMarkedBubble.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// The Mac's stand-in for the iPhone's naming toast: the new marker's name
/// and time over its dot, and what can be done next as buttons that show
/// their keys, so a mouse can click them and the keys are learnt in passing.
struct JustMarkedBubble: View {
    var name: String
    var time: String
    var onName: () -> Void
    var onEdit: () -> Void
    var onUndo: () -> Void
    /// The pointer is over it, so the timeout should wait.
    var onHover: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(Text(name).bold().foregroundStyle(.white)) \u{00B7} \(time)")
                .monospacedDigit()
                .padding(.trailing, 2)
            action("Name", key: "\u{21A9}", help: "Name it in place (Return)", perform: onName)
            action("Edit\u{2026}", key: "\u{2325}\u{21A9}", help: "Open Edit Marker (\u{2325}Return)", perform: onEdit)
            action("Undo", key: "\u{2318}Z", help: "Take the marker back (\u{2318}Z)", perform: onUndo)
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.8))
        .lineLimit(1)
        .fixedSize()
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 30 / 255, green: 34 / 255, blue: 36 / 255).opacity(0.96))
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
        }
        .environment(\.colorScheme, .dark)
        .onHover(perform: onHover)
    }

    private func action(_ title: String, key: String, help: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 5) {
                Text(title).foregroundStyle(.white)
                Text(key).foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(.white.opacity(0.12), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview("Just marked", traits: .fixedLayout(width: 460, height: 90)) {
    JustMarkedBubble(name: "Marker 7", time: "2:20.1", onName: {}, onEdit: {}, onUndo: {})
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 9 / 255, green: 21 / 255, blue: 23 / 255))
}
#endif
