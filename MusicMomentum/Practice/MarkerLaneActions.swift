//
//  MarkerLaneActions.swift
//  MusicMomentum
//

#if os(macOS)
import Foundation

/// What the Mac lane can ask for. The lane draws and reports; Practice owns
/// the loop and the model, so every meaning lives there.
struct MarkerLaneActions {
    /// A click on a clip; `chaining` is ⌘-click.
    var clip: (PlaybackScrubber.Marker, _ chaining: Bool) -> Void = { _, _ in }
    var point: (PlaybackScrubber.Marker) -> Void = { _ in }
    /// Jump to the start whatever the loop is doing: ⌥-click and the menu.
    var jump: (PlaybackScrubber.Marker) -> Void = { _ in }
    /// A new name. Blank keeps the old one, so the lane can pass the field's
    /// text straight through.
    var rename: (PlaybackScrubber.Marker, String) -> Void = { _, _ in }
    var editTimes: (PlaybackScrubber.Marker) -> Void = { _ in }
    var makePoint: (PlaybackScrubber.Marker) -> Void = { _ in }
    var delete: (PlaybackScrubber.Marker) -> Void = { _ in }
    /// A clip dragged out in the lane, named or not. Blank takes the default.
    var createClip: (_ name: String, _ start: TimeInterval, _ end: TimeInterval) -> Void = { _, _, _ in }
    /// A clip's edge is being dragged: where its bounds are now, for the loop
    /// to follow. Nothing is saved.
    var trimming: (PlaybackScrubber.Marker, _ start: TimeInterval, _ end: TimeInterval) -> Void = { _, _, _ in }
    /// The drag ended: save these bounds.
    var trimmed: (PlaybackScrubber.Marker, _ start: TimeInterval, _ end: TimeInterval) -> Void = { _, _, _ in }
}
#endif
