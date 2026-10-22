//
//  SectionBlocks.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Loop mode's timeline: the song's sections as a row of blocks, as wide as
/// they are long. A tap loops a block, or stops it if it's the one looping;
/// a drag across several loops them together; holding one opens its marker.
/// The loop itself is the caller's, so it survives the row being rebuilt.
struct SectionBlocks: View {
    struct Block: Identifiable {
        let id: AnyHashable
        let range: ClosedRange<TimeInterval>
        /// "Chorus", or "Marker 3" for an unnamed marker, for the caption
        /// and VoiceOver.
        let name: String
        /// Whether a marker opens it, so holding it has something to edit:
        /// not the stretch before the first marker, or a song without any.
        var isEditable = true
    }

    let blocks: [Block]
    let position: TimeInterval
    /// Inert when `nil`.
    let duration: TimeInterval?
    /// What's looping, the whole song as its full range; `nil` when nothing is.
    let loop: ClosedRange<TimeInterval>?
    var onTap: (ClosedRange<TimeInterval>) -> Void
    var onDrag: (ClosedRange<TimeInterval>) -> Void
    var onHold: ((Block) -> Void)?

    /// The blocks a finger is on: where it landed and where it is now.
    @State private var drag: (anchor: Int, current: Int)?
    @State private var holdTask: Task<Void, Never>?
    @State private var isHolding = false
    @State private var hasMoved = false

    private static let blockHeight: CGFloat = 24
    /// The row stops 4pt short of the scrubber's bar, as that bar's times
    /// tuck 4pt up under it, so the two timelines are the same height.
    private static let rowHeight = PlaybackScrubber.barHeight - 4
    /// As low as the caption allows: near the scrubber's track, so the two
    /// timelines read as one place on the screen, with the room above for
    /// the A and B tabs.
    private static let blockTop = rowHeight - blockHeight - 2
    private static let cornerRadius: CGFloat = 6
    private static let gap: CGFloat = 4
    private static let tapSlop: CGFloat = 6
    private static let holdDelay: Duration = .milliseconds(500)

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let layout = SectionBlockLayout(
                    sections: blocks.map(\.range),
                    width: proxy.size.width,
                    gap: Self.gap
                )
                row(layout)
                    // The blocks are drawn offset into the row; the touch
                    // area is the whole row, not the stack they offset from.
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(.rect)
                    .gesture(gesture(layout))
                    .overlay(alignment: .topLeading) { accessibilityBlocks(layout) }
            }
            .frame(height: Self.rowHeight)

            caption
        }
        .disabled(duration == nil)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Drawing

    /// Inactive blocks are translucent and the looping part solid: state is
    /// fill, as everywhere on the player.
    private func row(_ layout: SectionBlockLayout) -> some View {
        let active = activeRange(layout)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, _ in
                let frame = layout.frames[index]
                let width = frame.upperBound - frame.lowerBound
                let lit = active.flatMap { layout.activeSpan(of: index, loop: $0) }
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(.primary.opacity(0.22))
                    .overlay(alignment: .leading) {
                        if let lit {
                            Rectangle()
                                .fill(.primary)
                                .frame(width: lit.upperBound - lit.lowerBound)
                                .offset(x: lit.lowerBound - frame.lowerBound)
                        }
                    }
                    .clipShape(.rect(cornerRadius: Self.cornerRadius))
                    .frame(width: width, height: Self.blockHeight)
                    .offset(x: frame.lowerBound, y: Self.blockTop)
            }

            if duration != nil, let x = layout.x(for: position) {
                // Dark on a lit block, light on the rest, so it shows on both.
                let onLit = active?.contains(position) ?? false
                Capsule()
                    .fill(onLit ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                    .frame(width: 2, height: Self.blockHeight - 10)
                    .offset(x: x - 1, y: Self.blockTop + 5)
            }
        }
        .animation(.snappy(duration: 0.2), value: active)
    }

    /// While a finger is down, the blocks it would loop; otherwise the loop.
    private func activeRange(_ layout: SectionBlockLayout) -> ClosedRange<TimeInterval>? {
        if let drag, !isHolding, hasMoved {
            return layout.range(from: drag.anchor, to: drag.current)
        }
        return loop
    }

    // MARK: - Caption

    /// The playhead and the time left either side, as Play mode has, with
    /// what's looping (or would be, mid-drag) between them.
    private var caption: some View {
        HStack {
            Text(PlaybackScrubber.timeLabel(position))
            Spacer()
            if let duration {
                Text("-" + PlaybackScrubber.timeLabel(max(0, duration - position)))
            }
        }
        .foregroundStyle(.secondary)
        .overlay {
            Text(captionText.text)
                .fontWeight(captionText.isName ? .semibold : .regular)
                .foregroundStyle(captionText.isName ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .padding(.horizontal, 60)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: captionText.text)
        }
        .font(.caption.monospacedDigit())
        .accessibilityElement(children: .combine)
    }

    private var captionText: (text: String, isName: Bool) {
        let layout = SectionBlockLayout(sections: blocks.map(\.range), width: 1)
        let names = blocks.map(\.name)
        if let drag, hasMoved, !isHolding {
            let run = min(drag.anchor, drag.current)...max(drag.anchor, drag.current)
            return (SectionBlockLayout.name(of: run, names: names), true)
        }
        guard let loop else {
            return (blocks.count > 1 ? "Tap a section to loop it" : "Tap to loop the song", false)
        }
        if let run = layout.blocks(matching: loop) {
            let isWholeSong = run == 0...(blocks.count - 1)
            return (isWholeSong ? "Whole song" : SectionBlockLayout.name(of: run, names: names), true)
        }
        return ("\(PlaybackScrubber.timeLabel(loop.lowerBound)) – \(PlaybackScrubber.timeLabel(loop.upperBound))", true)
    }

    // MARK: - Touch

    private func gesture(_ layout: SectionBlockLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isHolding, let current = layout.index(at: value.location.x) else { return }
                guard let drag else {
                    guard let anchor = layout.index(at: value.startLocation.x) else { return }
                    self.drag = (anchor, anchor)
                    hasMoved = false
                    startHold(on: anchor)
                    return
                }
                if !hasMoved, hypot(value.translation.width, value.translation.height) > Self.tapSlop {
                    hasMoved = true
                    holdTask?.cancel()
                }
                if current != drag.current {
                    self.drag?.current = current
                    #if canImport(UIKit)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                }
            }
            .onEnded { _ in
                holdTask?.cancel()
                defer {
                    drag = nil
                    hasMoved = false
                    isHolding = false
                }
                guard let drag, !isHolding else { return }
                let range = layout.range(from: drag.anchor, to: drag.current)
                if hasMoved {
                    onDrag(range)
                } else {
                    onTap(range)
                }
            }
    }

    private func startHold(on index: Int) {
        holdTask?.cancel()
        guard let onHold, blocks[index].isEditable else { return }
        holdTask = Task {
            try? await Task.sleep(for: Self.holdDelay)
            guard !Task.isCancelled, !hasMoved else { return }
            isHolding = true
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onHold(blocks[index])
        }
    }

    // MARK: - VoiceOver

    /// One element per block over the row. A drag can't be done by
    /// VoiceOver, so a block outside a loop of whole sections offers to
    /// stretch the loop to it instead.
    private func accessibilityBlocks(_ layout: SectionBlockLayout) -> some View {
        let run = loop.flatMap { layout.blocks(matching: $0) }
        return ZStack(alignment: .topLeading) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                let frame = layout.frames[index]
                let isLooping = run?.contains(index) ?? false
                Color.clear
                    .frame(width: max(1, frame.upperBound - frame.lowerBound), height: Self.rowHeight)
                    .offset(x: frame.lowerBound)
                    .accessibilityElement()
                    .accessibilityLabel("\(block.name), \(PlaybackScrubber.timeLabel(block.range.lowerBound)) to \(PlaybackScrubber.timeLabel(block.range.upperBound))")
                    .accessibilityValue(isLooping ? "Looping" : "")
                    .accessibilityAddTraits(isLooping ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint(isLooping && run?.count == 1 ? "Stops looping" : "Loops this section")
                    .accessibilityAction { onTap(block.range) }
                    .accessibilityActions {
                        if let run, !run.contains(index) {
                            Button("Extend Loop to Here") {
                                onDrag(layout.range(from: index < run.lowerBound ? run.upperBound : run.lowerBound, to: index))
                            }
                        }
                        if let onHold, block.isEditable {
                            Button("Edit Marker") { onHold(block) }
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

private let previewBlocks: [SectionBlocks.Block] = [
    .init(id: 0, range: 0...22, name: "Intro"),
    .init(id: 1, range: 22...58, name: "Verse"),
    .init(id: 2, range: 58...96, name: "Chorus"),
    .init(id: 3, range: 96...112, name: "Solo"),
    .init(id: 4, range: 112...145, name: "Outro"),
]

#Preview("Idle") {
    SectionBlocks(blocks: previewBlocks, position: 41, duration: 145, loop: nil, onTap: { _ in }, onDrag: { _ in })
        .padding(.horizontal, 24)
}

#Preview("Looping one section") {
    SectionBlocks(blocks: previewBlocks, position: 70, duration: 145, loop: 58...96, onTap: { _ in }, onDrag: { _ in })
        .padding(.horizontal, 24)
}

#Preview("Looping two sections") {
    SectionBlocks(blocks: previewBlocks, position: 41, duration: 145, loop: 22...96, onTap: { _ in }, onDrag: { _ in })
        .padding(.horizontal, 24)
}

#Preview("No markers") {
    SectionBlocks(
        blocks: [.init(id: 0, range: 0...145, name: "Whole song", isEditable: false)],
        position: 41, duration: 145, loop: nil, onTap: { _ in }, onDrag: { _ in }
    )
    .padding(.horizontal, 24)
}
