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
///
/// While A·B waits for B, the stretch from A to the playhead is shaded under
/// an A tab. While looping, A and B tabs sit over the loop's ends, and the
/// caption becomes nudge controls for them; holding the B tab offers "Split
/// Here".
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
    /// A·B's A, with pre-roll, while it waits for B.
    var pendingA: TimeInterval? = nil
    /// ◀ ▶ under a loop; without it the caption stays as it is.
    var onNudge: ((ABLoop.End, TimeInterval) -> Void)? = nil
    var onSplit: (() -> Void)? = nil

    /// The blocks a finger is on: where it landed and where it is now.
    @State private var drag: (anchor: Int, current: Int)?
    @State private var holdTask: Task<Void, Never>?
    @State private var isHolding = false
    @State private var hasMoved = false
    /// A hold that opens the Edit Marker sheet has its touch cancelled by
    /// the presentation, so `onEnded` never runs; without this the next
    /// touch only cleared the hold and a tap on the blocks did nothing.
    @GestureState private var isTouching = false

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
                    .onChange(of: isTouching) { _, touching in
                        guard !touching, isHolding else { return }
                        isHolding = false
                        drag = nil
                        hasMoved = false
                    }
                    .overlay(alignment: .topLeading) { accessibilityBlocks(layout) }
                    .overlay(alignment: .topLeading) { tabs(layout, width: proxy.size.width) }
            }
            .frame(height: Self.rowHeight)

            if let loop, let onNudge, pendingA == nil {
                nudgeRow(loop, onNudge: onNudge)
            } else {
                caption
            }
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
                    .fill(.primary.opacity(ArtworkPalette.inactiveInk))
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

            if let pendingA, let a = layout.x(for: pendingA), let x = layout.x(for: position) {
                Rectangle()
                    .fill(.primary.opacity(0.5))
                    .frame(width: abs(x - a), height: Self.blockHeight)
                    .offset(x: min(a, x), y: Self.blockTop)
                Capsule()
                    .fill(.primary)
                    .frame(width: 2, height: Self.blockHeight + 4)
                    .offset(x: a - 1, y: Self.blockTop - 2)
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

    // MARK: - A and B

    private static let tabSize = CGSize(width: 18, height: 16)

    /// Above the blocks, in the room the row leaves for them.
    @ViewBuilder
    private func tabs(_ layout: SectionBlockLayout, width: CGFloat) -> some View {
        if let pendingA, let a = layout.x(for: pendingA) {
            tab("A")
                .offset(tabOrigin(a, width: width))
                .allowsHitTesting(false)
        } else if let loop, drag == nil,
                  let a = layout.x(for: loop.lowerBound), let b = layout.x(for: loop.upperBound) {
            let slack = CGSize(width: (44 - Self.tabSize.width) / 2, height: 6)
            let origin = tabOrigin(b, width: width)
            ZStack(alignment: .topLeading) {
                tab("A")
                    .offset(tabOrigin(a, width: width))
                    .allowsHitTesting(false)
                tab("B")
                    .padding(.horizontal, slack.width)
                    .padding(.vertical, slack.height)
                    .contentShape(.interaction, .rect)
                    .contentShape(.contextMenuPreview, .rect(cornerRadius: 8))
                    .contextMenu {
                        if let onSplit {
                            Button("Split Here", systemImage: "scissors", action: onSplit)
                        }
                    }
                    .offset(x: origin.width - slack.width, y: origin.height - slack.height)
                    .allowsHitTesting(onSplit != nil)
            }
        }
    }

    private func tab(_ letter: String) -> some View {
        Text(letter)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.background)
            .frame(width: Self.tabSize.width, height: Self.tabSize.height)
            .background(.primary, in: .rect(cornerRadius: 4))
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityHidden(true)
    }

    /// Kept inside the row, so a tab over the song's first or last moment
    /// doesn't hang off the edge.
    private func tabOrigin(_ x: CGFloat, width: CGFloat) -> CGSize {
        CGSize(
            width: min(max(0, x - Self.tabSize.width / 2), max(0, width - Self.tabSize.width)),
            height: Self.blockTop - Self.tabSize.height - 2
        )
    }

    // MARK: - Caption

    /// The playhead and the time left either side, as Play mode has, with
    /// what's looping (or would be, mid-drag) between them.
    private var caption: some View {
        HStack {
            if let pendingA {
                Text("A \(PlaybackScrubber.timeLabel(pendingA))")
            } else {
                Text(PlaybackScrubber.timeLabel(position))
            }
            Spacer()
            if pendingA != nil {
                Text(PlaybackScrubber.timeLabel(position))
            } else if let duration {
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
        if pendingA != nil { return ("Tap B to close the loop", false) }
        let names = blocks.map(\.name)
        if let drag, hasMoved, !isHolding {
            let run = min(drag.anchor, drag.current)...max(drag.anchor, drag.current)
            return (SectionBlockLayout.name(of: run, names: names), true)
        }
        guard let loop else {
            return (blocks.count > 1 ? "Tap a section to loop it" : "Tap to loop the song", false)
        }
        return (loopName(loop), true)
    }

    /// "Chorus", "Verse – Chorus", or the times for a loop that isn't made
    /// of whole sections.
    private func loopName(_ loop: ClosedRange<TimeInterval>) -> String {
        let layout = SectionBlockLayout(sections: blocks.map(\.range), width: 1)
        let names = blocks.map(\.name)
        if let run = layout.blocks(matching: loop) {
            let isWholeSong = run == 0...(blocks.count - 1)
            return isWholeSong ? "Whole song" : SectionBlockLayout.name(of: run, names: names)
        }
        return "\(PlaybackScrubber.timeLabel(loop.lowerBound)) – \(PlaybackScrubber.timeLabel(loop.upperBound))"
    }

    // MARK: - Nudging

    /// ◀ A ▶ · what's looping · ◀ B ▶. Tenths, so a 0.1 s nudge shows. The
    /// arrows' touch areas reach past the caption line to 44pt.
    private func nudgeRow(
        _ loop: ClosedRange<TimeInterval>,
        onNudge: @escaping (ABLoop.End, TimeInterval) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            nudgeControl(.start, letter: "A", time: loop.lowerBound, onNudge: onNudge)
            Text(loopName(loop))
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)
            nudgeControl(.end, letter: "B", time: loop.upperBound, onNudge: onNudge)
        }
        .font(.caption.monospacedDigit())
    }

    private func nudgeControl(
        _ end: ABLoop.End,
        letter: String,
        time: TimeInterval,
        onNudge: @escaping (ABLoop.End, TimeInterval) -> Void
    ) -> some View {
        let name = end == .start ? "Loop start" : "Loop end"
        return HStack(spacing: 0) {
            nudgeArrow("chevron.left", label: "\(name) earlier") { onNudge(end, -ABLoop.nudgeStep) }
            Text("\(letter) \(PreciseTime.format(time))")
                .fontWeight(.semibold)
                .fixedSize()
                .accessibilityElement()
                .accessibilityLabel(name)
                .accessibilityValue(PreciseTime.format(time))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: onNudge(end, ABLoop.nudgeStep)
                    case .decrement: onNudge(end, -ABLoop.nudgeStep)
                    @unknown default: break
                    }
                }
                .accessibilityActions {
                    if end == .end, let onSplit {
                        Button("Split Here", action: onSplit)
                    }
                }
            nudgeArrow("chevron.right", label: "\(name) later") { onNudge(end, ABLoop.nudgeStep) }
        }
        .foregroundStyle(.primary)
    }

    private func nudgeArrow(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 16)
                .contentShape(.rect.inset(by: -14))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Touch

    private func gesture(_ layout: SectionBlockLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isTouching) { _, touching, _ in touching = true }
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

#Preview("A set") {
    SectionBlocks(blocks: previewBlocks, position: 84, duration: 145, loop: nil, onTap: { _ in }, onDrag: { _ in }, pendingA: 62)
        .padding(.horizontal, 24)
}

#Preview("Looping, with nudges") {
    SectionBlocks(
        blocks: previewBlocks, position: 70, duration: 145, loop: 58...96,
        onTap: { _ in }, onDrag: { _ in }, onNudge: { _, _ in }, onSplit: {}
    )
    .padding(.horizontal, 24)
}

#Preview("Looping the last section, with nudges") {
    SectionBlocks(
        blocks: previewBlocks, position: 120, duration: 145, loop: 112...145,
        onTap: { _ in }, onDrag: { _ in }, onNudge: { _, _ in }, onSplit: {}
    )
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
