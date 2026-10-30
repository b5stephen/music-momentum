//
//  TimelineOverview.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

/// The whole song drawn small, as the iOS lane draws it, with a box over the
/// part the timeline shows. Drag the box to pan, drag its edges to zoom, click
/// outside it to centre the view there. Only there while zoom is worth
/// offering.
struct TimelineOverview: View {
    let markers: [PlaybackScrubber.Marker]
    let duration: TimeInterval
    @Binding var viewport: TimelineViewport

    static let height: CGFloat = 14

    private static let edgeZone: CGFloat = 6

    private enum Grab {
        case pan(startOffset: TimeInterval)
        case edge(TimelineViewport.Edge)
    }

    @State private var grab: Grab?
    @State private var pointerX: CGFloat?
    @State private var isPushed = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(.primary.opacity(0.12))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity)
                ForEach(markers) { marker in
                    mark(marker, width: width)
                }
                box(width: width)
            }
            .frame(width: width, height: Self.height, alignment: .topLeading)
            .contentShape(.rect)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location): pointerX = location.x
                case .ended: pointerX = nil
                }
                syncCursor(width: width)
            }
            .gesture(drag(width: width))
            .onDisappear {
                pointerX = nil
                syncCursor(width: width)
            }
        }
        .frame(height: Self.height)
        .help("Drag to scroll; drag an edge to zoom")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timeline overview")
        .accessibilityValue(Text(visibleDescription))
    }

    private var visibleDescription: String {
        let range = viewport.visible(duration: duration)
        return "\(PlaybackScrubber.timeLabel(range.lowerBound)) to \(PlaybackScrubber.timeLabel(range.upperBound))"
    }

    // MARK: Drawing

    @ViewBuilder
    private func mark(_ marker: PlaybackScrubber.Marker, width: CGFloat) -> some View {
        let x = TimelineViewport.x(for: marker.start, width: width, in: 0...duration)
        if let end = marker.end {
            let right = TimelineViewport.x(for: end, width: width, in: 0...duration)
            let barWidth = max(4, right - x)
            Capsule()
                .fill(marker.isLooping ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(0.35)))
                .frame(width: barWidth, height: 4)
                .offset(x: min(max(0, x), width - barWidth), y: (Self.height - 4) / 2)
        } else {
            Circle()
                .fill(.primary.opacity(0.7))
                .frame(width: 6, height: 6)
                .offset(x: min(max(0, x - 3), width - 6), y: (Self.height - 6) / 2)
        }
    }

    private func boxFrame(width: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let range = viewport.visible(duration: duration)
        let left = TimelineViewport.x(for: range.lowerBound, width: width, in: 0...duration)
        let right = TimelineViewport.x(for: range.upperBound, width: width, in: 0...duration)
        return (left, max(right - left, 8))
    }

    private func box(width: CGFloat) -> some View {
        let frame = boxFrame(width: width)
        return RoundedRectangle(cornerRadius: 5)
            .fill(.primary.opacity(0.10))
            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.55), lineWidth: 1) }
            .frame(width: frame.width, height: Self.height)
            .offset(x: frame.x)
            .allowsHitTesting(false)
    }

    // MARK: Input

    private func edge(at x: CGFloat, width: CGFloat) -> TimelineViewport.Edge? {
        let frame = boxFrame(width: width)
        let zone = min(Self.edgeZone, frame.width / 3)
        if abs(x - frame.x) <= zone { return .leading }
        if abs(x - (frame.x + frame.width)) <= zone { return .trailing }
        return nil
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard width > 0, duration > 0 else { return }
                let time = TimelineViewport.time(atX: value.location.x, width: width, in: 0...duration)
                if grab == nil {
                    let frame = boxFrame(width: width)
                    if viewport.isZoomed, let edge = edge(at: value.startLocation.x, width: width) {
                        grab = .edge(edge)
                    } else if viewport.isZoomed, value.startLocation.x >= frame.x, value.startLocation.x <= frame.x + frame.width {
                        let start = viewport.visible(duration: duration).lowerBound
                        grab = .pan(startOffset: start - TimelineViewport.time(atX: value.startLocation.x, width: width, in: 0...duration))
                    } else {
                        // A click outside centres the view there, and a drag from
                        // it carries on from that spot.
                        viewport.center(on: TimelineViewport.time(atX: value.startLocation.x, width: width, in: 0...duration), duration: duration)
                        let start = viewport.visible(duration: duration).lowerBound
                        grab = .pan(startOffset: start - TimelineViewport.time(atX: value.startLocation.x, width: width, in: 0...duration))
                    }
                    syncCursor(width: width)
                }
                switch grab {
                case .pan(let startOffset): viewport.move(to: time + startOffset, duration: duration)
                case .edge(let edge): viewport.resize(edge, to: time, duration: duration)
                case nil: break
                }
            }
            .onEnded { _ in
                grab = nil
                syncCursor(width: width)
            }
    }

    /// The left-right pointer over the box's edges, and through a drag from one.
    private func syncCursor(width: CGFloat) {
        var wanted = false
        if case .edge = grab {
            wanted = true
        } else if let pointerX, viewport.isZoomed {
            wanted = edge(at: pointerX, width: width) != nil
        }
        if wanted && !isPushed {
            NSCursor.resizeLeftRight.push()
            isPushed = true
        } else if !wanted && isPushed {
            NSCursor.pop()
            isPushed = false
        }
    }
}
#endif
