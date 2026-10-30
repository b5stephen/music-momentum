//
//  WindowActions.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// What the Mac's menus can ask of the window around Practice, published by
/// `MacWindow` as a focused scene value.
struct WindowActions {
    var canPickSong = false
    /// A song picker is up; its search field is for typing.
    var isSheetOpen = false
    var changeSong: @MainActor () -> Void = {}
    var addSong: @MainActor () -> Void = {}
}

extension FocusedValues {
    @Entry var windowActions: WindowActions?
}
#endif
