//
//  MarkerEditorTextTests.swift
//  MusicMomentumTests
//

import Testing
@testable import MusicMomentum

/// The sheet's caption says where the section ends; a wrong one sends the
/// user nudging the wrong marker.
@Suite("Edit Marker text")
struct MarkerEditorTextTests {
    private let others: [(time: Double, name: String)] = [(0, "Intro"), (22, "Verse"), (108, "Verse 2")]

    @Test("The section runs until the next marker")
    func runsUntil() {
        #expect(MarkerEditorView.impliedEnd(of: 72, others: others, duration: 245) == "Runs until Verse 2 at 1:48")
        #expect(MarkerEditorView.impliedEnd(of: 0, others: [(22, "Marker 2")], duration: 245) == "Runs until Marker 2 at 0:22")
    }

    @Test("Moved past a neighbour, it runs until the one after its new time")
    func movedPast() {
        #expect(MarkerEditorView.impliedEnd(of: 30, others: others, duration: 245) == "Runs until Verse 2 at 1:48")
        #expect(MarkerEditorView.impliedEnd(of: 10, others: others, duration: 245) == "Runs until Verse at 0:22")
    }

    @Test("The last marker runs to the end of the song")
    func toEnd() {
        #expect(MarkerEditorView.impliedEnd(of: 200, others: others, duration: 245) == "Runs to the end of the song")
        #expect(MarkerEditorView.impliedEnd(of: 10, others: [], duration: 245) == "Runs to the end of the song")
        #expect(MarkerEditorView.impliedEnd(of: 10, others: [(245, "Past the end")], duration: 245) == "Runs to the end of the song")
    }

    @Test("A marker at the same time isn't the end")
    func sameTime() {
        #expect(MarkerEditorView.impliedEnd(of: 22, others: others, duration: 245) == "Runs until Verse 2 at 1:48")
    }

    @Test("Preview starts a second early, never before the song")
    func previewStart() {
        #expect(MarkerEditorView.previewStart(for: 72) == 71)
        #expect(MarkerEditorView.previewStart(for: 0.4) == 0)
        #expect(MarkerEditorView.previewStart(for: 0) == 0)
    }
}
