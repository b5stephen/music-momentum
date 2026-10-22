//
//  PlayerMode.swift
//  MusicMomentum
//

import Foundation

/// What the player's timeline shows: a scrubber with marker ticks, or the
/// song's sections as blocks to loop. Only the timeline changes with it; the
/// loop itself carries across.
nonisolated enum PlayerMode: String, CaseIterable, Sendable {
    case play
    case loop

    var title: String {
        switch self {
        case .play: "Play"
        case .loop: "Loop"
        }
    }
}
