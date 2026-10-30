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
///
/// Dragging on empty lane marks a clip: a dashed ghost with its times, then a
/// name field under it. Dragging within a few points of a clip's edge trims it.
/// Neither saves anything itself; the lane reports the times and Practice
/// decides.
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
    /// Preview only: a clip mid-drag, one waiting for its name, a trim in
    /// progress.
    var previewGhost: ClipDraft?
    var previewNaming: ClipDraft?
    var previewTrim: TrimDraft?

    struct ClipDraft: Hashable {
        var start: TimeInterval
        var end: TimeInterval
    }

    struct TrimDraft: Equatable {
        let id: AnyHashable
        let edge: MarkerLaneDrag.Edge
        var start: TimeInterval
        var end: TimeInterval
    }

    @Environment(\.onAccent) private var onAccent
    @Environment(\.displayScale) private var displayScale
    @State private var hovered: AnyHashable?
    @State private var renaming: AnyHashable?
    @State private var ghost: ClipDraft?
    @State private var naming: ClipDraft?
    @State private var trim: TrimDraft?
    /// Where the edge being trimmed was when the drag began.
    @State private var trimOriginX: CGFloat = 0
    /// The edge under the pointer, for its handle.
    @State private var handle: HandleEdge?

    private struct HandleEdge: Equatable {
        let id: AnyHashable
        let edge: MarkerLaneDrag.Edge
    }

    private static let space = "markerLane"
    private static let edgeZone: CGFloat = 5

    private var shownTrim: TrimDraft? { trim ?? previewTrim }
    private var shownNaming: ClipDraft? { naming ?? previewNaming }
    private var shownGhost: ClipDraft? { ghost ?? shownNaming ?? previewGhost }
    private var shownHover: AnyHashable? {
        renaming == nil && shownTrim == nil && ghost == nil && shownNaming == nil ? hovered ?? previewHover : nil
    }

    /// The markers as drawn: the one being trimmed at its dragged bounds.
    private var shownMarkers: [PlaybackScrubber.Marker] {
        guard let trim = shownTrim else { return markers }
        return markers.map {
            $0.id == trim.id
                ? .init(id: $0.id, name: $0.name, start: trim.start, end: trim.end, isLooping: $0.isLooping)
                : $0
        }
    }

    private static let clipFont = NSFont.systemFont(ofSize: 11, weight: .bold)

    private func layout(width: CGFloat) -> MarkerLaneLayout {
        MarkerLaneLayout(markers: shownMarkers, duration: duration, width: width, visible: visible, nameWidth: Self.textWidth)
    }

    /// The lane's height depends on its width (rows stack as it narrows), so
    /// the frame follows the measured width while the content draws from the
    /// width it is given.
    var body: some View {
        GeometryReader { proxy in
            let layout = layout(width: proxy.size.width)
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(.rect)
                    .gesture(markDrag(width: width))
                if markers.isEmpty {
                    emptyHint
                        .opacity(shownGhost == nil ? 1 : 0)
                        .allowsHitTesting(false)
                } else {
                    ForEach(layout.points) { point in
                        if let marker = marker(point.id) { pointView(point, marker) }
                    }
                    ForEach(layout.clips) { clip in
                        if let marker = marker(clip.id) { clipView(clip, marker, top: layout.top(ofRow: clip.row)) }
                    }
                    ForEach(layout.clips) { clip in
                        if let marker = marker(clip.id) { trimZones(clip, marker, top: layout.top(ofRow: clip.row), width: width) }
                    }
                    if let target = shownTrim.map({ HandleEdge(id: $0.id, edge: $0.edge) }) ?? handle,
                       let clip = layout.clips.first(where: { $0.id == target.id }) {
                        handleBar(clip, edge: target.edge, top: layout.top(ofRow: clip.row))
                    }
                    if let id = shownHover, let marker = marker(id) {
                        bubble(for: marker, in: layout, width: proxy.size.width)
                    }
                    if let id = renaming ?? (startsRenaming ? markers.first?.id : nil), let marker = marker(id) {
                        renameField(for: marker, in: layout, width: proxy.size.width)
                    }
                }
                if let draft = shownGhost {
                    ghostBar(draft, top: layout.top(ofRow: 0), width: width)
                }
            }
            .coordinateSpace(.named(Self.space))
            // Overlaid, since a bubble's alignment guide, or a field hanging
            // below the lane, would otherwise resize the stack and pull
            // everything else in the lane along with it.
            .overlay(alignment: .topLeading) {
                if let draft = shownNaming {
                    nameField(for: draft, top: layout.top(ofRow: 0), width: width)
                }
            }
            .overlay(alignment: .topLeading) {
                if let trim = shownTrim {
                    trimBubble(trim, width: width)
                }
            }
            .overlay(alignment: .topLeading) {
                if shownTrim == nil, let draft = shownGhost {
                    ghostBubble(draft, width: width)
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
        .contextMenu { menu(for: marker) }
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
        .contextMenu { menu(for: marker) }
        .offset(x: clip.x, y: top)
        .accessibilityLabel("\(marker.name), clip\(marker.isLooping ? ", looping" : "")")
        .accessibilityValue(timeLabel(marker))
    }

    // MARK: Mark a clip

    /// Points to snap to: every marker's edges and the song's own, bar the
    /// clip being trimmed.
    private func snapPoints(excluding id: AnyHashable? = nil) -> [TimeInterval] {
        markers.filter { $0.id != id }.flatMap { [$0.start, $0.end].compactMap(\.self) } + [0, duration]
    }

    private var isFine: Bool { NSEvent.modifierFlags.contains(.option) }

    private func markDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                naming = nil
                ghost = MarkerLaneDrag.clip(
                    from: value.startLocation.x, to: value.location.x,
                    width: width, duration: duration, fine: isFine, snapTo: snapPoints()
                ).map { ClipDraft(start: $0.start, end: $0.end) }
            }
            .onEnded { _ in
                // Too short to be a clip leaves no ghost, so nothing to name.
                naming = ghost
                ghost = nil
            }
    }

    private func x(_ time: TimeInterval, width: CGFloat) -> CGFloat {
        let range = visible ?? 0...duration
        return width * (time - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func ghostBar(_ draft: ClipDraft, top: CGFloat, width: CGFloat) -> some View {
        let left = x(draft.start, width: width)
        let barWidth = max(MarkerLaneLayout.minClipWidth, x(draft.end, width: width) - left)
        return RoundedRectangle(cornerRadius: 7)
            .fill(.primary.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.primary.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            .frame(width: barWidth, height: MarkerLaneLayout.clipHeight)
            .offset(x: left, y: top)
            .allowsHitTesting(false)
    }

    private func ghostBubble(_ draft: ClipDraft, width: CGFloat) -> some View {
        let left = x(draft.start, width: width)
        return floatingBubble(
            MarkerBubble(Text(MarkerLaneDrag.clipReadout(start: draft.start, end: draft.end)).monospacedDigit()),
            minX: left, maxX: max(left + MarkerLaneLayout.minClipWidth, x(draft.end, width: width)), width: width
        )
    }

    /// Under the ghost, kept inside the lane when the clip is near its right edge.
    private func nameField(for draft: ClipDraft, top: CGFloat, width: CGFloat) -> some View {
        let fieldWidth: CGFloat = 140
        let left = max(0, min(x(draft.start, width: width), width - fieldWidth - InlineNameField.hintWidth - 8))
        return InlineNameField(
            width: fieldWidth,
            startsFocused: previewNaming != nil,
            onCommit: { name in
                naming = nil
                actions.createClip(name, draft.start, draft.end)
            },
            onCancel: { naming = nil }
        )
        .id(draft)
        .offset(x: left, y: top + MarkerLaneLayout.clipHeight + 8)
    }

    // MARK: Trim

    private func trimZones(
        _ clip: MarkerLaneLayout.Clip, _ marker: PlaybackScrubber.Marker, top: CGFloat, width: CGFloat
    ) -> some View {
        // A short clip keeps most of its body clickable.
        let inside = min(Self.edgeZone, clip.width / 3)
        let zone = Self.edgeZone + inside
        return ZStack(alignment: .topLeading) {
            ForEach([MarkerLaneDrag.Edge.start, .end], id: \.self) { edge in
                TrimZone(
                    onHover: { entered in
                        if entered {
                            handle = HandleEdge(id: marker.id, edge: edge)
                            hovered = marker.id
                        } else if handle?.id == marker.id && handle?.edge == edge {
                            handle = nil
                        }
                    },
                    onChange: { value in trimChanged(value, marker: marker, edge: edge, width: width) },
                    onEnd: { value in trimEnded(value, marker: marker) }
                )
                .frame(width: zone, height: MarkerLaneLayout.clipHeight)
                .contextMenu { menu(for: marker) }
                .offset(x: edge == .start ? clip.x - Self.edgeZone : clip.x + clip.width - inside)
            }
        }
        .offset(y: top)
    }

    private func trimChanged(
        _ value: DragGesture.Value, marker: PlaybackScrubber.Marker, edge: MarkerLaneDrag.Edge, width: CGFloat
    ) {
        guard let original = markers.first(where: { $0.id == marker.id }), let originalEnd = original.end else { return }
        if trim == nil {
            guard abs(value.translation.width) >= 3 else { return }
            trim = TrimDraft(id: marker.id, edge: edge, start: original.start, end: originalEnd)
            trimOriginX = x(edge == .start ? original.start : originalEnd, width: width)
        }
        guard var draft = trim else { return }
        let time = MarkerLaneDrag.time(
            atX: trimOriginX + value.translation.width, width: width, duration: duration,
            fine: isFine, snapTo: snapPoints(excluding: marker.id)
        )
        let bounds = MarkerLaneDrag.trim(edge, to: time, start: draft.start, end: draft.end, duration: duration)
        guard bounds.start != draft.start || bounds.end != draft.end else { return }
        draft.start = bounds.start
        draft.end = bounds.end
        trim = draft
        actions.trimming(original, draft.start, draft.end)
    }

    /// A press that never became a trim is a click on the clip beneath.
    private func trimEnded(_ value: DragGesture.Value, marker: PlaybackScrubber.Marker) {
        guard let draft = trim else {
            if abs(value.translation.width) < 3, abs(value.translation.height) < 3 { activate(marker) }
            return
        }
        trim = nil
        if let original = markers.first(where: { $0.id == draft.id }) {
            actions.trimmed(original, draft.start, draft.end)
        }
    }

    /// White with a dark ring, taller than the bar, at the edge being trimmed.
    private func handleBar(_ clip: MarkerLaneLayout.Clip, edge: MarkerLaneDrag.Edge, top: CGFloat) -> some View {
        let edgeX = edge == .start ? clip.x : clip.x + clip.width
        return RoundedRectangle(cornerRadius: 3)
            .fill(.white)
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 10 / 255, green: 24 / 255, blue: 25 / 255).opacity(0.9))
                    .padding(-2)
            }
            .frame(width: 5, height: MarkerLaneLayout.clipHeight + 8)
            .offset(x: edgeX - 2.5, y: top - 4)
            .allowsHitTesting(false)
    }

    private func trimBubble(_ trim: TrimDraft, width: CGFloat) -> some View {
        let edgeX = x(trim.edge == .start ? trim.start : trim.end, width: width)
        return MarkerBubble(
            Text(MarkerLaneDrag.trimReadout(trim.edge, start: trim.start, end: trim.end)).monospacedDigit()
        )
        // A zero-sized frame the bubble hangs above, centred on the edge,
        // rather than alignment guides, which resized the stack they sat in.
        .frame(width: 0, height: 0, alignment: .bottom)
        .offset(x: min(max(edgeX, 80), width - 80), y: -4)
        .allowsHitTesting(false)
    }

    /// Above the lane, at the left of `minX...maxX` or the right of it,
    /// whichever side has room.
    private func floatingBubble(_ bubble: MarkerBubble, minX: CGFloat, maxX: CGFloat, width: CGFloat) -> some View {
        let leading = (minX + maxX) / 2 < width * 0.6
        return bubble
            .frame(width: 0, height: 0, alignment: leading ? .bottomLeading : .bottomTrailing)
            .offset(x: leading ? minX : maxX, y: -4)
            .allowsHitTesting(false)
    }

    // MARK: Text

    private func marker(_ id: AnyHashable) -> PlaybackScrubber.Marker? {
        shownMarkers.first { $0.id == id }
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
        return floatingBubble(
            MarkerBubble(
                name: marker.name.isEmpty ? "Untitled" : marker.name,
                detail: "\(timeLabel(marker)) \u{00B7} \(action)"
            ),
            minX: minX, maxX: maxX, width: width
        )
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

    @ViewBuilder
    private func menu(for marker: PlaybackScrubber.Marker) -> some View {
        if marker.isClip {
            Button("Loop This Clip") { actions.clip(marker, false) }
                .disabled(!isLoopOn)
            Button(marker.isLooping && isLoopOn ? "Remove from Loop" : "Add to Loop") { actions.clip(marker, true) }
                .disabled(!isLoopOn)
        }
        Button("Jump to Start") { actions.jump(marker) }
        Divider()
        Button("Rename") { renaming = marker.id }
        Button("Edit Times\u{2026}") { actions.editTimes(marker) }
        if marker.isClip {
            Button("Make a Point") { actions.makePoint(marker) }
        }
        Divider()
        // Shown for the hint; the key itself comes in Phase 5.
        Button("Delete", role: .destructive) { actions.delete(marker) }
            .keyboardShortcut(.delete, modifiers: [])
    }
}

/// A strip over a clip's edge: the resize pointer while the mouse is over it
/// or dragging from it, with the drag and hover reported to the lane. The
/// pointer stays through a drag even when the mouse outruns the strip.
private struct TrimZone: View {
    let onHover: (Bool) -> Void
    let onChange: (DragGesture.Value) -> Void
    let onEnd: (DragGesture.Value) -> Void

    @State private var isInside = false
    @State private var isDragging = false
    @State private var isPushed = false

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .onHover { inside in
                isInside = inside
                syncCursor()
                onHover(inside)
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("markerLane"))
                    .onChanged { value in
                        isDragging = true
                        syncCursor()
                        onChange(value)
                    }
                    .onEnded { value in
                        isDragging = false
                        syncCursor()
                        onEnd(value)
                    }
            )
            .onDisappear {
                isInside = false
                isDragging = false
                syncCursor()
            }
    }

    private func syncCursor() {
        let wanted = isInside || isDragging
        if wanted && !isPushed {
            NSCursor.resizeLeftRight.push()
            isPushed = true
        } else if !wanted && isPushed {
            NSCursor.pop()
            isPushed = false
        }
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
    markers: [PlaybackScrubber.Marker] = previewMarkers,
    hover: AnyHashable? = nil, renames: Bool = false, isLoopOn: Bool = true,
    ghost: MarkerLane.ClipDraft? = nil, naming: MarkerLane.ClipDraft? = nil, trim: MarkerLane.TrimDraft? = nil
) -> some View {
    MarkerLane(
        markers: markers, duration: 258, isLoopOn: isLoopOn,
        previewHover: hover, startsRenaming: renames,
        previewGhost: ghost, previewNaming: naming, previewTrim: trim
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

#Preview("Lane, dragging a clip", traits: .fixedLayout(width: 680, height: 170)) {
    lanePreview(ghost: .init(start: 100, end: 124))
}

#Preview("Lane, naming a new clip", traits: .fixedLayout(width: 680, height: 170)) {
    lanePreview(naming: .init(start: 100, end: 124))
}

#Preview("Lane, trimming a clip", traits: .fixedLayout(width: 680, height: 170)) {
    lanePreview(
        markers: previewMarkers.map {
            $0.id == AnyHashable("Solo")
                ? .init(id: $0.id, name: $0.name, start: 140, end: 180, isLooping: true) : $0
        },
        trim: .init(id: "Solo", edge: .start, start: 140, end: 180)
    )
}

#Preview("Empty lane, dragging a clip", traits: .fixedLayout(width: 680, height: 150)) {
    lanePreview(markers: [], ghost: .init(start: 100, end: 124))
}

#Preview("Lane, renaming", traits: .fixedLayout(width: 680, height: 150)) {
    lanePreview(renames: true)
}
#endif
