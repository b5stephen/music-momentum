//
//  PracticeActions.swift
//  MusicMomentum
//

import SwiftUI

/// What the menus can ask of Practice, published by the scene's
/// `PracticeView` as a focused scene value so `AppCommands` never holds a
/// player of its own: every closure ends at `RootTabView`'s one
/// `PlaybackController`. The flags say which items can act.
struct PracticeActions {
    var hasSong = false
    var hasDuration = false
    var isPlaying = false
    var isLoopOn = false
    var canSaveSpeed = false
    var speedPercent = 100
    var savedSpeedPercent: Int?
    /// A knob is on screen to type the speed into.
    var canEditSpeed = false
    /// Only the Mac's timeline zooms.
    var canZoomIn = false
    var canZoomOut = false
    /// The mini player has no marker sheet to open.
    var canMark = true
    /// Names of the first nine clips in start order, for the 1-9 items.
    var clipNames: [String] = []
    /// A marker sheet is up, and its fields are for typing.
    var isBlocked = false

    var playPause: @MainActor () -> Void = {}
    var skip: @MainActor (TimeInterval) -> Void = { _ in }
    var restart: @MainActor () -> Void = {}
    var toggleLoop: @MainActor () -> Void = {}
    var mark: @MainActor () -> Void = {}
    var stepSpeed: @MainActor (_ up: Bool) -> Void = { _ in }
    var nudgeSpeed: @MainActor (_ up: Bool) -> Void = { _ in }
    var setSpeed: @MainActor (_ percent: Int) -> Void = { _ in }
    var editSpeed: @MainActor () -> Void = {}
    var saveSpeed: @MainActor () -> Void = {}
    var loopClip: @MainActor (_ number: Int) -> Void = { _ in }
    var zoomIn: @MainActor () -> Void = {}
    var zoomOut: @MainActor () -> Void = {}
    var zoomToFit: @MainActor () -> Void = {}
}

extension FocusedValues {
    @Entry var practiceActions: PracticeActions?
}
