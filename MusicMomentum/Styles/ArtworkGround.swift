//
//  ArtworkGround.swift
//  MusicMomentum
//

import SwiftUI

/// Paints the loaded screen in the cover's colours. Covers without colours
/// keep the system look and the coral tint.
struct ArtworkGround: ViewModifier {
    let palette: ArtworkPalette?
    /// The mesh drifts while the song plays, as Apple Music's does, and holds
    /// still while it's paused.
    var isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = DriftClock()

    func body(content: Content) -> some View {
        if let palette {
            content
                .foregroundStyle(palette.foreground)
                .tint(palette.foreground)
                .backgroundStyle(palette.background)
                .environment(\.onAccent, palette.background)
                .environment(\.smokedFill, palette.isBright ? palette.shadow.opacity(0.24) : nil)
                .environment(\.colorScheme, .dark)
                .background { backdrop(palette) }
        } else {
            content
        }
    }

    /// Darkening from a third of the way down, as Apple Music's does,
    /// towards the cover's own colour: black greys it and turns gold olive.
    private func backdrop(_ palette: ArtworkPalette) -> some View {
        let drifts = isPlaying && !reduceMotion
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: !drifts)) { context in
            MeshGradient(
                width: 3,
                height: 3,
                points: Self.points(at: clock.time(at: context.date, running: drifts)),
                colors: palette.mesh
            )
        }
        .overlay {
            LinearGradient(
                stops: [.init(color: .clear, location: 0.35), .init(color: palette.shadow.opacity(0.55), location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Corners stay put and edge points only slide along their edge, so the
    /// mesh always covers the screen. Periods share no common factor, so the
    /// pattern doesn't visibly repeat.
    private static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        func wave(_ period: Double, _ phase: Double) -> Float {
            Float(sin(time * 2 * .pi / period + phase))
        }
        return [
            [0, 0], [0.5 + 0.15 * wave(23, 0), 0], [1, 0],
            [0, 0.5 + 0.12 * wave(19, 1)], [0.5 + 0.18 * wave(17, 2), 0.5 + 0.15 * wave(29, 3)], [1, 0.5 + 0.12 * wave(31, 4)],
            [0, 1], [0.5 + 0.15 * wave(37, 5), 1], [1, 1],
        ]
    }
}

/// Time that only passes while the song plays, so a paused mesh resumes from
/// where it stopped rather than jumping ahead.
private final class DriftClock {
    private var banked: TimeInterval = 0
    private var runningSince: Date?

    func time(at date: Date, running: Bool) -> TimeInterval {
        if running, runningSince == nil {
            runningSince = date
        } else if !running, let since = runningSince {
            banked += date.timeIntervalSince(since)
            runningSince = nil
        }
        return banked + (runningSince.map { date.timeIntervalSince($0) } ?? 0)
    }
}
