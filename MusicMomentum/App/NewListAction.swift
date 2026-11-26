//
//  NewListAction.swift
//  MusicMomentum
//

import SwiftUI

/// File ▸ New List, published as a focused scene value by whichever Saved
/// screen is in front.
struct NewListAction: Equatable {
    let perform: @MainActor () -> Void

    /// Always equal, so SwiftUI keeps the first closure it was handed. That's
    /// safe only while `perform` does nothing but set `@State`, which reads
    /// through to live storage; a closure capturing a plain value would go stale.
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}
