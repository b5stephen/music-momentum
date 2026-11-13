//
//  MarkTiming.swift
//  MusicMomentum
//

import Foundation

nonisolated enum MarkTiming {
    /// Seconds of listening time between hearing the spot and pressing Mark.
    /// It is listening time, not song time, so it scales with the playback
    /// rate: at 75% speed the song moves 0.2625s in 0.35s of listening.
    static let reactionAllowance: TimeInterval = 0.35
    static let repeatWindow: TimeInterval = 1

    static func time(playhead: TimeInterval, rate: Double, isPlaying: Bool, duration: TimeInterval) -> TimeInterval {
        let raw = isPlaying ? playhead - reactionAllowance * rate : playhead
        return min(max(raw, 0), max(0, duration))
    }

    static func isRepeat(at now: Date, lastMark: Date?) -> Bool {
        guard let lastMark else { return false }
        let elapsed = now.timeIntervalSince(lastMark)
        return elapsed >= 0 && elapsed < repeatWindow
    }
}
