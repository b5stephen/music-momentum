//
//  SectionBlockLayout.swift
//  MusicMomentum
//

import CoreGraphics
import Foundation

/// Where Loop mode's section blocks sit across the row, and the reverse:
/// which block a touch is on and where a time falls. Pure, so the mapping a
/// tap or a drag turns into a loop can be tested.
nonisolated struct SectionBlockLayout: Equatable {
    /// Each section's span in the song, in order.
    let sections: [ClosedRange<TimeInterval>]
    /// Each block's span across the row, in points.
    let frames: [ClosedRange<CGFloat>]
    let gap: CGFloat

    /// Widths are proportional to length, except that no block is narrower
    /// than `minimumWidth`, so a sliver of a section stays visible and a
    /// zero-length one (two markers at one time) stays reachable.
    init(
        sections: [ClosedRange<TimeInterval>],
        width: CGFloat,
        gap: CGFloat = 4,
        minimumWidth: CGFloat = 6
    ) {
        self.sections = sections
        self.gap = gap
        let count = sections.count
        guard count > 0 else {
            frames = []
            return
        }
        let available = max(0, width - gap * CGFloat(count - 1))
        let widths = Self.widths(
            lengths: sections.map { $0.upperBound - $0.lowerBound },
            available: available,
            minimum: minimumWidth
        )
        var x: CGFloat = 0
        var frames: [ClosedRange<CGFloat>] = []
        for width in widths {
            frames.append(x...(x + width))
            x += width + gap
        }
        self.frames = frames
    }

    /// Proportional to `lengths`, with any below `minimum` raised to it and
    /// the rest sharing what's left. Equal when nothing has length or the
    /// minimums alone don't fit.
    static func widths(lengths: [TimeInterval], available: CGFloat, minimum: CGFloat) -> [CGFloat] {
        let count = lengths.count
        let total = lengths.reduce(0) { $0 + max(0, $1) }
        guard total > 0, CGFloat(count) * minimum < available else {
            return Array(repeating: available / CGFloat(max(count, 1)), count: count)
        }
        var pinned = Set<Int>()
        while true {
            let free = lengths.indices.filter { !pinned.contains($0) }
            let freeLength = free.reduce(0) { $0 + max(0, lengths[$1]) }
            let share = available - CGFloat(pinned.count) * minimum
            let newlyPinned = free.filter {
                freeLength <= 0 || share * CGFloat(max(0, lengths[$0]) / freeLength) < minimum
            }
            if newlyPinned.isEmpty {
                return lengths.indices.map {
                    pinned.contains($0) ? minimum : share * CGFloat(max(0, lengths[$0]) / freeLength)
                }
            }
            pinned.formUnion(newlyPinned)
        }
    }

    /// The block under `x`. The gap between two blocks is split down the
    /// middle, and a touch past either end goes to the end block, so a drag
    /// never falls between blocks.
    func index(at x: CGFloat) -> Int? {
        guard !frames.isEmpty else { return nil }
        return frames.firstIndex { x < $0.upperBound + gap / 2 } ?? frames.count - 1
    }

    /// Where `time` falls across the row: inside its section's block, in
    /// proportion. A boundary belongs to the section it starts.
    func x(for time: TimeInterval) -> CGFloat? {
        guard let first = sections.first, let last = sections.last else { return nil }
        let index = time >= last.upperBound
            ? sections.count - 1
            : sections.lastIndex { $0.lowerBound <= time && time < $0.upperBound }
                ?? (time < first.lowerBound ? 0 : sections.count - 1)
        return x(for: time, in: index)
    }

    private func x(for time: TimeInterval, in index: Int) -> CGFloat {
        let section = sections[index]
        let frame = frames[index]
        let length = section.upperBound - section.lowerBound
        guard length > 0 else { return frame.lowerBound }
        let fraction = min(max((time - section.lowerBound) / length, 0), 1)
        return frame.lowerBound + (frame.upperBound - frame.lowerBound) * CGFloat(fraction)
    }

    /// The part of block `index` that `loop` covers, in points; `nil` when
    /// it covers none of it. A loop made of whole sections fills its blocks.
    func activeSpan(of index: Int, loop: ClosedRange<TimeInterval>) -> ClosedRange<CGFloat>? {
        let section = sections[index]
        let lower = max(loop.lowerBound, section.lowerBound)
        let upper = min(loop.upperBound, section.upperBound)
        guard upper > lower else { return nil }
        return x(for: lower, in: index)...x(for: upper, in: index)
    }

    /// What a drag from block `from` to block `to` loops: every section
    /// between them, either way round.
    func range(from: Int, to: Int) -> ClosedRange<TimeInterval> {
        let (lower, upper) = (min(from, to), max(from, to))
        return sections[lower].lowerBound...sections[upper].upperBound
    }

    /// The run of blocks a loop is exactly made of, or `nil` when it starts
    /// or ends partway through one. The run ends at the first section ending
    /// with the loop and starts at the last one starting with it, so a
    /// zero-length section at a boundary isn't swept in.
    func blocks(matching loop: ClosedRange<TimeInterval>) -> ClosedRange<Int>? {
        let same = MarkerPlacement.sameTime
        guard let upper = sections.firstIndex(where: {
                  abs($0.upperBound - loop.upperBound) < same && $0.upperBound > $0.lowerBound
              }),
              let lower = sections[...upper].lastIndex(where: { abs($0.lowerBound - loop.lowerBound) < same })
        else { return nil }
        return lower...upper
    }

    /// "Chorus" for one block, "Verse – Chorus" for a run of them.
    static func name(of blocks: ClosedRange<Int>, names: [String]) -> String {
        blocks.lowerBound == blocks.upperBound
            ? names[blocks.lowerBound]
            : "\(names[blocks.lowerBound]) – \(names[blocks.upperBound])"
    }
}
