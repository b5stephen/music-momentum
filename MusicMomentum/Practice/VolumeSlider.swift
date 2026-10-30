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
/// and while it's on screen the system's volume HUD stays away. The Mac has
/// no `MPVolumeView`, so there it's a plain slider on `SystemVolume`.
///
/// The native slider, tinted and centred through `MPVolumeView`'s own API
/// and nothing else. Its slider is a private subclass: forced into iOS 26's
/// thumbless style it couldn't be dragged back up from zero, and both a
/// hand-centred slider and one sized to the view's own height still sat
/// above the speaker icons.
struct VolumeSlider: View {
    /// The screen's text colour; UIKit can't see SwiftUI's foreground style.
    var tint: Color?
    #if os(macOS)
    /// Left out, rather than disabled, on an output with no software volume.
    var hidesWhenFixed = false
    /// Made on appear: `@State` evaluates its initial value on every init,
    /// and each one would register CoreAudio listeners.
    @State private var volume: SystemVolume?
    #endif

    var body: some View {
        #if os(macOS)
        if hidesWhenFixed, volume?.isSettable == false { EmptyView() } else { content }
        #else
        content
        #endif
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
            slider
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        #if os(macOS)
        .onAppear { if volume == nil { volume = SystemVolume() } }
        #endif
    }

    @ViewBuilder
    private var slider: some View {
        #if os(macOS)
        Slider(
            value: Binding(
                get: { Double(volume?.level ?? 0) },
                set: { volume?.set(Float($0)) }
            )
        )
        .tint(tint ?? .primary)
        .disabled(volume?.isSettable != true)
        .accessibilityLabel("Volume")
        #elseif targetEnvironment(simulator)
        // The simulator has no output volume and `MPVolumeView` draws
        // nothing there; previews would show a gap.
        Slider(value: .constant(0.6))
            .tint(tint ?? .primary)
        #else
        SystemVolumeView(tint: tint)
        #endif
    }
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
