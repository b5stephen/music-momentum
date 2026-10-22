//
//  PlaybackScrubber.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Play mode's timeline: a position bar with the markers as labelled ticks
/// above it. Only commits a seek on release — one per gesture, not sixty — so
/// the audio doesn't stutter while dragging. A quick tap on a tick jumps to
/// it; holding one hands it to `onHoldMarker` (the editor), or without that
/// scrubs; moving off it scrubs as anywhere else.
struct PlaybackScrubber: View {
    let position: TimeInterval
    /// Inert when `nil`.
    let duration: TimeInterval?
    var markers: [Marker] = []
    /// Song time a point's name stays up after the playhead crosses it.
    var pointNameDuration: TimeInterval = 3
    var onScrub: (TimeInterval) -> Void = { _ in }
    var onHoldMarker: ((Marker) -> Void)?
    var onCommit: (TimeInterval) -> Void

    /// A point, or with an `end` a span; Practice passes its markers as
    /// points and the looping range as the one span.
    nonisolated struct Marker: Identifiable {
        let id: AnyHashable
        /// As stored: an unnamed marker's tick has no label.
        var name: String = ""
        let start: TimeInterval
        let end: TimeInterval?
        var isLooping: Bool = false
        /// What VoiceOver calls it, "Marker 3" for an unnamed one.
        var spokenName: String?

        var isClip: Bool { end != nil }
    }

    /// What the bar draws while a finger is down, so the thumb never snaps
    /// back to a stale playhead before the player catches up.
    @State private var dragPosition: TimeInterval?
    /// A touch that landed on a marker, not yet a tap or a scrub.
    @State private var pendingMarker: Marker?
    @State private var holdTask: Task<Void, Never>?
    /// A hold has opened the editor; the rest of the touch does nothing.
    @State private var isHolding = false
    /// A hold that opens the Edit Marker sheet has its touch cancelled by
    /// the presentation, so `onEnded` never runs; without this the next
    /// touch only cleared the hold and did nothing.
    @GestureState private var isTouching = false

    private var isDragging: Bool { dragPosition != nil }
    private var displayedPosition: TimeInterval { dragPosition ?? position }

    private var fraction: Double {
        guard let duration, duration > 0 else { return 0 }
        return min(max(displayedPosition / duration, 0), 1)
    }

    var body: some View {
        // The bar's height is touch area round the lane and the track, so the
        // times tuck up under the track rather than under the touch area.
        VStack(spacing: -4) {
            bar
            labels
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }

    /// Shared with Loop mode's block row, so the transport doesn't move
    /// when the mode switches.
    static let barHeight: CGFloat = 48
    private static let barTopPadding: CGFloat = 2
    private static let tickLabelHeight: CGFloat = 16
    private static let tickLabelGap: CGFloat = 2
    private static let laneHeight: CGFloat = 8
    private static let laneGap: CGFloat = 4
    /// The track's centre, which Loop mode's blocks centre on too.
    static let trackCentre: CGFloat = barTopPadding + tickLabelHeight + tickLabelGap + laneHeight + laneGap + draggingTrackHeight / 2
    /// The track's height while a finger is down; it sits in a slot this
    /// tall either way, so growing doesn't nudge the lane above it.
    private static let draggingTrackHeight: CGFloat = 12
    private static let tapSlop: CGFloat = 6
    private static let holdDelay: Duration = .milliseconds(300)
    /// A long press, as anywhere else in iOS.
    private static let editDelay: Duration = .milliseconds(500)

    /// Markers get a lane of their own above the track. Drawn on the track
    /// they fought the played fill: a clip at track height read as buffering,
    /// and a looping one needed a halo to survive being played past.
    private var bar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let trackHeight: CGFloat = isDragging ? Self.draggingTrackHeight : 6
            // Above the track's slot is the lane's; the track below always scrubs.
            let laneBottom = Self.trackCentre - Self.draggingTrackHeight / 2 - Self.laneGap / 2

            VStack(spacing: 0) {
                tickLabels(width: width)
                    .frame(height: Self.tickLabelHeight)
                    .padding(.bottom, Self.tickLabelGap)

                markerLane(width: width)
                    .frame(height: Self.laneHeight)
                    .padding(.bottom, Self.laneGap)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.18))
                    Capsule()
                        .fill(.primary)
                        .frame(width: max(trackHeight, width * fraction))
                        .opacity(duration == nil ? 0 : 1)
                }
                .frame(height: trackHeight)
                .frame(height: Self.draggingTrackHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Playback position")
                .accessibilityValue(Text([Self.timeLabel(displayedPosition), sectionName].compactMap(\.self).joined(separator: ", ")))
                .accessibilityAdjustableAction { direction in
                    guard duration != nil else { return }
                    let step: TimeInterval = direction == .increment ? 5 : -5
                    onCommit(displayedPosition + step)
                }
            }
            .padding(.top, Self.barTopPadding)
            .frame(maxHeight: .infinity, alignment: .top)
            .contentShape(.rect)
            .gesture(dragGesture(width: width, laneBottom: laneBottom))
            .onChange(of: isTouching) { _, touching in
                if !touching, isHolding { isHolding = false }
            }
            .animation(.snappy(duration: 0.2), value: isDragging)
            .overlay(alignment: .topLeading) { tickAccessibility(width: width) }
        }
        .frame(height: Self.barHeight)
        .disabled(duration == nil)
    }

    private var points: [Marker] { markers.filter { !$0.isClip } }

    /// Each label runs from its tick towards the next, and gives way when
    /// there's too little room to read; an unnamed marker's tick has none.
    @ViewBuilder
    private func tickLabels(width: CGFloat) -> some View {
        if let duration, duration > 0 {
            let points = points.sorted { $0.start < $1.start }
            let xs = points.map { width * min(max($0.start / duration, 0), 1) }
            let widths = Self.tickLabelWidths(xs: xs, width: width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, marker in
                    if !marker.name.isEmpty, let labelWidth = widths[index] {
                        Text(marker.name)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .frame(width: labelWidth, alignment: .leading)
                            .offset(x: xs[index] - 1)
                    }
                }
            }
            .frame(width: width, alignment: .topLeading)
            .foregroundStyle(.secondary)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    /// The room each tick's label has, running right from its tick to just
    /// short of the next tick or the end of the bar; `nil` where that's too
    /// little to read. `xs` in time order.
    nonisolated static func tickLabelWidths(
        xs: [CGFloat],
        width: CGFloat,
        spacing: CGFloat = 6,
        minimum: CGFloat = 24
    ) -> [CGFloat?] {
        xs.indices.map { index in
            let room = index + 1 < xs.count
                ? xs[index + 1] - xs[index] - spacing
                : width - xs[index]
            return room >= minimum ? room : nil
        }
    }

    /// VoiceOver can't find a tick by touch, so each is an element of its
    /// own, over the lane where a finger would find it.
    @ViewBuilder
    private func tickAccessibility(width: CGFloat) -> some View {
        if let duration, duration > 0 {
            ZStack(alignment: .topLeading) {
                ForEach(points) { marker in
                    let x = width * min(max(marker.start / duration, 0), 1)
                    Color.clear
                        .frame(width: 44, height: Self.trackCentre - Self.draggingTrackHeight / 2)
                        .offset(x: x - 22)
                        .accessibilityElement()
                        .accessibilityLabel("\(marker.spokenName ?? marker.name), \(Self.timeLabel(marker.start))")
                        .accessibilityHint("Jumps here")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onCommit(marker.start) }
                        .accessibilityActions {
                            if let onHoldMarker {
                                Button("Edit Marker") { onHoldMarker(marker) }
                            }
                        }
                }
            }
            .frame(width: width, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    /// Ticks for points; the looping range, the one span, is solid.
    @ViewBuilder
    private func markerLane(width: CGFloat) -> some View {
        if let duration, duration > 0 {
            ZStack(alignment: .leading) {
                // Spans first and half height, so the ticks inside a
                // looping range still stand out of it.
                ForEach(markers.filter(\.isClip) + points) { marker in
                    let x = width * min(max(marker.start / duration, 0), 1)
                    if let end = marker.end {
                        let span = width * min(max((end - marker.start) / duration, 0), 1)
                        Capsule()
                            .fill(marker.isLooping ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(0.35)))
                            .frame(width: max(Self.laneHeight / 2, span), height: Self.laneHeight / 2)
                            .offset(x: min(x, width - max(Self.laneHeight / 2, span)))
                    } else {
                        Capsule()
                            .fill(.primary.opacity(0.75))
                            .frame(width: 2, height: Self.laneHeight)
                            .offset(x: min(max(0, x - 1), width - 2))
                    }
                }
            }
            .frame(width: width, alignment: .leading)
            .allowsHitTesting(false)
        } else {
            Color.clear
        }
    }

    private func dragGesture(width: CGFloat, laneBottom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                guard let duration, duration > 0, width > 0, !isHolding else { return }
                if dragPosition == nil, pendingMarker == nil {
                    if value.startLocation.y < laneBottom,
                       let marker = Self.marker(at: value.startLocation.x, width: width, duration: duration, in: points, targetWidth: 44) {
                        pendingMarker = marker
                        holdTask = Task {
                            try? await Task.sleep(for: onHoldMarker == nil ? Self.holdDelay : Self.editDelay)
                            guard !Task.isCancelled, let held = pendingMarker else { return }
                            pendingMarker = nil
                            if let onHoldMarker, !held.isClip {
                                isHolding = true
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                onHoldMarker(held)
                            } else {
                                scrub(to: value.startLocation.x, width: width, duration: duration)
                            }
                        }
                        return
                    }
                } else if pendingMarker != nil {
                    guard hypot(value.translation.width, value.translation.height) > Self.tapSlop else { return }
                    pendingMarker = nil
                    holdTask?.cancel()
                }
                scrub(to: value.location.x, width: width, duration: duration)
            }
            .onEnded { _ in
                holdTask?.cancel()
                if isHolding {
                    isHolding = false
                    return
                }
                if let marker = pendingMarker {
                    pendingMarker = nil
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    #endif
                    onCommit(marker.start)
                    return
                }
                guard let time = dragPosition else { return }
                dragPosition = nil
                onCommit(time)
            }
    }

    private func scrub(to x: CGFloat, width: CGFloat, duration: TimeInterval) {
        if dragPosition == nil {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
        }
        let time = duration * min(max(x / width, 0), 1)
        dragPosition = time
        onScrub(time)
    }

    /// The marker a tap at `x` in the lane jumps to. Targets are widened to a
    /// fingertip; a point beats the clip it sits in, the nearest point wins,
    /// and overlapping clips go to the latest start, as `sectionName` does.
    nonisolated static func marker(
        at x: CGFloat,
        width: CGFloat,
        duration: TimeInterval,
        in markers: [Marker],
        targetWidth: CGFloat = 22
    ) -> Marker? {
        guard duration > 0, width > 0 else { return nil }
        func offset(_ time: TimeInterval) -> CGFloat { width * min(max(time / duration, 0), 1) }
        func distance(_ marker: Marker) -> CGFloat { abs(offset(marker.start) - x) }

        if let point = markers.filter({ !$0.isClip && distance($0) <= targetWidth / 2 }).min(by: { distance($0) < distance($1) }) {
            return point
        }
        return markers.filter { marker in
            guard let end = marker.end else { return false }
            let (lower, upper) = (offset(marker.start), offset(end))
            let pad = max(0, (targetWidth - (upper - lower)) / 2)
            return (lower - pad...upper + pad).contains(x)
        }
        .max { $0.start < $1.start }
    }

    private var sectionName: String? {
        duration == nil ? nil : Self.sectionName(
            at: displayedPosition, in: markers, pointNameDuration: pointNameDuration
        )
    }

    /// The section's name sits between the times rather than riding the
    /// playhead: a moving label pulls the eye off the instrument, and while
    /// dragging this one says where you'd land.
    private var labels: some View {
        HStack {
            Text(Self.timeLabel(displayedPosition))
            Spacer()
            if let duration {
                Text("-" + Self.timeLabel(max(0, duration - displayedPosition)))
            }
        }
        .overlay {
            if let sectionName {
                Text(sectionName)
                    .lineLimit(1)
                    .padding(.horizontal, 60)
                    .id(sectionName)
                    .transition(.opacity)
            }
        }
        .animation(isDragging ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.6), value: sectionName)
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    /// A point's name for `pointNameDuration` after it, then the clip the
    /// position is in. Where markers overlap, the latest start wins.
    nonisolated static func sectionName(
        at position: TimeInterval,
        in markers: [Marker],
        pointNameDuration: TimeInterval
    ) -> String? {
        func latest(where matches: (Marker) -> Bool) -> String? {
            markers.filter { !$0.name.isEmpty && matches($0) }.max { $0.start < $1.start }?.name
        }
        return latest { $0.end == nil && (0..<pointNameDuration).contains(position - $0.start) }
            ?? latest { marker in marker.end.map { (marker.start..<$0).contains(position) } ?? false }
    }

    /// `m:ss`, or `h:mm:ss` when needed.
    nonisolated static func timeLabel(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// `45s` under a minute, `m:ss` past it.
    nonisolated static func lengthLabel(_ seconds: TimeInterval) -> String {
        seconds < 60
            ? "\(Int(seconds.rounded()))s"
            : timeLabel(seconds)
    }
}

#Preview("Just past a point") {
    PlaybackScrubber(
        position: 41,
        duration: 245,
        markers: [
            .init(id: "verse", name: "Verse 2", start: 40, end: nil),
            .init(id: "solo", name: "Solo", start: 96, end: 128, isLooping: true)
        ]
    ) { _ in }
        .padding(.horizontal, 32)
}

#Preview("No markers") {
    PlaybackScrubber(position: 71, duration: 245) { _ in }
        .padding(.horizontal, 32)
}

#Preview("A few markers") {
    PlaybackScrubber(
        position: 71,
        duration: 245,
        markers: [
            .init(id: "intro", name: "Intro", start: 4, end: nil),
            .init(id: "verse", name: "Verse riff", start: 40, end: 71),
            .init(id: "solo", name: "Solo", start: 96, end: 128, isLooping: true),
            .init(id: "outro", name: "Outro", start: 238, end: nil)
        ]
    ) { _ in }
        .padding(.horizontal, 32)
}

// The case the halo around a lit band is there for.
#Preview("Looping, already played") {
    PlaybackScrubber(
        position: 190,
        duration: 245,
        markers: [
            .init(id: "intro", name: "Intro", start: 4, end: nil),
            .init(id: "verse", name: "Verse riff", start: 40, end: 71),
            .init(id: "solo", name: "Solo", start: 96, end: 128, isLooping: true),
            .init(id: "outro", name: "Outro", start: 238, end: nil)
        ]
    ) { _ in }
        .padding(.horizontal, 32)
}

#Preview("A songful of markers") {
    PlaybackScrubber(
        position: 120,
        duration: 245,
        markers: (0..<8).map {
            .init(
                id: $0,
                name: "Section \($0 + 1) with a name long enough to truncate",
                start: TimeInterval($0) * 28 + 4,
                end: $0.isMultiple(of: 2) ? TimeInterval($0) * 28 + 22 : nil,
                isLooping: $0 == 4
            )
        }
    ) { _ in }
        .padding(.horizontal, 32)
}
