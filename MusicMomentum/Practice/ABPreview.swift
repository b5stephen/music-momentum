//
//  ABPreview.swift
//  MusicMomentum
//

import Foundation

/// A·B part way through, on a 4-minute sample song.
enum ABPreview {
    case started, looping, ghost

    @MainActor
    func apply(to controller: PlaybackController) {
        controller.sampleDuration = 238
        switch self {
        case .started:
            controller.startAB(at: 76)
            controller.seek(to: 84)
        case .looping:
            controller.restoreAB(76..<87, looping: true)
            controller.seek(to: 81)
        case .ghost:
            controller.restoreAB(76..<87, looping: false)
            controller.seek(to: 98)
        }
    }
}
