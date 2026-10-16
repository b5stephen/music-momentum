//
//  VolumeSlider.swift
//  MusicMomentum
//

import AVFoundation
import MediaPlayer
import SwiftUI

/// The system volume, the same level the side buttons change, drawn like the
/// scrubber so the two read as a pair. `ApplicationMusicPlayer` plays in the
/// Music app's process and has no volume of its own, and `MPVolumeView` is
/// the only public way to set the system's. Its own slider can't be drawn
/// without a thumb: a thumb wide enough to touch pushed the fill 22pt in at
/// zero. So it sits hidden behind this track, which sets its slider.
struct VolumeSlider: View {
    var axis: Axis = .horizontal
    @State private var volume = SystemVolume()
    @State private var dragStart: Float?

    nonisolated static let trackHeight: CGFloat = 6
    private static let draggingTrackHeight: CGFloat = 12

    var body: some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: 10) {
                    quiet
                    track
                    loud
                }
            } else {
                VStack(spacing: 10) {
                    loud
                    track
                    quiet
                }
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .background(alignment: .leading) {
            SystemVolumeView(volume: volume)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
    }

    private var quiet: some View {
        Image(systemName: "speaker.fill").accessibilityHidden(true)
    }

    private var loud: some View {
        Image(systemName: "speaker.wave.3.fill").accessibilityHidden(true)
    }

    private var track: some View {
        GeometryReader { proxy in
            let isHorizontal = axis == .horizontal
            let length = isHorizontal ? proxy.size.width : proxy.size.height
            let thickness = dragStart == nil ? Self.trackHeight : Self.draggingTrackHeight
            let fill = max(thickness, length * CGFloat(volume.level))
            ZStack(alignment: isHorizontal ? .leading : .bottom) {
                Capsule()
                    .fill(.primary.opacity(0.18))
                Capsule()
                    .fill(.primary)
                    .frame(width: isHorizontal ? fill : nil, height: isHorizontal ? nil : fill)
            }
            .frame(width: isHorizontal ? nil : thickness, height: isHorizontal ? thickness : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            // Relative, never jumping to the touch: a tap near the end would
            // otherwise blast the speaker.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let start = dragStart ?? volume.level
                        dragStart = start
                        let travel = isHorizontal ? value.translation.width : -value.translation.height
                        volume.set(start + Float(travel / max(length, 1)))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .animation(.snappy(duration: 0.2), value: dragStart == nil)
        }
        .frame(width: axis == .vertical ? 44 : nil, height: axis == .horizontal ? 44 : nil)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue(Text(Double(volume.level), format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            // The side buttons' step.
            volume.set(volume.level + (direction == .increment ? 1 : -1) / 16)
        }
    }
}

@Observable
private final class SystemVolume {
    private(set) var level: Float = 0
    @ObservationIgnored weak var slider: UISlider?
    @ObservationIgnored private var observation: NSKeyValueObservation?
    @ObservationIgnored private var activation: NSObjectProtocol?

    /// `outputVolume` reads 0 and never changes for an app whose audio
    /// session isn't active, which ours never was, since the Music app does
    /// the playing. An ambient, mixable session plays nothing and leaves the
    /// Music app's playback alone. Activated again on returning to the app,
    /// in case the system deactivated it while we were away.
    init() {
        let session = AVAudioSession.sharedInstance()
        Self.activate(session)
        level = session.outputVolume
        observation = session.observe(\.outputVolume) { [weak self] session, _ in
            let level = session.outputVolume
            Task { @MainActor in self?.level = level }
        }
        activation = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            let session = AVAudioSession.sharedInstance()
            Self.activate(session)
            let level = session.outputVolume
            Task { @MainActor in self?.level = level }
        }
    }

    isolated deinit {
        if let activation { NotificationCenter.default.removeObserver(activation) }
    }

    private nonisolated static func activate(_ session: AVAudioSession) {
        try? session.setCategory(.ambient, options: .mixWithOthers)
        try? session.setActive(true)
    }

    func set(_ newLevel: Float) {
        level = min(max(newLevel, 0), 1)
        slider?.value = level
    }
}

/// Kept on screen, if invisibly: an `MPVolumeView` that's hidden or out of
/// the window neither sets the volume nor stops the system's volume HUD
/// covering the screen when the side buttons are pressed.
private struct SystemVolumeView: UIViewRepresentable {
    var volume: SystemVolume

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        volume.slider = view.subviews.lazy.compactMap { $0 as? UISlider }.first
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {}
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

#Preview("Vertical") {
    VolumeSlider(axis: .vertical)
        .frame(height: 160)
        .preferredColorScheme(.dark)
}
