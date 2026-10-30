//
//  MarkerLane.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

/// The Mac timeline's markers, above the track: points as a dot with their
/// name beside it, clips as bars with theirs inside. Where everything goes is
/// `MarkerLaneLayout`'s job; this draws it and reports clicks.
///
/// Clicks are told apart from ⌘-clicks here, since a SwiftUI `Button` doesn't
/// say which modifiers were down.
struct MarkerLane: View {
    let markers: [PlaybackScrubber.Marker]
    let duration: TimeInterval
    /// Defaults to the whole song.
    var visible: ClosedRange<TimeInterval>?
    /// What a click on a clip does depends on it: with looping off a click
    /// can only jump.
    var isLoopOn = false
    var onClip: (PlaybackScrubber.Marker, _ chaining: Bool) -> Void = { _, _ in }
    var onPoint: (PlaybackScrubber.Marker) -> Void = { _ in }

    @Environment(\.onAccent) private var onAccent
    @Environment(\.displayScale) private var displayScale

    private static let clipFont = NSFont.systemFont(ofSize: 11, weight: .bold)

    private func layout(width: CGFloat) -> MarkerLaneLayout {
        MarkerLaneLayout(markers: markers, duration: duration, width: width, visible: visible, nameWidth: Self.textWidth)
    }

    /// The lane's height depends on its width (rows stack as it narrows), so
    /// the frame follows the measured width while the content draws from the
    /// width it is given.
    var body: some View {
        GeometryReader { proxy in
            let layout = layout(width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                Color.clear
                if markers.isEmpty {
                    emptyHint
                } else {
                    ForEach(layout.points) { point in
                        if let marker = marker(point.id) { pointView(point, marker) }
                    }
                    ForEach(layout.clips) { clip in
                        if let marker = marker(clip.id) { clipView(clip, marker, top: layout.top(ofRow: clip.row)) }
                    }
                }
            }
        }
        .modifier(LaneHeight { width in
            markers.isEmpty ? MarkerLaneLayout.height(hasPoints: false, rows: 1) : layout(width: width).height
        })
    }

    // MARK: Empty

    /// The same height as one row, so loading a song never moves Practice.
    private var emptyHint: some View {
        Text("No markers yet \u{00B7} press \(Text("M").fontWeight(.semibold)) to mark a point, or drag here to mark a clip")
            .font(.system(size: 12))
            .foregroundStyle(.primary.opacity(0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            .accessibilityElement(children: .combine)
    }

    // MARK: Points

    private func pointView(_ point: MarkerLaneLayout.Point, _ marker: PlaybackScrubber.Marker) -> some View {
        let dot: CGFloat = 8
        let padding: CGFloat = 4
        return Button {
            onPoint(marker)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(.primary)
                    .frame(width: dot, height: dot)
                    .overlay { Circle().stroke(.black.opacity(0.15), lineWidth: 2) }
                if point.showsName {
                    Text(marker.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, padding)
            .frame(height: MarkerLaneLayout.pointRowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .offset(x: point.x - dot / 2 - padding)
        .help(tooltip(marker))
        .accessibilityLabel("\(marker.name), point")
        .accessibilityValue(PlaybackScrubber.timeLabel(marker.start))
    }

    // MARK: Clips

    private func clipView(_ clip: MarkerLaneLayout.Clip, _ marker: PlaybackScrubber.Marker, top: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        return Button {
            onClip(marker, NSEvent.modifierFlags.contains(.command))
        } label: {
            ZStack(alignment: .leading) {
                if marker.isLooping {
                    shape.fill(.tint)
                } else {
                    shape.fill(.primary.opacity(0.15))
                    shape.strokeBorder(.primary.opacity(0.16), lineWidth: 1 / displayScale)
                }
                if clip.showsName {
                    Text(marker.name)
                        .font(Self.clipFont.asFont)
                        .foregroundStyle(marker.isLooping ? AnyShapeStyle(onAccent) : AnyShapeStyle(.primary))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, MarkerLaneLayout.clipNamePadding / 2)
                }
            }
            .frame(width: clip.width, height: MarkerLaneLayout.clipHeight, alignment: .leading)
            .clipShape(shape)
            .shadow(color: .black.opacity(marker.isLooping ? 0.25 : 0), radius: 7, y: 4)
            .overlay {
                // A ring in the background colour keeps a stacked clip's edge
                // readable against the one above it.
                if clip.isStacked {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.background, lineWidth: 2)
                        .padding(-2)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .offset(x: clip.x, y: top)
        .help(tooltip(marker))
        .accessibilityLabel("\(marker.name), clip\(marker.isLooping ? ", looping" : "")")
        .accessibilityValue(timeLabel(marker))
    }

    // MARK: Text

    private func marker(_ id: AnyHashable) -> PlaybackScrubber.Marker? {
        markers.first { $0.id == id }
    }

    private static func textWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: clipFont]).width)
    }

    private func timeLabel(_ marker: PlaybackScrubber.Marker) -> String {
        let start = PlaybackScrubber.timeLabel(marker.start)
        guard let end = marker.end else { return start }
        return "\(start) \u{2013} \(PlaybackScrubber.timeLabel(end))"
    }

    /// Names, times and what a click does, since a name may not fit.
    private func tooltip(_ marker: PlaybackScrubber.Marker) -> String {
        let name = marker.name.isEmpty ? "Untitled" : marker.name
        let action = marker.isClip
            ? (isLoopOn
                ? "click to loop just this clip, \u{2318}-click to add or remove"
                : "click to jump to the start")
            : "click to jump here"
        return "\(name) \u{00B7} \(timeLabel(marker)) \u{00B7} \(action)"
    }
}

/// Sizes its content to the height the layout wants for the width it is
/// offered, in the same pass: a measured width fed back through state left
/// the first frame a row tall, with stacked clips drawn over the track.
private struct LaneHeight: ViewModifier {
    let height: (CGFloat) -> CGFloat

    private struct Sizing: Layout {
        nonisolated(unsafe) let height: (CGFloat) -> CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = proposal.width ?? 0
            return CGSize(width: width, height: height(width))
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            for subview in subviews {
                subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            }
        }
    }

    func body(content: Content) -> some View {
        Sizing(height: height) { content }
    }
}

private extension NSFont {
    var asFont: Font { Font(self) }
}
#endif
