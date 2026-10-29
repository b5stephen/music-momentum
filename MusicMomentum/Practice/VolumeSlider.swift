//
//  VolumeSlider.swift
//  MusicMomentum
//

#if canImport(UIKit)
import MediaPlayer
#endif
import SwiftUI

/// The system volume, the level the side buttons set. MusicKit has no
/// volume of its own, and `MPVolumeView` is what Apple points every
/// deprecated volume API to. It keeps itself in step with the side buttons,
/// and while it's on screen the system's volume HUD stays away.
///
/// The native slider, tinted and centred through `MPVolumeView`'s own API
/// and nothing else. Its slider is a private subclass: forced into iOS 26's
/// thumbless style it couldn't be dragged back up from zero, and both a
/// hand-centred slider and one sized to the view's own height still sat
/// above the speaker icons.
struct VolumeSlider: View {
    /// The screen's text colour; UIKit can't see SwiftUI's foreground style.
    var tint: Color?

    var body: some View {
        #if os(macOS)
        // The Mac has no `MPVolumeView`, and MusicKit no volume to set.
        Color.clear
        #else
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
            slider
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        #endif
    }

    #if canImport(UIKit)
    @ViewBuilder
    private var slider: some View {
        #if targetEnvironment(simulator)
        // The simulator has no output volume and `MPVolumeView` draws
        // nothing there; previews would show a gap.
        Slider(value: .constant(0.6))
            .tint(tint ?? .primary)
        #else
        SystemVolumeView(tint: tint)
        #endif
    }
    #endif
}

#if canImport(UIKit)
private struct SystemVolumeView: UIViewRepresentable {
    var tint: Color?

    func makeUIView(context: Context) -> CentredVolumeView {
        CentredVolumeView()
    }

    func updateUIView(_ view: CentredVolumeView, context: Context) {
        // Neutral, not the accent: volume isn't a state.
        view.tintColor = tint.map(UIColor.init) ?? .label
    }
}

/// Left to itself, `MPVolumeView` puts its slider along its top edge.
private final class CentredVolumeView: MPVolumeView {
    override func volumeSliderRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.volumeSliderRect(forBounds: bounds)
        rect.origin.y = bounds.midY - rect.height / 2
        return rect
    }
}
#endif

#Preview("Light") {
    VolumeSlider()
        .padding(.horizontal, 24)
}

#Preview("Dark") {
    VolumeSlider()
        .padding(.horizontal, 24)
        .preferredColorScheme(.dark)
}
