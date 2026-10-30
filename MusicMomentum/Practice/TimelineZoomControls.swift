//
//  TimelineZoomControls.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// − / Fit / + in one glass capsule, in the timeline's header. Quiet: a
/// button that can't do anything is dimmed rather than hidden, so the
/// capsule keeps its width.
struct TimelineZoomControls: View {
    let viewport: TimelineViewport
    let duration: TimeInterval
    var zoomOut: () -> Void
    var fit: () -> Void
    var zoomIn: () -> Void

    static let height: CGFloat = 30

    var body: some View {
        let isZoomed = viewport.isZoomed
        HStack(spacing: 0) {
            button("minus", label: "Zoom out", enabled: isZoomed, action: zoomOut)
                .frame(width: 30)
            divider
            Button(action: fit) {
                Text("Fit")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 9)
                    .frame(height: Self.height)
                    .contentShape(.rect)
                    .opacity(isZoomed ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .disabled(!isZoomed)
            .help("Fit the whole song")
            .accessibilityLabel("Fit the whole song")
            divider
            button("plus", label: "Zoom in", enabled: viewport.canZoomIn(duration: duration), action: zoomIn)
                .frame(width: 30)
        }
        .foregroundStyle(Color.primary)
        .modifier(ButtonGlass())
    }

    private var divider: some View {
        Rectangle()
            .fill(.primary.opacity(0.14))
            .frame(width: 1, height: 14)
            .accessibilityHidden(true)
    }

    private func button(_ glyph: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: glyph)
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .contentShape(.rect)
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(label)
        .accessibilityLabel(label)
    }
}

#Preview("Fitted", traits: .sizeThatFitsLayout) {
    TimelineZoomControls(viewport: TimelineViewport(), duration: 258, zoomOut: {}, fit: {}, zoomIn: {})
        .padding(24)
        .background(Color(red: 0.07, green: 0.2, blue: 0.22))
}

#Preview("Zoomed", traits: .sizeThatFitsLayout) {
    @Previewable @State var viewport = {
        var viewport = TimelineViewport()
        viewport.zoom(by: 4, around: 130, duration: 258)
        return viewport
    }()
    TimelineZoomControls(viewport: viewport, duration: 258, zoomOut: {}, fit: {}, zoomIn: {})
        .padding(24)
        .background(Color(red: 0.07, green: 0.2, blue: 0.22))
}
#endif
