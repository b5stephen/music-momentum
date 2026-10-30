//
//  PracticeActions.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// What the Mac's menus can ask of Practice, published by the window's
/// `PracticeView` as a focused scene value so `MacCommands` never holds a
/// player of its own: every closure ends at `RootTabView`'s one
/// `PlaybackController`. The flags say which items can act.
struct PracticeActions {
    var hasSong = false
    var hasDuration = false
    var isPlaying = false
    var isLoopOn = false
    var canSaveSpeed = false
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
    var saveSpeed: @MainActor () -> Void = {}
    var loopClip: @MainActor (_ number: Int) -> Void = { _ in }
    var zoomIn: @MainActor () -> Void = {}
    var zoomOut: @MainActor () -> Void = {}
    var zoomToFit: @MainActor () -> Void = {}
}

extension FocusedValues {
    @Entry var practiceActions: PracticeActions?
}
#endif
