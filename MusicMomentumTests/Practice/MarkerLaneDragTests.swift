//
//  MarkerLaneDragTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Foundation
import Testing
@testable import MusicMomentum

@Suite("Marker lane drag")
struct MarkerLaneDragTests {
    /// 1000pt across 200s: five points a second.
    private func time(_ x: CGFloat, fine: Bool = false, snap: [TimeInterval] = []) -> TimeInterval {
        MarkerLaneDrag.time(atX: x, width: 1000, duration: 200, fine: fine, snapTo: snap)
    }

    @Test func roundsToWholeSecondsOrTenths() {
        #expect(time(103) == 21)   // 20.6s
        #expect(time(103, fine: true) == 20.6)
        #expect(MarkerLaneDrag.rounded(20.64, fine: true) == 20.6)
    }

    @Test func clampsToTheSong() {
        #expect(time(-40) == 0)
        #expect(time(1200) == 200)
    }

    @Test func snapsWithinTolerance() {
        // 5 points a second: a point 1s (5pt) away snaps, 2s (10pt) away doesn't.
        #expect(time(105, snap: [20]) == 20)
        #expect(time(110, snap: [20]) == 22)
        #expect(MarkerLaneDrag.snapped(21, to: [20, 25], pointsPerSecond: 5) == 20)
        #expect(MarkerLaneDrag.snapped(22.5, to: [20, 25], pointsPerSecond: 5) == nil)
    }

    @Test func snapKeepsFractionalPointsAndPicksTheNearest() {
        #expect(MarkerLaneDrag.snapped(20.9, to: [20, 21.3], pointsPerSecond: 5) == 21.3)
        #expect(time(107, snap: [21.3]) == 21.3)
    }

    @Test func snapToleranceFollowsTheScale() {
        // Zoomed in tenfold, the same 1s is 50pt away: no snap.
        #expect(MarkerLaneDrag.snapped(21, to: [20], pointsPerSecond: 50) == nil)
        #expect(MarkerLaneDrag.snapped(20.1, to: [20], pointsPerSecond: 50) == 20)
        #expect(MarkerLaneDrag.snapped(21, to: [20], pointsPerSecond: 0) == nil)
    }

    @Test func dragMakesAClipEitherWay() {
        let forward = MarkerLaneDrag.clip(from: 200, to: 420, width: 1000, duration: 200, fine: false, snapTo: [])
        let backward = MarkerLaneDrag.clip(from: 420, to: 200, width: 1000, duration: 200, fine: false, snapTo: [])
        #expect(forward?.start == 40 && forward?.end == 84)
        #expect(backward?.start == 40 && backward?.end == 84)
    }

    @Test func dragEdgesSnapIndependently() {
        let clip = MarkerLaneDrag.clip(from: 202, to: 417, width: 1000, duration: 200, fine: false, snapTo: [40, 83.5])
        #expect(clip?.start == 40 && clip?.end == 83.5)
    }

    @Test func shortDragsAreClicks() {
        #expect(MarkerLaneDrag.clip(from: 200, to: 202, width: 1000, duration: 200, fine: false, snapTo: []) == nil)
        // Wide enough to count as a drag but under the shortest clip.
        #expect(MarkerLaneDrag.clip(from: 200, to: 204, width: 1000, duration: 100, fine: true, snapTo: []) == nil)
        // Both ends snapping to the same point is no clip.
        #expect(MarkerLaneDrag.clip(from: 200, to: 206, width: 1000, duration: 200, fine: false, snapTo: [41]) == nil)
    }

    @Test func dragPastTheSongEndsClamps() {
        let clip = MarkerLaneDrag.clip(from: 900, to: 1400, width: 1000, duration: 200, fine: false, snapTo: [])
        #expect(clip?.start == 180 && clip?.end == 200)
    }

    @Test func trimmingClampsToTheSong() {
        let start = MarkerLaneDrag.trim(.start, to: -5, start: 10, end: 30, duration: 100)
        #expect(start.start == 0 && start.end == 30)
        let end = MarkerLaneDrag.trim(.end, to: 130, start: 10, end: 30, duration: 100)
        #expect(end.start == 10 && end.end == 100)
    }

    @Test func trimmingKeepsTheMinimumLength() {
        let gap = SongMarker.minimumClipLength
        let start = MarkerLaneDrag.trim(.start, to: 50, start: 10, end: 30, duration: 100)
        #expect(start.start == 30 - gap && start.end == 30)
        let end = MarkerLaneDrag.trim(.end, to: 2, start: 10, end: 30, duration: 100)
        #expect(end.start == 10 && end.end == 10 + gap)
    }

    @Test func trimmingNeverCrossesEvenAtTheSongsEnd() {
        let end = MarkerLaneDrag.trim(.end, to: 0, start: 99.8, end: 100, duration: 100)
        #expect(end.start == 99.8 && end.end == 100)
        let start = MarkerLaneDrag.trim(.start, to: 100, start: 90, end: 100, duration: 100)
        #expect(start.start == 100 - SongMarker.minimumClipLength)
    }

    @Test func trimmingInRangeMovesOnlyThatEdge() {
        let moved = MarkerLaneDrag.trim(.start, to: 14.5, start: 10, end: 30, duration: 100)
        #expect(moved.start == 14.5 && moved.end == 30)
    }

    @Test func readouts() {
        #expect(MarkerLaneDrag.clipReadout(start: 100, end: 124) == "1:40 \u{2013} 2:04 \u{00B7} 0:24")
        #expect(MarkerLaneDrag.clipReadout(start: 100.5, end: 124) == "1:40.5 \u{2013} 2:04.0 \u{00B7} 0:23.5")
        #expect(MarkerLaneDrag.trimReadout(.start, start: 140, end: 180) == "Start 2:20.0 \u{00B7} 0:40")
        #expect(MarkerLaneDrag.trimReadout(.end, start: 140, end: 180.4) == "End 3:00.4 \u{00B7} 0:40.4")
    }
}
