//
//  MarkerLaneLayoutTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MusicMomentum

@Suite("Marker lane layout")
struct MarkerLaneLayoutTests {
    private typealias Marker = PlaybackScrubber.Marker

    /// 10pt a character, and 100s across 1000pt, so a second is 10pt.
    private func layout(
        _ markers: [Marker],
        visible: ClosedRange<TimeInterval>? = nil,
        width: CGFloat = 1000
    ) -> MarkerLaneLayout {
        MarkerLaneLayout(
            markers: markers, duration: 100, width: width, visible: visible, nameWidth: { CGFloat($0.count) * 10 }
        )
    }

    private func clip(_ name: String, _ start: TimeInterval, _ end: TimeInterval) -> Marker {
        .init(id: name, name: name, start: start, end: end)
    }

    private func point(_ name: String, _ start: TimeInterval) -> Marker {
        .init(id: name, name: name, start: start, end: nil)
    }

    // MARK: Height

    @Test("An empty lane keeps one row's height")
    func emptyHeight() {
        let empty = layout([])
        #expect(empty.height == 24)
        #expect(empty.points.isEmpty && empty.clips.isEmpty)
    }

    @Test("A lane that can't draw yet keeps one row's height too")
    func unmeasured() {
        let none = MarkerLaneLayout(markers: [clip("A", 0, 10)], duration: 0, width: 500, nameWidth: { _ in 0 })
        #expect(none.height == 24)
        #expect(layout([clip("A", 0, 10)], width: 0).height == 24)
    }

    @Test("Clips alone are one row tall until they stack")
    func clipHeights() {
        #expect(layout([clip("A", 0, 10)]).height == 24)
        #expect(layout([clip("A", 0, 10), clip("B", 5, 15)]).height == 52)
        #expect(layout([clip("A", 0, 10), clip("B", 5, 15), clip("C", 6, 16)]).height == 80)
    }

    @Test("Points add their own row on top, only when there are any")
    func pointRow() {
        #expect(layout([point("P", 10)]).height == 50)
        #expect(layout([point("P", 10), clip("A", 0, 10)]).height == 50)
        let both = layout([point("P", 10), clip("A", 0, 10), clip("B", 5, 15)])
        #expect(both.height == 78)
        #expect(both.top(ofRow: 0) == 26)
        #expect(both.top(ofRow: 1) == 54)
    }

    // MARK: Clip rows

    @Test("Overlapping clips stack, and a clip drops into the first row that is free")
    func stacking() {
        let rows = layout([clip("A", 0, 20), clip("B", 10, 30), clip("C", 25, 40)]).clips
        #expect(rows.map(\.row) == [0, 1, 0])
        #expect(rows.map(\.isStacked) == [false, true, false])
    }

    @Test("Clips butted end to end need the gap to share a row")
    func gap() {
        // A ends at x=200; 3pt of clear space is required.
        #expect(layout([clip("A", 0, 20), clip("B", 20, 30)]).clips.map(\.row) == [0, 1])
        #expect(layout([clip("A", 0, 20), clip("B", 20.5, 30)]).clips.map(\.row) == [0, 0])
        #expect(layout([clip("A", 0, 20), clip("B", 20.2, 30)]).clips.map(\.row) == [0, 1])
    }

    @Test("Rows are capped at three and the rest share the last")
    func cap() {
        let rows = layout((0..<6).map { clip("C\($0)", TimeInterval($0), 50) }).clips
        #expect(rows.map(\.row) == [0, 1, 2, 2, 2, 2])
        #expect(layout((0..<6).map { clip("C\($0)", TimeInterval($0), 50) }).height == 80)
    }

    @Test("Input order doesn't matter")
    func unsorted() {
        let rows = layout([clip("B", 10, 30), clip("A", 0, 20)]).clips
        #expect(rows.map { "\($0.id)" } == ["A", "B"])
        #expect(rows.map(\.row) == [0, 1])
    }

    @Test("A clip's position and width follow the time scale")
    func geometry() {
        let bar = layout([clip("Chorus", 10, 30)]).clips[0]
        #expect(bar.x == 100 && bar.width == 200)
    }

    @Test("Clips are never narrower than 6pt, and stay inside the lane")
    func minimumWidth() {
        let bars = layout([clip("Tiny", 10, 10.1), clip("End", 99.95, 100)]).clips
        #expect(bars[0].width == 6)
        #expect(bars[1].width == 6)
        #expect(bars[1].x == 994)
    }

    // MARK: Clip names

    @Test("A clip shows its name only when the whole name plus padding fits")
    func clipNames() {
        // "Chorus" is 60pt, and needs 74.
        #expect(layout([clip("Chorus", 0, 7.5)]).clips[0].showsName)
        #expect(!layout([clip("Chorus", 0, 7.3)]).clips[0].showsName)
    }

    @Test("A nameless clip is a bare bar")
    func unnamed() {
        #expect(!layout([clip("", 0, 50)]).clips[0].showsName)
    }

    // MARK: Points

    @Test("A point's name shows when it fits before the next point")
    func pointNames() {
        // "Verse" is 50pt: it starts 12pt past the dot and wants 8pt clear.
        // A point at x=100 fits it by a next point at 170 or beyond.
        let roomy = layout([point("Verse", 10), point("Next", 17)]).points
        #expect(roomy[0].showsName)
        let tight = layout([point("Verse", 10), point("Next", 16.9)]).points
        #expect(!tight[0].showsName)
        #expect(tight[0].x == 100)
    }

    @Test("The last point's name has the lane's end to fit before")
    func lastPoint() {
        #expect(layout([point("Outro", 90)]).points[0].showsName)
        #expect(!layout([point("Outro", 94)]).points[0].showsName)
    }

    @Test("Clips don't crowd a point's name")
    func clipsIgnored() {
        #expect(layout([point("Verse", 10), clip("Solo", 11, 12)]).points[0].showsName)
    }

    // MARK: Zoom

    @Test("A visible range rescales, drops what is outside and cuts what crosses its edge")
    func visibleRange() {
        let lane = layout(
            [point("Early", 5), point("In", 30), clip("Before", 0, 20), clip("Across", 40, 70), clip("After", 80, 90)],
            visible: 25...50
        )
        #expect(lane.points.map { "\($0.id)" } == ["In"])
        #expect(lane.points[0].x == 200)
        #expect(lane.clips.map { "\($0.id)" } == ["Across"])
        #expect(lane.clips[0].x == 600)
        #expect(lane.clips[0].width == 400)
    }

    @Test("Zooming in can make a name fit that didn't")
    func zoomShowsNames() {
        let marker = clip("Chorus", 10, 15)
        #expect(!layout([marker]).clips[0].showsName)
        #expect(layout([marker], visible: 0...25).clips[0].showsName)
    }
}
