//
//  PlaybackScrubber.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Position bar with the markers drawn on it. Only commits a seek on release
/// — one per gesture, not sixty — so the audio doesn't stutter while dragging.
struct PlaybackScrubber: View {
    let position: TimeInterval
    /// Inert when `nil`.
    let duration: TimeInterval?
    var markers: [Marker] = []
    /// Song time a point's name stays up after the playhead crosses it.
    var pointNameDuration: TimeInterval = 3
    var onScrub: (TimeInterval) -> Void = { _ in }
    var onCommit: (TimeInterval) -> Void

    nonisolated struct Marker: Identifiable {
        let id: AnyHashable
        var name: String = ""
        let start: TimeInterval
        let end: TimeInterval?
        var isLooping: Bool = false

        var isClip: Bool { end != nil }
    }

    /// What the bar draws while a finger is down, so the thumb never snaps
    /// back to a stale playhead before the player catches up.
    @State private var dragPosition: TimeInterval?

    private var isDragging: Bool { dragPosition != nil }
    private var displayedPosition: TimeInterval { dragPosition ?? position }

    private var fraction: Double {
        guard let duration, duration > 0 else { return 0 }
        return min(max(displayedPosition / duration, 0), 1)
    }

    var body: some View {
        // The bar's 44pt is touch area around the lane and the track, so the
        // labels tuck up under the track rather than under the touch area.
        VStack(spacing: -4) {
            bar
            labels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(Text([Self.timeLabel(displayedPosition), sectionName].compactMap(\.self).joined(separator: ", ")))
        .accessibilityAdjustableAction { direction in
            guard duration != nil else { return }
            let step: TimeInterval = direction == .increment ? 5 : -5
            onCommit(displayedPosition + step)
        }
    }

    private static let laneHeight: CGFloat = 8
    private static let laneGap: CGFloat = 4
    /// The track's height while a finger is down; it sits in a slot this
    /// tall either way, so growing doesn't nudge the lane above it.
    private static let draggingTrackHeight: CGFloat = 12

    /// Markers get a lane of their own above the track. Drawn on the track
    /// they fought the played fill: a clip at track height read as buffering,
    /// and a looping one needed a halo to survive being played past.
    private var bar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let trackHeight: CGFloat = isDragging ? Self.draggingTrackHeight : 6

            VStack(spacing: Self.laneGap) {
                markerLane(width: width)
                    .frame(height: Self.laneHeight)

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
            }
            .overlay(alignment: .topLeading) { playhead(width: width, trackHeight: trackHeight) }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(dragGesture(width: width))
            .animation(.snappy(duration: 0.2), value: isDragging)
            .animation(.snappy(duration: 0.2), value: markers.isEmpty)
        }
        .frame(height: 44)
        .disabled(duration == nil)
    }

    /// The looping clip is solid; the rest are translucent, as the pills'
    /// fills are.
    @ViewBuilder
    private func markerLane(width: CGFloat) -> some View {
        if let duration, duration > 0 {
            ZStack(alignment: .leading) {
                ForEach(markers) { marker in
                    let x = width * min(max(marker.start / duration, 0), 1)
                    if let end = marker.end {
                        let span = width * min(max((end - marker.start) / duration, 0), 1)
                        Capsule()
                            .fill(marker.isLooping ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(0.35)))
                            .frame(width: max(Self.laneHeight, span), height: Self.laneHeight)
                            .offset(x: min(x, width - max(Self.laneHeight, span)))
                    } else {
                        Circle()
                            .fill(.primary.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .offset(x: min(max(0, x - 3), width - 6))
                    }
                }
            }
            .frame(width: width, alignment: .leading)
            .allowsHitTesting(false)
        } else {
            Color.clear
        }
    }

    /// A hairline through the lane and the track, so you can see where you
    /// are against a clip. Without markers it's hidden: crossing an empty
    /// lane, it sat high above the track and the bar looked off-centre.
    private func playhead(width: CGFloat, trackHeight: CGFloat) -> some View {
        let overhang: CGFloat = 2
        let trackBottom = Self.laneHeight + Self.laneGap + (Self.draggingTrackHeight + trackHeight) / 2
        return Capsule()
            .fill(.primary.opacity(0.8))
            .frame(width: 1.5, height: trackBottom + 2 * overhang)
            .offset(x: min(max(0, width * fraction - 0.75), max(0, width - 1.5)), y: -overhang)
            .allowsHitTesting(false)
            .opacity(duration == nil || markers.isEmpty ? 0 : 1)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let duration, duration > 0, width > 0 else { return }
                if dragPosition == nil {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                }
                let time = duration * min(max(value.location.x / width, 0), 1)
                dragPosition = time
                onScrub(time)
            }
            .onEnded { _ in
                guard let time = dragPosition else { return }
                dragPosition = nil
                onCommit(time)
            }
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
