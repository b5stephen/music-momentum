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
/// Clicks are told apart from ⌘- and ⌥-clicks here, since a SwiftUI `Button`
/// doesn't say which modifiers were down. Hovering lifts an item and raises a
/// bubble over the lane; right-clicking opens its menu; double-clicking, or
/// the menu's Rename, types a new name over it.
struct MarkerLane: View {
    let markers: [PlaybackScrubber.Marker]
    let duration: TimeInterval
    /// Defaults to the whole song.
    var visible: ClosedRange<TimeInterval>?
    /// What a click on a clip does depends on it: with looping off a click
    /// can only jump.
    var isLoopOn = false
    var actions = MarkerLaneActions()
    /// Preview only: hovers this marker, or opens its rename field with
    /// `startsRenaming`, without a pointer.
    var previewHover: AnyHashable?
    var startsRenaming = false

    @Environment(\.onAccent) private var onAccent
    @Environment(\.displayScale) private var displayScale
    @State private var hovered: AnyHashable?
    @State private var renaming: AnyHashable?
    @State private var rightClicks = RightClickMonitor()

    private var shownHover: AnyHashable? { renaming == nil ? hovered ?? previewHover : nil }

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
                    if let id = shownHover, let marker = marker(id) {
                        bubble(for: marker, in: layout, width: proxy.size.width)
                    }
                    if let id = renaming ?? (startsRenaming ? markers.first?.id : nil), let marker = marker(id) {
                        renameField(for: marker, in: layout, width: proxy.size.width)
                    }
                }
            }
            .onAppear { rightClicks.start() }
            .onDisappear { rightClicks.stop() }
            .onChange(of: hovered, initial: true) { refreshMenu() }
            .onChange(of: isLoopOn) { refreshMenu() }
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
            activate(marker)
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
        .modifier(LaneItemInput(id: marker.id, hovered: $hovered, renaming: $renaming))
        .offset(x: point.x - dot / 2 - padding)
        .accessibilityLabel("\(marker.name), point")
        .accessibilityValue(PlaybackScrubber.timeLabel(marker.start))
    }

    // MARK: Clips

    private func clipView(_ clip: MarkerLaneLayout.Clip, _ marker: PlaybackScrubber.Marker, top: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        let isHovered = shownHover == marker.id
        return Button {
            activate(marker)
        } label: {
            ZStack(alignment: .leading) {
                if marker.isLooping {
                    shape.fill(.tint)
                } else {
                    shape.fill(.primary.opacity(isHovered ? 0.3 : 0.15))
                    shape.strokeBorder(.primary.opacity(isHovered ? 0.45 : 0.16), lineWidth: 1 / displayScale)
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
            .shadow(
                color: .black.opacity(isHovered ? 0.3 : marker.isLooping ? 0.25 : 0),
                radius: isHovered ? 8 : 7,
                y: isHovered ? 6 : 4
            )
            .overlay {
                // A ring in the background colour keeps a stacked clip's edge
                // readable against the one above it.
                if clip.isStacked {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.background, lineWidth: 2)
                        .padding(-2)
                }
            }
            // The lift is on the picture, not the button, so the pointer's
            // target doesn't move out from under it.
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .frame(width: clip.width, height: MarkerLaneLayout.clipHeight)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .modifier(LaneItemInput(id: marker.id, hovered: $hovered, renaming: $renaming))
        .offset(x: clip.x, y: top)
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

    // MARK: Bubble

    /// Names, times and what a click does, since a name may not fit.
    private func bubble(for marker: PlaybackScrubber.Marker, in layout: MarkerLaneLayout, width: CGFloat) -> some View {
        let (minX, maxX) = extent(of: marker.id, in: layout)
        let action = marker.isClip && isLoopOn ? "click to loop" : "click to jump"
        let leading = (minX + maxX) / 2 < width * 0.6
        return MarkerBubble(
            name: marker.name.isEmpty ? "Untitled" : marker.name,
            detail: "\(timeLabel(marker)) \u{00B7} \(action)"
        )
        .padding(leading ? .leading : .trailing, leading ? minX : width - maxX)
        .frame(width: width, alignment: leading ? .leading : .trailing)
        .alignmentGuide(.top) { $0[.bottom] + 4 }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func extent(of id: AnyHashable, in layout: MarkerLaneLayout) -> (CGFloat, CGFloat) {
        if let clip = layout.clips.first(where: { $0.id == id }) { return (clip.x, clip.x + clip.width) }
        let x = layout.points.first { $0.id == id }?.x ?? 0
        return (x - 4, x + 4)
    }

    // MARK: Rename

    /// Over the item, with its hint beside it; shifted left to keep both in
    /// the lane when the item is near the right edge.
    private func renameField(for marker: PlaybackScrubber.Marker, in layout: MarkerLaneLayout, width: CGFloat) -> some View {
        let clip = layout.clips.first { $0.id == marker.id }
        let fieldWidth = max(clip?.width ?? 0, 140)
        let (minX, _) = extent(of: marker.id, in: layout)
        let x = max(0, min(minX, width - fieldWidth - InlineNameField.hintWidth - 8))
        let y = clip.map { layout.top(ofRow: $0.row) - 1 } ?? -4
        return InlineNameField(
            initialText: marker.name,
            width: fieldWidth,
            startsFocused: startsRenaming,
            onCommit: { name in
                renaming = nil
                actions.rename(marker, name)
            },
            onCancel: { renaming = nil }
        )
        .id(marker.id)
        .offset(x: x, y: y)
    }

    // MARK: Input

    /// ⌥-click always jumps; ⌘-click chains a clip; a plain click is
    /// Practice's call, since it depends on whether looping is on.
    private func activate(_ marker: PlaybackScrubber.Marker) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.option) {
            actions.jump(marker)
        } else if marker.isClip {
            actions.clip(marker, flags.contains(.command))
        } else {
            actions.point(marker)
        }
    }

    /// Right-click, or control-click, over a hovered item. Kept pointed at
    /// whatever is hovered now and the loop's current state.
    private func refreshMenu() {
        guard let id = hovered, let marker = marker(id) else {
            rightClicks.handler = nil
            return
        }
        rightClicks.handler = { event in
            hovered = nil
            MarkerContextMenu.popUp(menuEntries(for: marker), with: event)
        }
    }

    private func menuEntries(for marker: PlaybackScrubber.Marker) -> [MarkerContextMenu.Entry] {
        var entries: [MarkerContextMenu.Entry] = []
        if marker.isClip {
            entries.append(.item("Loop This Clip", hint: "Click", isEnabled: isLoopOn) { actions.clip(marker, false) })
            entries.append(.item(
                marker.isLooping && isLoopOn ? "Remove from Loop" : "Add to Loop",
                hint: "\u{2318} Click",
                isEnabled: isLoopOn
            ) { actions.clip(marker, true) })
        }
        entries.append(.item("Jump to Start", hint: "\u{2325} Click") { actions.jump(marker) })
        entries.append(.separator)
        entries.append(.item("Rename", hint: "Double-click") { renaming = marker.id })
        entries.append(.item("Edit Times\u{2026}") { actions.editTimes(marker) })
        if marker.isClip {
            entries.append(.item("Make a Point") { actions.makePoint(marker) })
        }
        entries.append(.separator)
        entries.append(.item("Delete", hint: "\u{232B}") { actions.delete(marker) })
        return entries
    }
}

/// Hover and double-click, the same on a point and a clip.
private struct LaneItemInput: ViewModifier {
    let id: AnyHashable
    @Binding var hovered: AnyHashable?
    @Binding var renaming: AnyHashable?

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    hovered = id
                } else if hovered == id {
                    hovered = nil
                }
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded { renaming = id })
    }
}

/// SwiftUI has no right-click event, so one monitor watches for it and hands
/// it to whatever the lane has hovered.
@MainActor
private final class RightClickMonitor {
    var handler: ((NSEvent) -> Void)?
    private var token: Any?

    func start() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            let isContextClick = event.type == .rightMouseDown || event.modifierFlags.contains(.control)
            guard isContextClick, let handler = self?.handler else { return event }
            handler(event)
            return nil
        }
    }

    func stop() {
        token.map(NSEvent.removeMonitor)
        token = nil
        handler = nil
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

private let previewMarkers: [PlaybackScrubber.Marker] = [
    .init(id: "Chorus", name: "Chorus", start: 62, end: 96),
    .init(id: "Bridge", name: "Bridge", start: 128, end: nil),
    .init(id: "Solo", name: "Solo", start: 142, end: 180),
]

@MainActor
private func lanePreview(
    hover: AnyHashable? = nil, renames: Bool = false, isLoopOn: Bool = true
) -> some View {
    MarkerLane(
        markers: previewMarkers, duration: 258, isLoopOn: isLoopOn,
        previewHover: hover, startsRenaming: renames
    )
    .padding(.top, 56)
    .padding(.horizontal, 24)
    .padding(.bottom, 40)
    .frame(width: 680)
    .modifier(ArtworkGround(palette: ArtworkPalette(cover: OKLCH(red: 0.18, green: 0.42, blue: 0.45)), isPlaying: false))
}

#Preview("Lane, hovering a clip", traits: .fixedLayout(width: 680, height: 150)) {
    lanePreview(hover: "Chorus")
}

#Preview("Lane, hovering a point, loop off", traits: .fixedLayout(width: 680, height: 150)) {
    lanePreview(hover: "Bridge", isLoopOn: false)
}

#Preview("Lane, renaming", traits: .fixedLayout(width: 680, height: 150)) {
    lanePreview(renames: true)
}
#endif
