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
    var isPlaying: Bool
    var onPick: (String) -> Void
    var onEdit: () -> Void
    var onUndo: () -> Void
    var onTimeout: () -> Void
    /// Stands in for VoiceOver in previews, which can't turn it on.
    var assumesVoiceOver = false

    static let duration: Duration = .seconds(6)

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning
    @State private var remaining = 1.0

    private static let cornerRadius: CGFloat = 26
    private static let smoke = Color(red: 20 / 255, green: 36 / 255, blue: 44 / 255).opacity(0.94)

    private var voiceOverOn: Bool { voiceOverRunning || assumesVoiceOver }
    private var title: String { "\(name) saved at \(time)" }
    private var subtitle: String {
        (isPlaying ? "Still playing" : "Paused") + " · pick a name, or carry on"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                Spacer(minLength: 8)
                Button("Undo", action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                    .accessibilityLabel("Undo mark")
            }

            FlowLayout(spacing: 8) {
                ForEach(Array(suggestions.enumerated()), id: \.element) { index, suggestion in
                    chip(suggestion, emphasised: index == 0) { onPick(suggestion) }
                        .accessibilityLabel("Name it \(suggestion)")
                }
                editChip
            }
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 16, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if !voiceOverOn {
                ZStack(alignment: .leading) {
                    Rectangle().fill(.primary.opacity(0.12))
                    Rectangle()
                        .fill(.primary.opacity(0.55))
                        .scaleEffect(x: remaining, anchor: .leading)
                }
                .frame(height: 3)
                .accessibilityHidden(true)
            }
        }
        .background(Self.smoke)
        .clipShape(.rect(cornerRadius: Self.cornerRadius))
        .overlay { RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(.primary.opacity(0.18), lineWidth: 1) }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 12)
        .environment(\.colorScheme, .dark)
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

    private func chip(_ title: String, emphasised: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(.primary.opacity(emphasised ? 0.22 : 0.12), in: .capsule)
                .overlay { Capsule().strokeBorder(.primary.opacity(emphasised ? 0.45 : 0.2), lineWidth: 1) }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var editChip: some View {
        Button(action: onEdit) {
            Label("Edit…", systemImage: "pencil")
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .overlay { Capsule().strokeBorder(.primary.opacity(0.2), lineWidth: 1) }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit marker")
    }
}

/// Left-aligned rows that wrap, as the chips do on the design board.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(in: bounds.width, subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in width: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty { rows.append(Row()) }
            let last = rows.count - 1
            rows[last].width = rows[last].indices.isEmpty ? size.width : rows[last].width + spacing + size.width
            rows[last].height = max(rows[last].height, size.height)
            rows[last].indices.append(index)
        }
        return rows
    }
}

#Preview("Typical", traits: .fixedLayout(width: 402, height: 240)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"])
}

#Preview("Long name, narrow", traits: .fixedLayout(width: 375, height: 240)) {
    toastPreview(name: "Don't Dream It's Over, the long middle eight", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"])
}

#Preview("Over a bright cover", traits: .fixedLayout(width: 402, height: 240)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"], ground: Color(red: 0.88, green: 0.64, blue: 0.05).opacity(0.85))
}

#Preview("VoiceOver, no countdown", traits: .fixedLayout(width: 402, height: 240)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"], voiceOver: true)
}

#Preview("Paused", traits: .fixedLayout(width: 402, height: 240)) {
    toastPreview(name: "Marker 7", suggestions: ["Chorus 2", "Verse", "Bridge", "Solo", "Pre-chorus"], isPlaying: false)
}

private func toastPreview(
    name: String,
    suggestions: [String],
    ground: Color = Color(red: 0.2, green: 0.07, blue: 0.07),
    voiceOver: Bool = false,
    isPlaying: Bool = true
) -> some View {
    MarkToast(
        name: name,
        time: "2:20.1",
        suggestions: suggestions,
        isPlaying: isPlaying,
        onPick: { _ in }, onEdit: {}, onUndo: {}, onTimeout: {},
        assumesVoiceOver: voiceOver
    )
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ground)
    .environment(\.colorScheme, .dark)
}
#endif
