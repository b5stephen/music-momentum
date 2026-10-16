//
//  VolumeSlider.swift
//  MusicMomentum
//

import MediaPlayer
import SwiftUI

/// The system volume, the level the side buttons set. MusicKit has no
/// volume of its own, and `MPVolumeView` is what Apple points every
/// deprecated volume API to. It keeps itself in step with the side buttons,
/// and while it's on screen the system's volume HUD stays away.
struct VolumeSlider: View {
    /// The screen's text colour; UIKit can't see SwiftUI's foreground style.
    var tint: Color?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
            slider
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var slider: some View {
        #if targetEnvironment(simulator)
        // The simulator has no output volume and `MPVolumeView` draws
        // nothing there; previews would show a gap.
        Capsule()
            .fill(.primary.opacity(0.18))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(tint ?? .primary).frame(width: proxy.size.width * 0.6)
                }
            }
            .frame(height: 6)
        #else
        SystemVolumeView(tint: tint)
        #endif
    }
}

private struct SystemVolumeView: UIViewRepresentable {
    var tint: Color?

    func makeUIView(context: Context) -> ThumblessVolumeView {
        ThumblessVolumeView()
    }

    func updateUIView(_ view: ThumblessVolumeView, context: Context) {
        view.tint = tint.map(UIColor.init) ?? .label
    }
}

/// `MPVolumeView` has no style of its own, so its slider is found and given
/// iOS 26's thumbless media style, as Apple Music's is. Should a later iOS
/// rebuild the view, the slider keeps its thumb and still works.
private final class ThumblessVolumeView: MPVolumeView {
    var tint: UIColor = .label {
        didSet { styleSlider() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        styleSlider()
    }

    private func styleSlider() {
        guard let slider = subviews.lazy.compactMap({ $0 as? UISlider }).first else { return }
        if slider.sliderStyle != .thumbless { slider.sliderStyle = .thumbless }
        // It lays its slider along its top edge, not through the middle of the row.
        slider.center.y = bounds.midY
        slider.minimumTrackTintColor = tint
        slider.maximumTrackTintColor = tint.withAlphaComponent(0.18)
    }
}

#Preview("Light") {
    VolumeSlider()
        .padding(.horizontal, 24)
}

#Preview("Dark") {
    VolumeSlider()
        .padding(.horizontal, 24)
        .preferredColorScheme(.dark)
}
