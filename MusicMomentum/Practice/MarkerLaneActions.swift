//
//  MarkerLaneActions.swift
//  MusicMomentum
//

#if os(macOS)
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
}
#endif
