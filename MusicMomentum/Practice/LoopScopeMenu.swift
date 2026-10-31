//
//  LoopScopeMenu.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

/// What's looping, as a label that opens every marker by name: Practice's
/// timeline header and the mini player's caption. It covers what the lane
/// can't (names too long for their bar, clips stacked or too short to hit)
/// and is the mini player's only way to pick a clip.
///
/// A SwiftUI menu closes on every click, so ⌘-click adds or removes a clip
/// and the menu closes anyway.
struct LoopScopeMenu<Label: View>: View {
    let controller: PlaybackController
    /// The song's markers in start order.
    let markers: [SongMarker]
    let chevronSize: CGFloat
    @ViewBuilder let label: Label

    var body: some View {
        let clips = markers.filter(\.isClip)
        let points = markers.filter { !$0.isClip }
        Menu {
            Toggle(
                "Whole song",
                isOn: Binding(
                    get: { controller.loop == .wholeSong },
                    set: { _ in controller.loopWholeSong() }
                )
            )
            .disabled(!controller.isLoopOn)

            if !clips.isEmpty {
                Section("Clips") {
                    ForEach(Array(clips.enumerated()), id: \.element.persistentModelID) { index, clip in
                        Toggle(
                            Self.title(clip, number: index < 9 ? index + 1 : nil),
                            isOn: Binding(
                                get: { controller.isLooping(clip) },
                                set: { _ in controller.choose(clip, chaining: NSEvent.modifierFlags.contains(.command)) }
                            )
                        )
                    }
                }
            }
            if !points.isEmpty {
                Section("Points") {
                    ForEach(points, id: \.persistentModelID) { point in
                        Button(Self.title(point, number: nil)) { controller.choose(point) }
                    }
                }
            }
        } label: {
            HStack(spacing: chevronSize * 0.75) {
                label
                Image(systemName: "chevron.down")
                    .font(.system(size: chevronSize, weight: .bold))
                    .opacity(0.6)
            }
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Choose what loops, or jump to a marker. \u{2318}-click a clip to add or remove it")
        .accessibilityLabel("Loop scope")
    }

    private static func title(_ marker: SongMarker, number: Int?) -> String {
        let title = "\(marker.name)  \(marker.timeLabel)"
        return number.map { "\(title)  \u{00B7}  \($0)" } ?? title
    }
}
#endif
