//
//  PlaybackController+Surfaces.swift
//  MusicMomentum
//

/// What the Mac's mini player and menu bar ask of the controller, so they
/// share the lane's rules rather than each restating them.
extension PlaybackController {
    /// The lane's click rule, for every surface that lists markers: with the
    /// loop on, narrow it to this clip, or with `chaining` add it to the chain
    /// or take it out; otherwise only jump to its start, since only the Loop
    /// button turns looping on.
    func choose(_ marker: SongMarker, chaining: Bool = false) {
        guard isLoopOn, marker.isClip else {
            jump(to: marker)
            return
        }
        if chaining {
            toggleLoop(for: marker)
        } else {
            loop(only: marker)
        }
    }

    /// The clip the previous or next button goes to, if there is one.
    func clip(_ direction: ClipStep.Direction, in clips: [SongMarker]) -> SongMarker? {
        let index = ClipStep.target(
            starts: clips.map(\.startTime),
            loop: (loop?.segments ?? []).map { $0.start..<$0.end },
            playhead: playbackTime,
            direction: direction
        )
        return index.map { clips[$0] }
    }

    /// ±5% for the speed keys and menu items, landing on the 5% grid.
    func stepSpeed(up: Bool) {
        let percent = Int((playbackRate * 100).rounded())
        let range = SpeedKnobGeometry.minPercent...SpeedKnobGeometry.maxPercent
        playbackRate = Double(SpeedInput.stepped(from: percent, up: up, in: range)) / 100
    }
}
