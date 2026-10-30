//
//  LoopCaption.swift
//  MusicMomentum
//

import Foundation

/// The one line that says what is looping, for the small surfaces (the mini
/// player) that have no room for the timeline's header.
nonisolated enum LoopCaption {
    struct Clip: Equatable {
        var name: String?
        var length: TimeInterval
    }

    /// `clips` is what the loop plays; empty with the loop on is the whole song.
    static func text(isOn: Bool, clips: [Clip]) -> String {
        guard isOn else { return "Loop off" }
        switch clips.count {
        case 0:
            return "Looping whole song"
        case 1:
            return "Looping \(clips[0].name ?? "one clip") \u{00B7} \(PlaybackScrubber.timeLabel(clips[0].length))"
        default:
            let total = clips.reduce(0) { $0 + $1.length }
            return "Looping \(clips.count) clips \u{00B7} \(PlaybackScrubber.timeLabel(total))"
        }
    }
}
