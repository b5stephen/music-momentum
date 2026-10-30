//
//  TimelineViewportTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MusicMomentum

@Suite("Timeline viewport")
struct TimelineViewportTests {
    private let duration: TimeInterval = 240

    private func zoomed(_ factor: Double, around time: TimeInterval) -> TimelineViewport {
        var viewport = TimelineViewport()
        viewport.zoom(by: factor, around: time, duration: duration)
        return viewport
    }

    /// Zooms divide, so exact equality would trip on the last bit.
    private func expectVisible(
        _ viewport: TimelineViewport, _ expected: ClosedRange<TimeInterval>, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let range = viewport.visible(duration: duration)
        #expect(abs(range.lowerBound - expected.lowerBound) < 1e-9, sourceLocation: sourceLocation)
        #expect(abs(range.upperBound - expected.upperBound) < 1e-9, sourceLocation: sourceLocation)
    }

    private func layout(_ markers: [PlaybackScrubber.Marker], width: CGFloat = 600) -> MarkerLaneLayout {
        MarkerLaneLayout(markers: markers, duration: duration, width: width, nameWidth: { CGFloat($0.count) * 7 })
    }

    @Test func startsAsTheWholeSong() {
        let viewport = TimelineViewport()
        expectVisible(viewport, 0...240)
        #expect(!viewport.isZoomed)
    }

    @Test func zoomKeepsTheAnchorWhereItWas() {
        // The playhead a quarter of the way across stays a quarter across.
        let viewport = zoomed(4, around: 60)
        let range = viewport.visible(duration: duration)
        #expect(abs(range.upperBound - range.lowerBound - 60) < 1e-9)
        #expect(abs(range.lowerBound - 45) < 1e-9)
    }

    @Test func zoomingOutKeepsTheAnchorToo() {
        var viewport = zoomed(4, around: 60)   // 45...105
        viewport.zoom(by: 0.5, around: 75, duration: duration)   // the middle, 25% across the old view
        let range = viewport.visible(duration: duration)
        #expect(abs(range.upperBound - range.lowerBound - 120) < 1e-9)
        #expect(abs((75 - range.lowerBound) / 120 - 0.5) < 1e-9)
    }

    @Test func zoomIsHeldBetweenWholeSongAndEightSeconds() {
        let deepest = zoomed(1000, around: 100).visible(duration: duration)
        #expect(abs(deepest.upperBound - deepest.lowerBound - 8) < 1e-9)
        var viewport = zoomed(4, around: 100)
        viewport.zoom(by: 0.01, around: 100, duration: duration)
        #expect(viewport == TimelineViewport())
        #expect(viewport.canZoomIn(duration: duration))
        #expect(!zoomed(1000, around: 1).canZoomIn(duration: duration))
    }

    @Test func aShortSongNeverZooms() {
        var viewport = TimelineViewport()
        viewport.zoom(by: 8, around: 3, duration: 6)
        #expect(viewport.visible(duration: 6) == 0...6)
        #expect(!viewport.isZoomed)
    }

    @Test func zoomingAtTheSongsEndsStaysInside() {
        let atStart = zoomed(8, around: 0).visible(duration: duration)
        #expect(atStart.lowerBound == 0)
        #expect(abs(atStart.upperBound - 30) < 1e-9)
        let atEnd = zoomed(8, around: 240).visible(duration: duration)
        #expect(abs(atEnd.upperBound - 240) < 1e-9)
        #expect(abs(atEnd.lowerBound - 210) < 1e-9)
    }

    @Test func panIsClampedAtBothEnds() {
        var viewport = zoomed(4, around: 120)   // 90...150
        viewport.pan(by: 1000, duration: duration)
        expectVisible(viewport, 180...240)
        viewport.pan(by: -1000, duration: duration)
        expectVisible(viewport, 0...60)
        viewport.pan(by: 10, duration: duration)
        expectVisible(viewport, 10...70)
    }

    @Test func panDoesNothingWhenFitted() {
        var viewport = TimelineViewport()
        viewport.pan(by: 30, duration: duration)
        #expect(viewport == TimelineViewport())
    }

    @Test func fitGoesBackToTheWholeSong() {
        var viewport = zoomed(6, around: 200)
        viewport.fit()
        expectVisible(viewport, 0...240)
    }

    @Test func aShorterSongClampsAStaleViewport() {
        let viewport = zoomed(4, around: 200)   // 170...230 of a 240s song
        #expect(viewport.visible(duration: 100) == 75...100)
        #expect(viewport.visible(duration: 0) == 0...0)
    }

    @Test func centreAndShowClamp() {
        var viewport = zoomed(4, around: 120)
        viewport.center(on: 5, duration: duration)
        expectVisible(viewport, 0...60)
        viewport.show(100...130, duration: duration)
        expectVisible(viewport, 100...130)
        viewport.show(100...101, duration: duration)   // below the minimum
        expectVisible(viewport, 100...108)
        viewport.show(0...240, duration: duration)
        #expect(!viewport.isZoomed)
    }

    @Test func resizingAnEdgeLeavesTheOtherAlone() {
        var viewport = zoomed(4, around: 120)   // 90...150
        viewport.resize(.leading, to: 60, duration: duration)
        expectVisible(viewport, 60...150)
        viewport.resize(.trailing, to: 100, duration: duration)
        expectVisible(viewport, 60...100)
        viewport.resize(.trailing, to: 62, duration: duration)   // can't squeeze past the minimum
        expectVisible(viewport, 60...68)
        viewport.resize(.leading, to: 500, duration: duration)
        expectVisible(viewport, 60...68)
        viewport.resize(.leading, to: -5, duration: duration)
        #expect(viewport.visible(duration: duration).lowerBound == 0)
    }

    // MARK: Paging

    @Test func pagesWhenThePlayheadLeavesTheRightEdge() {
        var viewport = zoomed(4, around: 0)   // 0...60
        viewport.follow(playhead: 60.4, previous: 59.9, duration: duration)
        let range = viewport.visible(duration: duration)
        #expect(abs(range.lowerBound - 54.4) < 1e-9)   // a tenth of the view in from the left
    }

    @Test func doesNotPageWhileThePlayheadIsInView() {
        var viewport = zoomed(4, around: 0)
        viewport.follow(playhead: 40, previous: 39.5, duration: duration)
        expectVisible(viewport, 0...60)
    }

    @Test func pagesBackWhenALoopWrapsToBeforeTheView() {
        var viewport = zoomed(4, around: 120)   // 90...150
        viewport.pan(by: 30, duration: duration)   // 120...180
        viewport.follow(playhead: 100, previous: 125, duration: duration)
        expectVisible(viewport, 94...154)
    }

    @Test func pagingIsHeldAtTheSongsEnds() {
        var viewport = zoomed(4, around: 230)   // 180...240
        viewport.follow(playhead: 5, previous: 200, duration: duration)   // previous in view
        #expect(viewport.visible(duration: duration).lowerBound == 0)
        var end = zoomed(4, around: 0)
        end.follow(playhead: 239, previous: 30, duration: duration)
        expectVisible(end, 180...240)
    }

    @Test func aPlayheadTheUserPannedAwayFromIsLeftAlone() {
        var viewport = zoomed(4, around: 0)   // 0...60
        viewport.follow(playhead: 100.5, previous: 100, duration: duration)
        expectVisible(viewport, 0...60)
    }

    @Test func fittedViewNeverPages() {
        var viewport = TimelineViewport()
        viewport.follow(playhead: 300, previous: 10, duration: duration)
        #expect(viewport == TimelineViewport())
    }

    // MARK: Fit to a loop

    @Test func aLoopInViewLeavesTheViewAlone() {
        var viewport = zoomed(4, around: 0)
        viewport.reveal(10...30, duration: duration)
        expectVisible(viewport, 0...60)
    }

    @Test func anOffscreenLoopThatFitsIsCentredWithoutZooming() {
        var viewport = zoomed(4, around: 0)   // 0...60
        viewport.reveal(150...170, duration: duration)
        let range = viewport.visible(duration: duration)
        #expect(range.upperBound - range.lowerBound == 60)
        #expect(range == 130...190)
    }

    @Test func aLoopCrossingTheEdgeCountsAsOffscreen() {
        var viewport = zoomed(4, around: 0)
        viewport.reveal(50...70, duration: duration)
        expectVisible(viewport, 30...90)
    }

    @Test func aLoopLongerThanTheViewZoomsOutToItWithAMargin() {
        var viewport = zoomed(8, around: 0)   // 0...30
        viewport.reveal(100...160, duration: duration)   // 60s, margin 6s
        expectVisible(viewport, 94...166)
    }

    @Test func aLoopNearTheSongsEndStaysInside() {
        var viewport = zoomed(8, around: 0)
        viewport.reveal(225...240, duration: duration)
        let range = viewport.visible(duration: duration)
        #expect(abs(range.upperBound - 240) < 1e-9)
        #expect(range.contains(225))
    }

    @Test func aLoopAsLongAsTheSongFits() {
        var viewport = zoomed(8, around: 0)
        viewport.reveal(0...238, duration: duration)
        #expect(!viewport.isZoomed)
    }

    // MARK: Whether it's needed

    private let lots: [PlaybackScrubber.Marker] = (0..<12).map {
        .init(id: $0, name: "Marker number \($0)", start: TimeInterval($0) * 4, end: nil)
    }

    @Test func fewMarkersDontNeedIt() {
        let few: [PlaybackScrubber.Marker] = [
            .init(id: 1, name: "Chorus", start: 62, end: 96),
            .init(id: 2, name: "Bridge", start: 128, end: nil),
        ]
        #expect(!TimelineViewport().isNeeded(wholeSong: layout(few)))
        #expect(!TimelineViewport().isNeeded(wholeSong: layout([])))
    }

    @Test func moreThanThreeHiddenNamesNeedIt() {
        let crowded = layout(lots)
        #expect(crowded.hiddenNameCount > TimelineViewport.hiddenNameLimit)
        #expect(TimelineViewport().isNeeded(wholeSong: crowded))
    }

    @Test func threeHiddenNamesDoNot() {
        let three: [PlaybackScrubber.Marker] = (0..<3).map {
            .init(id: $0, name: "A name far too long for this", start: TimeInterval($0), end: nil)
        }
        let narrow = layout(three, width: 100)
        #expect(narrow.hiddenNameCount == 3)
        #expect(!TimelineViewport().isNeeded(wholeSong: narrow))
    }

    @Test func threeClipRowsNeedIt() {
        let stacked: [PlaybackScrubber.Marker] = (0..<3).map {
            .init(id: $0, name: "C", start: TimeInterval($0), end: 100)
        }
        let twoRows = layout(Array(stacked.prefix(2)))
        #expect(twoRows.rowCount == 2)
        #expect(!TimelineViewport().isNeeded(wholeSong: twoRows))
        let threeRows = layout(stacked)
        #expect(threeRows.rowCount == 3)
        #expect(TimelineViewport().isNeeded(wholeSong: threeRows))
    }

    @Test func beingZoomedAlwaysNeedsIt() {
        #expect(zoomed(2, around: 10).isNeeded(wholeSong: layout([])))
    }

    // MARK: Mapping

    @Test func mapsBetweenXAndTime() {
        let range: ClosedRange<TimeInterval> = 100...140
        #expect(TimelineViewport.time(atX: 0, width: 400, in: range) == 100)
        #expect(TimelineViewport.time(atX: 100, width: 400, in: range) == 110)
        #expect(TimelineViewport.time(atX: 900, width: 400, in: range) == 140)
        #expect(TimelineViewport.time(atX: -5, width: 400, in: range) == 100)
        #expect(TimelineViewport.x(for: 120, width: 400, in: range) == 200)
        #expect(TimelineViewport.x(for: 90, width: 400, in: range) == -100)
    }
}
