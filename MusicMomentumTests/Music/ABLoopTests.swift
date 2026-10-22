//
//  ABLoopTests.swift
//  MusicMomentumTests
//

import Foundation
import SwiftData
import Testing
@testable import MusicMomentum

/// A wrong time here loops the wrong bars or leaves a marker where the user
/// didn't tap, so the A·B flow is tested without the player.
@Suite("A·B times")
struct ABLoopTimeTests {
    private let pre = MarkerPlacement.startPreRoll
    private let post = MarkerPlacement.endPostRoll

    @Test("The button goes idle, A set, looping, with a pending A winning")
    func phases() {
        #expect(ABLoop.phase(pendingA: nil, isLooping: false) == .idle)
        #expect(ABLoop.phase(pendingA: 12, isLooping: false) == .aSet(tapped: 12))
        #expect(ABLoop.phase(pendingA: nil, isLooping: true) == .looping)
        #expect(ABLoop.phase(pendingA: 12, isLooping: true) == .aSet(tapped: 12))
    }

    @Test("A moves earlier and B later, and both get markers away from any")
    func preRoll() throws {
        let closing = try #require(ABLoop.close(a: 30, b: 40, duration: 145, markers: [0, 90]))
        #expect(abs(closing.start - (30 - pre)) < 1e-9)
        #expect(abs(closing.end - (40 + post)) < 1e-9)
        #expect(closing.newMarkers.count == 2)
        #expect(closing.newMarkers == [closing.start, closing.end])
    }

    @Test("Ends near a marker snap to it and need no new one")
    func snaps() throws {
        let closing = try #require(ABLoop.close(a: 58.4, b: 95.5, duration: 145, markers: [22, 58, 96]))
        #expect(closing.start == 58)
        #expect(closing.end == 96)
        #expect(closing.newMarkers.isEmpty)
    }

    @Test("Ends near the song's start or end snap there without a marker")
    func songEnds() throws {
        let closing = try #require(ABLoop.close(a: 0.6, b: 144.5, duration: 145, markers: []))
        #expect(closing.start == 0)
        #expect(closing.end == 145)
        #expect(closing.newMarkers.isEmpty)
    }

    @Test("Pre-roll stops at the song's ends")
    func clamps() throws {
        let closing = try #require(ABLoop.close(a: 0.1, b: 144.9, duration: 145, markers: [20, 100]))
        #expect(closing.start == 0)
        #expect(closing.end == 145)
    }

    @Test("B behind A, after a seek back, loops between them")
    func swapped() throws {
        let closing = try #require(ABLoop.close(a: 40, b: 30, duration: 145, markers: []))
        #expect(abs(closing.start - (30 - pre)) < 1e-9)
        #expect(abs(closing.end - (40 + post)) < 1e-9)
    }

    @Test("Ends snapping onto one marker leave A set")
    func degenerate() {
        #expect(ABLoop.close(a: 58, b: 58.1, duration: 145, markers: [58]) == nil)
    }

    @Test("A tap close to a marker still leaves room for B's own")
    func endClearOfNewStart() throws {
        // B snaps nowhere, but must sit far enough from A's new marker that
        // adding it can't snap back onto A.
        let closing = try #require(ABLoop.close(a: 10, b: 10, duration: 145, markers: []))
        #expect(closing.end - closing.start >= MarkerPlacement.snapThreshold)
    }

    @Test("A free end nudges within the song and short of the other end")
    func nudgeFree() {
        let step = ABLoop.nudgeStep
        #expect(ABLoop.nudged(.start, of: 0...30, by: -step, duration: 145) == nil)
        #expect(ABLoop.nudged(.start, of: 0...30, by: step, duration: 145) == step)
        #expect(ABLoop.nudged(.end, of: 100...145, by: step, duration: 145) == nil)
        #expect(ABLoop.nudged(.end, of: 100...145, by: -step, duration: 145) == 145 - step)
        let tight = 10...(10 + MarkerPlacement.minimumNudgedSection)
        #expect(ABLoop.nudged(.start, of: tight, by: step, duration: 145) == nil)
        #expect(ABLoop.nudged(.end, of: tight, by: -step, duration: 145) == nil)
    }

    @Test("Split on a marker goes a nudge short of it; between markers, right there")
    func splitTime() {
        #expect(ABLoop.splitTime(of: 58...96, markers: [58, 96], duration: 145) == 96 - ABLoop.nudgeStep)
        #expect(ABLoop.splitTime(of: 112...145, markers: [112], duration: 145) == 145 - ABLoop.nudgeStep)
        #expect(ABLoop.splitTime(of: 58...80, markers: [58, 96], duration: 145) == 80)
        #expect(ABLoop.splitTime(of: 58...58.05, markers: [58, 58.05], duration: 145) == nil)
    }
}

@MainActor
@Suite("A·B on a song's markers")
struct ABLoopMarkerTests {
    private let context: ModelContext
    private let song: SavedSong

    init() throws {
        context = ModelContext(try AppSchema.inMemoryContainer())
        song = SavedSong.save(
            songID: "i.1", title: "Little Wing", artistName: "Jimi Hendrix",
            artworkData: nil, speed: 0.6, in: context
        )
        for time in [0.0, 22, 58, 96, 112] {
            SongMarker.add(to: song, at: time, in: context)
        }
    }

    private var times: [TimeInterval] { song.sortedMarkers.map(\.startTime) }

    @Test("Closing away from markers adds one at each end and reports them")
    func closeAdds() throws {
        let closed = try #require(ABLoop.close(a: 70, b: 80, duration: 145, song: song, in: context))
        #expect(closed.created.count == 2)
        #expect(closed.created.map(\.startTime) == [closed.loop.lowerBound, closed.loop.upperBound])
        #expect(times.count == 7)
        #expect(times.contains(closed.loop.lowerBound) && times.contains(closed.loop.upperBound))
    }

    @Test("Closing on markers reuses them and creates nothing")
    func closeReuses() throws {
        let closed = try #require(ABLoop.close(a: 58.3, b: 95.8, duration: 145, song: song, in: context))
        #expect(closed.loop == 58...96)
        #expect(closed.created.isEmpty)
        #expect(times == [0, 22, 58, 96, 112])
    }

    @Test("Without a saved song it still loops")
    func closeUnsaved() throws {
        let closed = try #require(ABLoop.close(a: 70, b: 80, duration: 145, song: nil, in: nil))
        #expect(closed.created.isEmpty)
        #expect(times.count == 5)
    }

    @Test("Nudging B moves the shared marker, so the next section starts there too, and the loop follows")
    func nudgeShared() throws {
        let loop = try #require(ABLoop.nudge(.end, of: 58...96, by: -0.1, duration: 145, song: song, in: context))
        #expect(abs(loop.upperBound - 95.9) < 1e-9)
        #expect(loop.lowerBound == 58)
        #expect(times.contains(loop.upperBound))
        #expect(!times.contains(96))
        let sections = song.sections(duration: 145)
        #expect(sections.contains { $0.start == loop.upperBound && $0.end == 112 })
    }

    @Test("Nudging A moves the previous section's end with it")
    func nudgeStart() throws {
        let loop = try #require(ABLoop.nudge(.start, of: 58...96, by: 0.1, duration: 145, song: song, in: context))
        #expect(abs(loop.lowerBound - 58.1) < 1e-9)
        #expect(song.sections(duration: 145).contains { $0.start == 22 && $0.end == loop.lowerBound })
    }

    @Test("A marker held by its neighbour leaves the loop where it is")
    func nudgeHeld() throws {
        SongMarker.add(to: song, at: 96.1, in: context)
        let loop = try #require(ABLoop.nudge(.end, of: 58...96, by: 0.1, duration: 145, song: song, in: context))
        #expect(loop == 58...96)
    }

    @Test("Nudging the song's end moves the loop alone")
    func nudgeSongEnd() throws {
        let loop = try #require(ABLoop.nudge(.end, of: 112...145, by: -0.1, duration: 145, song: song, in: context))
        #expect(abs(loop.upperBound - 144.9) < 1e-9)
        #expect(times == [0, 22, 58, 96, 112])
    }

    @Test("Split gives B its own marker; then nudging B leaves the next section's start alone")
    func splitThenNudge() throws {
        let split = try #require(ABLoop.split(58...96, duration: 145, song: song, in: context))
        let created = try #require(split.created)
        #expect(abs(split.loop.upperBound - 95.9) < 1e-9)
        #expect(created.startTime == split.loop.upperBound)
        #expect(times.contains(96))

        let nudged = try #require(ABLoop.nudge(.end, of: split.loop, by: -0.1, duration: 145, song: song, in: context))
        #expect(abs(nudged.upperBound - 95.8) < 1e-9)
        #expect(times.contains(96))
        // The gap between B and Verse 2 is a section of its own.
        #expect(song.sections(duration: 145).contains { abs($0.start - nudged.upperBound) < 1e-9 && $0.end == 96 })
    }
}

/// Saving a marker at a new time in the Edit Marker sheet must carry a loop
/// that ends on it, or the loop keeps playing bars the marker no longer bounds.
@Suite("A loop following an edited marker")
struct ABLoopFollowingTests {
    @Test("A loop starting on the marker starts where it went")
    func start() {
        #expect(ABLoop.following(58...96, markerMovedFrom: 58, to: 60.5) == 60.5...96)
    }

    @Test("A loop ending on the marker ends where it went")
    func end() {
        #expect(ABLoop.following(58...96, markerMovedFrom: 96, to: 94) == 58...94)
    }

    @Test("A loop the marker doesn't bound, or a marker that didn't move, leaves it alone")
    func untouched() {
        #expect(ABLoop.following(58...96, markerMovedFrom: 22, to: 30) == nil)
        #expect(ABLoop.following(58...96, markerMovedFrom: 58, to: 58) == nil)
    }

    @Test("Moving an end past the other leaves the loop where it was")
    func inverted() {
        #expect(ABLoop.following(58...96, markerMovedFrom: 58, to: 100) == nil)
        #expect(ABLoop.following(58...96, markerMovedFrom: 96, to: 58.05) == nil)
    }
}
