//
//  WindowActions.swift
//  MusicMomentum
//

import SwiftUI

/// What the menus can ask of the window around Practice, published as a
/// focused scene value by `MacWindow`, and on iOS by `PracticeView`, which
/// presents the pickers there.
struct WindowActions {
    var canPickSong = false
    /// A song picker is up; its search field is for typing.
    var isSheetOpen = false
    var changeSong: @MainActor () -> Void = {}
    var addSong: @MainActor () -> Void = {}
}

extension FocusedValues {
    @Entry var windowActions: WindowActions?
    /// One of Saved's sheets is up on iOS, where Practice can't see it.
    @Entry var isSavedSheetOpen: Bool?
}
