//
//  MarkerRangeEditor.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A zoomable strip of the track with drag handles for a marker's times.
///
/// No waveform: Apple Music tracks are DRM-protected and neither MusicKit nor
/// `MPMediaItem` gives out samples. Zoom does the job instead — a point is
/// most of a second across a whole song, about 15ms in the 5s window.
struct MarkerRangeEditor: View {
    @Binding var start: TimeInterval
    @Binding var end: TimeInterval?
    let duration: TimeInterval
    let playhead: TimeInterval
    var onGrab: (MarkerHandle) -> Void = { _ in }
    var onScrub: () -> Void = {}
    var onSeek: (TimeInterval) -> Void = { _ in }

    enum Zoom: String, CaseIterable, Identifiable {
        case whole = "Song", thirty = "30s", five = "5s"
        var id: String { rawValue }
        var span: TimeInterval? {
            switch self {
            case .whole: nil
            case .thirty: 30
            case .five: 5
            }
        }
    }

    @State private var zoom: Zoom = .whole
    @State private var windowStart: TimeInterval = 0
    @State private var drag: Drag?
    /// Where the playhead is being dragged to. The seek waits for the drop:
    /// seeking on every frame makes the player stutter through the drag.
    @State private var scrubTime: TimeInterval?
    /// Whether the dragged handle is locked to the playhead.
    @State private var isSnapped = false
    @State private var bubbleWidth: CGFloat = 0
    /// Where the finger was, and the time under it, when the drag began or
    /// last changed speed. Movement is measured from here rather than read
    /// off the touch, so a slowed drag doesn't jump when the speed changes.
    @State private var anchor: (x: CGFloat, time: TimeInterval) = (0, 0)
    @State private var scrubSpeed: Double = 1
    /// The ruler step the dragged time is in; a change is a notch.
    @State private var notch: Int?

    private enum Drag {
        case start, end, playhead
        case pan(from: TimeInterval)
    }

    private static let grabRadius: CGFloat = 28
    /// The touch area; the track drawn across its middle is much thinner.
    private static let barHeight: CGFloat = 44
    private static let trackHeight: CGFloat = 8
    private static let handleSize: CGFloat = 20
    private static let playheadKnobSize: CGFloat = 12
    private static let fadeWidth: CGFloat = 28
    private static let snapRadius: CGFloat = 10
    private static let bubbleHeight: CGFloat = 26
    private static let majorTickHeight: CGFloat = 8
    private static let minorTickHeight: CGFloat = 4
    /// Further than this and a touch in the open is a pan, not a tap.
    private static let tapSlop: CGFloat = 6
    private static let labelHeight: CGFloat = 18

    private var span: TimeInterval {
        min(zoom.span ?? duration, duration)
    }

    private var window: ClosedRange<TimeInterval> {
        windowStart...(windowStart + span)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(PlaybackScrubber.timeLabel(window.lowerBound)) – \(PlaybackScrubber.timeLabel(window.upperBound))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Zoom", selection: $zoom) {
                    ForEach(Zoom.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            strip
                .frame(height: Self.barHeight + Self.labelHeight + 8)
        }
        .onAppear {
            // A short clip is a sliver on the whole song, so it opens zoomed in.
            if let end, end - start <= 25 { zoom = .thirty }
            recentre()
        }
        .onChange(of: zoom) { recentre() }
        // Nudges and the typed fields can push a handle out of view.
        .onChange(of: start) { if !window.contains(start) { recentre() } }
        .onChange(of: end) { if let end, !window.contains(end) { recentre() } }
        // The time fields carry the same values for VoiceOver.
        .accessibilityHidden(true)
    }

    private var strip: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    track(width: width)
                    ruler(width: width)
                    ticks(width: width)
                }
                .frame(width: width, height: proxy.size.height, alignment: .topLeading)
                .mask { edgeFade(width: width) }

                if window.contains(shownPlayhead) {
                    playheadLine(at: x(shownPlayhead, width: width))
                } else {
                    offscreenPlayhead(isBefore: shownPlayhead < window.lowerBound, width: width)
                }

                if isVisible(start, width: width) {
                    handle(at: x(start, width: width), filled: true)
                }
                if let end, isVisible(end, width: width) {
                    handle(at: x(end, width: width), filled: false)
                }

                if let draggedTime {
                    timeBubble(draggedTime, at: x(draggedTime, width: width), width: width)
                }
            }
            .contentShape(.rect)
            .gesture(dragGesture(width: width))
            .sensoryFeedback(.selection, trigger: notch) { old, new in
                old != nil && new != nil && !isSnapped
            }
            .sensoryFeedback(.impact(weight: .light), trigger: scrubSpeed) { _, _ in drag != nil }
        }
    }

    /// Drawn the length of the whole song and cut by the strip, so it's
    /// rounded only at the song's real ends: a flat, fading edge is where
    /// there's more to pan to.
    private func track(width: CGFloat) -> some View {
        let songStart = x(0, width: width)
        return Capsule()
            .fill(.quaternary)
            .overlay(alignment: .leading) {
                if let end {
                    let left = x(start, width: width) - songStart
                    Rectangle()
                        .fill(.tint)
                        .frame(width: max(0, x(end, width: width) - songStart - left))
                        .offset(x: left)
                }
            }
            .clipShape(Capsule())
            .frame(width: x(duration, width: width) - songStart, height: Self.trackHeight)
            .offset(x: songStart, y: (Self.barHeight - Self.trackHeight) / 2)
    }

    private func edgeFade(width: CGFloat) -> some View {
        let fade = min(0.5, Self.fadeWidth / max(width, 1))
        let cutBefore = windowStart > 0
        let cutAfter = windowStart + span < duration
        return LinearGradient(
            stops: [
                .init(color: cutBefore ? .clear : .black, location: 0),
                .init(color: .black, location: fade),
                .init(color: .black, location: 1 - fade),
                .init(color: cutAfter ? .clear : .black, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Half a handle past the edge still shows, so dragging one out of view
    /// doesn't make it vanish the instant its centre leaves.
    private func isVisible(_ time: TimeInterval, width: CGFloat) -> Bool {
        let margin = Self.handleSize / 2
        return (-margin...(width + margin)).contains(x(time, width: width))
    }

    private var shownPlayhead: TimeInterval { scrubTime ?? playhead }

    private var draggedTime: TimeInterval? {
        switch drag {
        case .start: start
        case .end: end
        case .playhead: scrubTime
        case .pan, nil: nil
        }
    }

    /// Sits above the strip, over the zoom row, because the thumb covers the
    /// handle and the strip, and the big time fields are further down.
    private func timeBubble(_ time: TimeInterval, at position: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 5) {
            Text(PreciseTime.format(time))
            if let note = isSnapped ? "Playhead" : Self.speedName(scrubSpeed) {
                Text(note)
                    .opacity(0.65)
            }
        }
        .font(.footnote.weight(.semibold).monospacedDigit())
        .foregroundStyle(Color(.systemBackground))
        .padding(.horizontal, 10)
        .frame(height: Self.bubbleHeight)
        .background(Color(.label), in: Capsule())
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { bubbleWidth = $0 }
        .offset(
            x: max(0, min(position - bubbleWidth / 2, width - bubbleWidth)),
            y: -Self.bubbleHeight - 6
        )
        .allowsHitTesting(false)
    }

    /// Points the way to a playhead that's been skipped or played out of view.
    private func offscreenPlayhead(isBefore: Bool, width: CGFloat) -> some View {
        Image(systemName: isBefore ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
            .font(.system(size: Self.playheadKnobSize - 2))
            .foregroundStyle(.primary)
            .frame(width: Self.playheadKnobSize, height: Self.playheadKnobSize)
            .offset(x: isBefore ? 0 : width - Self.playheadKnobSize)
    }

    /// The knob sits above the track, so it stays grabbable when the playhead
    /// is parked on a handle, as it is after a cue.
    private func playheadLine(at position: CGFloat) -> some View {
        Capsule()
            .fill(.primary)
            .frame(width: 2, height: Self.barHeight - 12)
            .overlay(alignment: .top) {
                Circle()
                    .fill(.primary)
                    .frame(width: Self.playheadKnobSize, height: Self.playheadKnobSize)
                    .offset(y: -Self.playheadKnobSize / 2)
            }
            .offset(x: position - 1, y: 6)
    }

    /// The end handle is hollow, filled with the form cell's colour so the
    /// clip doesn't show through it.
    private func handle(at position: CGFloat, filled: Bool) -> some View {
        Circle()
            .fill(filled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            .overlay(Circle().strokeBorder(.tint, lineWidth: 3))
            .frame(width: Self.handleSize, height: Self.handleSize)
            .offset(x: position - Self.handleSize / 2, y: (Self.barHeight - Self.handleSize) / 2)
    }

    private func ticks(width: CGFloat) -> some View {
        let interval = Self.tickInterval(for: span)
        let first = (window.lowerBound / interval).rounded(.up) * interval
        let times = stride(from: first, through: window.upperBound, by: interval)

        return ForEach(Array(times), id: \.self) { time in
            let position = x(time, width: width)
            VStack(spacing: 2) {
                Color.clear
                    .frame(width: 1, height: Self.barHeight)
                Text(PlaybackScrubber.timeLabel(time))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(height: Self.labelHeight)
                    // Labels at the ends would hang off the strip.
                    .offset(x: position < 20 ? 14 : position > width - 20 ? -14 : 0)
            }
            .frame(width: 1)
            .offset(x: position)
        }
    }

    static func tickInterval(for span: TimeInterval) -> TimeInterval {
        let candidates: [TimeInterval] = [1, 2, 5, 10, 15, 30, 60, 120, 300]
        return candidates.first { span / $0 <= 8 } ?? 600
    }

    /// Divides each labelled interval into steps you can count: tenths at
    /// the 5s zoom, whole seconds at 30s.
    nonisolated static func minorTickInterval(for major: TimeInterval) -> TimeInterval {
        switch major {
        case 1: 0.1
        case 2: 0.5
        case 5: 1
        case 10: 2
        case 15, 30: 5
        case 60: 10
        case 120: 30
        default: major / 5
        }
    }

    /// Counted in whole minor steps so floating-point drift can't skip or
    /// double a mark.
    private func ruler(width: CGFloat) -> some View {
        let major = Self.tickInterval(for: span)
        let minor = Self.minorTickInterval(for: major)
        let perMajor = max(1, Int((major / minor).rounded()))
        let first = Int((window.lowerBound / minor).rounded(.up))
        let last = Int((window.upperBound / minor).rounded(.down))

        return Canvas { context, _ in
            guard first <= last else { return }
            var minorMarks = Path()
            var majorMarks = Path()
            for step in first...last {
                let position = x(TimeInterval(step) * minor, width: width)
                if step % perMajor == 0 {
                    majorMarks.addRect(CGRect(x: position - 0.5, y: Self.barHeight - Self.majorTickHeight, width: 1, height: Self.majorTickHeight))
                } else {
                    minorMarks.addRect(CGRect(x: position - 0.5, y: Self.barHeight - Self.minorTickHeight, width: 1, height: Self.minorTickHeight))
                }
            }
            context.fill(minorMarks, with: .style(.tertiary))
            context.fill(majorMarks, with: .style(.secondary))
        }
        .frame(width: width, height: Self.barHeight)
    }

    // MARK: - Geometry

    private func x(_ time: TimeInterval, width: CGFloat) -> CGFloat {
        guard span > 0 else { return 0 }
        return CGFloat((time - windowStart) / span) * width
    }

    private func time(atX x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return windowStart }
        return windowStart + TimeInterval(x / width) * span
    }

    private func recentre() {
        let centre = end.map { (start + $0) / 2 } ?? start
        windowStart = clampWindowStart(centre - span / 2)
    }

    private func clampWindowStart(_ value: TimeInterval) -> TimeInterval {
        max(0, min(value, duration - span))
    }

    // MARK: - Dragging

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if drag == nil {
                    let picked = pick(at: value.startLocation, width: width)
                    drag = picked
                    switch picked {
                    case .start: onGrab(.start)
                    case .end: onGrab(.end)
                    case .playhead: onScrub()
                    case .pan: break
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                    anchor = (value.startLocation.x, grabTime(for: picked, atX: value.startLocation.x, width: width))
                    scrubSpeed = 1
                }
                if case .pan = drag {} else {
                    let speed = Self.scrubSpeed(forDistance: distanceOffBar(value.location.y))
                    if speed != scrubSpeed, let current = draggedTime {
                        anchor = (value.location.x, current)
                        scrubSpeed = speed
                    }
                }
                let time = anchor.time + TimeInterval((value.location.x - anchor.x) / width) * span * scrubSpeed
                switch drag {
                case .start:
                    let ceiling = end.map { $0 - SongMarker.minimumClipLength } ?? duration
                    start = snapToPlayhead(time, in: 0...max(0, ceiling), width: width)
                case .end:
                    let floor = min(start + SongMarker.minimumClipLength, duration)
                    end = snapToPlayhead(time, in: floor...duration, width: width)
                case .playhead:
                    scrubTime = max(window.lowerBound, min(time, window.upperBound))
                case .pan(let origin):
                    let shift = TimeInterval(value.translation.width / width) * span
                    windowStart = clampWindowStart(origin - shift)
                case nil:
                    break
                }
                updateNotch(draggedTime)
            }
            .onEnded { value in
                switch drag {
                case .playhead:
                    if let scrubTime { onSeek(scrubTime) }
                case .pan where abs(value.translation.width) < Self.tapSlop:
                    let time = time(atX: value.location.x, width: width)
                    onScrub()
                    onSeek(max(0, min(time, duration)))
                default:
                    break
                }
                drag = nil
                scrubTime = nil
                isSnapped = false
                notch = nil
                scrubSpeed = 1
            }
    }

    /// A handle picks up from where it is, not from the finger, so grabbing
    /// one a little off-centre doesn't nudge it. A drag in the open takes
    /// the playhead to the finger.
    private func grabTime(for picked: Drag, atX touch: CGFloat, width: CGFloat) -> TimeInterval {
        switch picked {
        case .start: start
        case .end: end ?? start
        case .playhead where window.contains(playhead) && abs(x(playhead, width: width) - touch) <= Self.grabRadius:
            playhead
        default: time(atX: touch, width: width)
        }
    }

    private func distanceOffBar(_ y: CGFloat) -> CGFloat {
        y < 0 ? -y : max(0, y - Self.barHeight)
    }

    /// The further the finger strays from the strip, the slower the drag, as
    /// in the Music app's scrubber. Nearer than 100pt slowed drags that only
    /// wandered, so the tiers start there and sit close enough together to
    /// all fit below the strip on a mini.
    nonisolated static func scrubSpeed(forDistance distance: CGFloat) -> Double {
        switch distance {
        case ..<100: 1
        case ..<140: 0.5
        case ..<180: 0.25
        default: 0.125
        }
    }

    nonisolated static func speedName(_ speed: Double) -> String? {
        switch speed {
        case 0.5: "Half speed"
        case 0.25: "Quarter speed"
        case 0.125: "Fine"
        default: nil
        }
    }

    private func updateNotch(_ time: TimeInterval?) {
        guard let time else { return }
        let minor = Self.minorTickInterval(for: Self.tickInterval(for: span))
        // The epsilon keeps a time sitting on a mark, like 70.0 read as 699.999… tenths, in its own step.
        notch = Int((time / minor + 1e-6).rounded(.down))
    }

    private func snapToPlayhead(_ time: TimeInterval, in range: ClosedRange<TimeInterval>, width: CGFloat) -> TimeInterval {
        let tolerance = width > 0 ? TimeInterval(Self.snapRadius / width) * span : 0
        let landing = Self.handleTime(
            time,
            playhead: window.contains(playhead) ? playhead : nil,
            tolerance: tolerance,
            in: range
        )
        if landing.snapped, !isSnapped {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            #endif
        }
        isSnapped = landing.snapped
        return landing.time
    }

    /// Where a dragged handle lands: on the playhead when the touch is within
    /// `tolerance` of it and the handle is allowed there, otherwise the touch
    /// clamped to `range`.
    nonisolated static func handleTime(
        _ time: TimeInterval,
        playhead: TimeInterval?,
        tolerance: TimeInterval,
        in range: ClosedRange<TimeInterval>
    ) -> (time: TimeInterval, snapped: Bool) {
        if let playhead, range.contains(playhead), abs(time - playhead) <= tolerance {
            return (playhead, true)
        }
        return (max(range.lowerBound, min(time, range.upperBound)), false)
    }

    /// The nearest handle wins, except above the track, where the playhead's
    /// knob is. A drag in the open moves the playhead on the whole-song view,
    /// where there's nothing to pan; zoomed in it pans, and a tap seeks.
    private func pick(at touch: CGPoint, width: CGFloat) -> Drag {
        let playheadDistance = window.contains(playhead)
            ? abs(x(playhead, width: width) - touch.x) : .infinity
        let aboveTrack = touch.y < (Self.barHeight - Self.trackHeight) / 2

        var nearest: (Drag, CGFloat) = (.start, abs(x(start, width: width) - touch.x))
        if let end {
            let distance = abs(x(end, width: width) - touch.x)
            if distance < nearest.1 { nearest = (.end, distance) }
        }
        if playheadDistance <= Self.grabRadius, aboveTrack || playheadDistance < nearest.1 {
            return .playhead
        }
        if nearest.1 <= Self.grabRadius { return nearest.0 }
        return zoom == .whole ? .playhead : .pan(from: windowStart)
    }
}

#Preview("Clip") {
    @Previewable @State var start: TimeInterval = 71
    @Previewable @State var end: TimeInterval? = 84.5
    MarkerRangeEditor(start: $start, end: $end, duration: 245, playhead: 75)
        .padding()
}

#Preview("Point") {
    @Previewable @State var start: TimeInterval = 71
    @Previewable @State var end: TimeInterval? = nil
    MarkerRangeEditor(start: $start, end: $end, duration: 245, playhead: 0)
        .padding()
}
