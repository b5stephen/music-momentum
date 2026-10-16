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
///
/// Styled only through its own image setters. Its slider is a private
/// subclass: forced into iOS 26's thumbless style it couldn't be dragged
/// back up from zero, and centring it by hand came undone whenever it laid
/// itself out again.
struct VolumeSlider: View {
    /// The screen's text colour; UIKit can't see SwiftUI's foreground style.
    var tint: Color?

    static let trackHeight: CGFloat = 6
    /// Small, like the scrubber's playhead rather than the system's glass
    /// thumb, which outweighed the scrubber.
    static let dotSide: CGFloat = 14
    /// The thumb image's transparent square, so the dot is easy to catch.
    static let thumbSide: CGFloat = 28

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
        GeometryReader { proxy in
            let travel = proxy.size.width - Self.thumbSide
            let x = Self.thumbSide / 2 + travel * 0.6
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.18))
                    .frame(height: Self.trackHeight)
                Capsule().fill(tint ?? .primary)
                    .frame(width: x, height: Self.trackHeight)
                Circle().fill(tint ?? .primary)
                    .frame(width: Self.dotSide, height: Self.dotSide)
                    .offset(x: x - Self.dotSide / 2)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Self.thumbSide)
        #else
        SystemVolumeView(tint: tint)
        #endif
    }
}

private struct SystemVolumeView: UIViewRepresentable {
    var tint: Color?

    func makeUIView(context: Context) -> MPVolumeView {
        MPVolumeView()
    }

    final class Coordinator {
        var color: UIColor?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        let traits = UITraitCollection(userInterfaceStyle: context.environment.colorScheme == .dark ? .dark : .light)
        let color = (tint.map(UIColor.init) ?? .label).resolvedColor(with: traits)
        // Playback redraws the screen many times a second; the images only
        // change with the colour.
        guard color != context.coordinator.color else { return }
        context.coordinator.color = color
        view.setMinimumVolumeSliderImage(Self.track(color), for: .normal)
        view.setMaximumVolumeSliderImage(Self.track(color.withAlphaComponent(0.18)), for: .normal)
        let thumb = Self.thumb(color)
        view.setVolumeThumbImage(thumb, for: .normal)
        view.setVolumeThumbImage(thumb, for: .highlighted)
    }

    /// Its own height, so the row centres the whole view rather than
    /// stretching it, which left the slider along its top edge.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MPVolumeView, context: Context) -> CGSize? {
        let width = proposal.width ?? 200
        return CGSize(width: width, height: uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }

    private static func track(_ color: UIColor) -> UIImage {
        let side = VolumeSlider.trackHeight
        let image = UIGraphicsImageRenderer(size: CGSize(width: side + 1, height: side)).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side + 1, height: side), cornerRadius: side / 2).fill()
        }
        let cap = side / 2
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: cap, bottom: 0, right: cap))
    }

    private static func thumb(_ color: UIColor) -> UIImage {
        let side = VolumeSlider.thumbSide
        let dot = VolumeSlider.dotSide
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            color.setFill()
            UIBezierPath(ovalIn: CGRect(x: (side - dot) / 2, y: (side - dot) / 2, width: dot, height: dot)).fill()
        }
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
