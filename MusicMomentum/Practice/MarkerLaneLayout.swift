//
//  MarkerLaneLayout.swift
//  MusicMomentum
//

import CoreGraphics
import Foundation

/// Where the Mac timeline's markers go: points on a row of their own, clips
/// stacked below like calendar events. Pure, so the collision rules can be
/// tested without a view. Name widths come in as a closure because only the
/// view can measure text.
nonisolated struct MarkerLaneLayout: Equatable {
    struct Point: Equatable, Identifiable {
        let id: AnyHashable
        /// The dot's centre.
        let x: CGFloat
        let showsName: Bool
    }

    struct Clip: Equatable, Identifiable {
        let id: AnyHashable
        let x: CGFloat
        let width: CGFloat
        /// 0...2.
        let row: Int
        let showsName: Bool
        /// Not on the top row, so it gets a ring to keep its edges readable
        /// against the clip above.
        let isStacked: Bool
    }

    var points: [Point]
    var clips: [Clip]
    var height: CGFloat
    /// Whether the song has any points at all, in view or not, so a zoomed
    /// lane keeps its clips where the whole-song lane has them.
    var hasPointRow: Bool

    static let pointRowHeight: CGFloat = 18
    /// A point row's height plus the gap under it.
    static let pointBand: CGFloat = 26
    static let clipHeight: CGFloat = 24
    static let rowPitch: CGFloat = 28
    static let maxRows = 3
    /// Clear space between two clips sharing a row.
    static let clipGap: CGFloat = 3
    static let minClipWidth: CGFloat = 6
    /// Room for the whole name inside a bar: its padding on both sides.
    static let clipNamePadding: CGFloat = 14
    /// From a point's centre to where its name starts, and the clear space
    /// kept before whatever comes next.
    static let pointNameOffset: CGFloat = 12
    static let pointNameGap: CGFloat = 8

    /// The lane keeps one row's height with nothing in it, so loading a song
    /// never moves Practice.
    static func height(hasPoints: Bool, rows: Int) -> CGFloat {
        (hasPoints ? pointBand : 0) + CGFloat(max(1, rows)) * rowPitch - (rowPitch - clipHeight)
    }

    /// `visible` defaults to the whole song; anything outside it is left out,
    /// and a clip crossing its edge is cut to it.
    init(
        markers: [PlaybackScrubber.Marker],
        duration: TimeInterval,
        width: CGFloat,
        visible: ClosedRange<TimeInterval>? = nil,
        nameWidth: (String) -> CGFloat
    ) {
        let range = visible ?? 0...duration
        let span = range.upperBound - range.lowerBound
        guard duration > 0, width > 0, span > 0 else {
            self.init(points: [], clips: [], height: Self.height(hasPoints: false, rows: 1), hasPointRow: false)
            return
        }
        func x(_ time: TimeInterval) -> CGFloat { width * (time - range.lowerBound) / span }

        let ordered = markers.enumerated().sorted {
            ($0.element.start, $0.offset) < ($1.element.start, $1.offset)
        }.map(\.element)

        let hasPointRow = ordered.contains { !$0.isClip }
        let pointMarkers = ordered.filter { !$0.isClip && range.contains($0.start) }
        let points = pointMarkers.enumerated().map { index, marker in
            let px = x(marker.start)
            let next = index + 1 < pointMarkers.count ? x(pointMarkers[index + 1].start) : width
            let fits = !marker.name.isEmpty
                && px + Self.pointNameOffset + nameWidth(marker.name) <= next - Self.pointNameGap
            return Point(id: marker.id, x: px, showsName: fits)
        }

        var rowEnds: [CGFloat] = []
        var clips: [Clip] = []
        for marker in ordered {
            guard let end = marker.end, end > range.lowerBound, marker.start < range.upperBound else { continue }
            let left = max(0, x(marker.start))
            let right = min(width, x(end))
            let barWidth = min(max(Self.minClipWidth, right - left), width)
            let barX = min(left, width - barWidth)

            var row = rowEnds.firstIndex { $0 + Self.clipGap <= barX } ?? rowEnds.count
            if row >= Self.maxRows { row = Self.maxRows - 1 }
            if row == rowEnds.count {
                rowEnds.append(barX + barWidth)
            } else {
                rowEnds[row] = max(rowEnds[row], barX + barWidth)
            }
            let fits = !marker.name.isEmpty && barWidth >= nameWidth(marker.name) + Self.clipNamePadding
            clips.append(Clip(id: marker.id, x: barX, width: barWidth, row: row, showsName: fits, isStacked: row > 0))
        }

        self.init(
            points: points,
            clips: clips,
            height: Self.height(hasPoints: hasPointRow, rows: rowEnds.count),
            hasPointRow: hasPointRow
        )
    }

    private init(points: [Point], clips: [Clip], height: CGFloat, hasPointRow: Bool) {
        self.points = points
        self.clips = clips
        self.height = height
        self.hasPointRow = hasPointRow
    }

    /// Names the lane had to leave out.
    var hiddenNameCount: Int {
        points.filter { !$0.showsName }.count + clips.filter { !$0.showsName }.count
    }

    /// Clip rows in use.
    var rowCount: Int { (clips.map(\.row).max() ?? -1) + 1 }

    /// Where a row's bars start, below the point row if there is one.
    func top(ofRow row: Int) -> CGFloat {
        (hasPointRow ? Self.pointBand : 0) + CGFloat(row) * Self.rowPitch
    }
}
