//
//  MarkToast.swift
//  MusicMomentum
//

#if os(iOS)
import SwiftUI

/// Offered after a quick Mark so the point can be named without stopping the
/// song. It dismisses itself after `duration` unless VoiceOver is running,
/// where a timeout would take the chips away mid-swipe.
struct MarkToast: View {
    var name: String
    var time: String
    var suggestions: [String]
    var onPick: (String) -> Void
    var onEdit: () -> Void
    var onUndo: () -> Void
    var onTimeout: () -> Void
    /// Stands in for VoiceOver in previews, which can't turn it on.
    var assumesVoiceOver = false

    static let duration: Duration = .seconds(6)

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning
    @Environment(\.smokedFill) private var smokedFill
    @State private var remaining = 1.0

    private var voiceOverOn: Bool { voiceOverRunning || assumesVoiceOver }
    private var title: String { "\(name) saved at \(time)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Still playing · tap a name")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                // Here rather than at the end of the chips, where a phone
                // scrolled it out of sight.
                headerButton("Edit…", action: onEdit)
                    .accessibilityLabel("Edit marker")
                headerButton("Undo", action: onUndo)
                    .accessibilityLabel("Undo mark")
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        chip(suggestion) { onPick(suggestion) }
                            .accessibilityLabel("Name it \(suggestion)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 10)
        }
        .environment(\.inGlassPanel, true)
        .overlay(alignment: .bottom) {
            if !voiceOverOn {
                Rectangle()
                    .fill(.primary.opacity(0.45))
                    .frame(height: 2)
                    .scaleEffect(x: remaining, anchor: .leading)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(smokedFill.map { Glass.regular.tint($0) } ?? .regular, in: .rect(cornerRadius: 28))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .task(id: voiceOverOn) {
            remaining = 1
            guard !voiceOverOn else { return }
            withAnimation(.linear(duration: Double(Self.duration.components.seconds))) { remaining = 0 }
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            onTimeout()
        }
    }

    private func headerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .modifier(ButtonGlass())
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

#Preview("Typical", traits: .fixedLayout(width: 402, height: 220)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"])
}

#Preview("Long name, narrow", traits: .fixedLayout(width: 375, height: 220)) {
    toastPreview(name: "Don't Dream It's Over, the long middle eight", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"])
}

#Preview("Over a bright cover", traits: .fixedLayout(width: 402, height: 220)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"], ground: Color(red: 0.88, green: 0.64, blue: 0.05).opacity(0.85))
}

#Preview("VoiceOver, no countdown", traits: .fixedLayout(width: 402, height: 220)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"], voiceOver: true)
}

private func toastPreview(
    name: String,
    suggestions: [String],
    ground: Color = Color(red: 0.2, green: 0.07, blue: 0.07),
    voiceOver: Bool = false
) -> some View {
    MarkToast(
        name: name,
        time: "2:20.1",
        suggestions: suggestions,
        onPick: { _ in }, onEdit: {}, onUndo: {}, onTimeout: {},
        assumesVoiceOver: voiceOver
    )
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ground)
    .environment(\.colorScheme, .dark)
}
#endif
