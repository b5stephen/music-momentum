//
//  SpeedWheelPicker.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// An amp-style knob for practice speed, one haptic detent per percent.
/// Where it points is the speed: it stops dead at either limit, and the
/// scale around it lights up to the pointer. A tap on one of the scale's
/// ticks jumps straight to it.
struct SpeedWheelPicker: View {
    @Binding var speed: Double
    @Environment(\.smokedFill) private var smokedFill
    @Environment(\.colorScheme) private var colorScheme

    /// A double tap toggles between this and full speed; with none, it only
    /// ever goes to full speed.
    var savedSpeed: Double? = nil

    var diameter: CGFloat = 260

    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11

    /// Live, unrounded value during a drag. Clamped on every update, so
    /// turning past a stop is dropped and reversing responds immediately.
    @State private var dragPercent: Double?
    /// `nil` while the finger is inside the cap, where the angle is unstable.
    @State private var lastTouchAngle: Double?
    /// What the readout showed at touch-down, so a touch that ends where it
    /// began counts as a tap, while a one-percent nudge, which can move less
    /// than a tap's slop on a small knob, doesn't.
    @State private var touchDownPercent: Int?

    #if canImport(UIKit)
    private let tick = UIImpactFeedbackGenerator(style: .rigid)
    private let limit = UIImpactFeedbackGenerator(style: .medium)
    #endif

    private var geometry: SpeedKnobGeometry {
        SpeedKnobGeometry(diameter: diameter, labelSize: labelSize)
    }

    var body: some View {
        knob
            .frame(width: diameter, height: diameter)
            .contentShape(.circle)
            .gesture(rotationGesture)
            // The drag gesture has `minimumDistance: 0`, so a plain
            // `.onTapGesture` never fires. The drag a double tap also
            // triggers moves no distance and commits the value unchanged.
            .simultaneousGesture(TapGesture(count: 2).onEnded { toggleFullSpeed() })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback speed")
            .accessibilityValue("\(displayPercent) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: commit(Double(displayPercent + 1))
                case .decrement: commit(Double(displayPercent - 1))
                @unknown default: break
                }
            }
    }

    // MARK: - Knob

    private var knob: some View {
        let geometry = geometry
        return ZStack {
            // Swapped rather than redrawn, so a window dragged across a
            // detail threshold cross-fades the numbers instead of popping them.
            // Animated here alone: across the whole knob it also animated the
            // readout's new size, which its numeric transition draws as a blur.
            ZStack {
                scale(geometry)
                    .id(geometry.detail)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.2), value: geometry.detail)
            skirt(geometry)
            markings(geometry)
                .rotationEffect(SpeedKnobGeometry.angle(for: ringPercent) - .degrees(270))
                .animation(isDragging ? nil : .snappy(duration: 0.35), value: ringPercent)
            cap(geometry)
        }
    }

    /// Printed on the panel, so it stays still while the knob turns.
    private func scale(_ geometry: SpeedKnobGeometry) -> some View {
        let lit = displayPercent
        let saved = savedSpeed.map { clamp(Int(($0 * 100).rounded())) }
        return Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            for percent in stride(from: SpeedKnobGeometry.minPercent, through: SpeedKnobGeometry.maxPercent, by: geometry.tickStep) {
                let isMajor = percent.isMultiple(of: 10)
                let isLit = percent <= lit
                let angle = SpeedKnobGeometry.angle(for: Double(percent))
                var path = Path()
                path.move(to: SpeedKnobGeometry.point(from: centre, radius: geometry.tickInnerRadius, angle: angle))
                path.addLine(to: SpeedKnobGeometry.point(
                    from: centre,
                    radius: geometry.tickInnerRadius + geometry.tickLength(major: isMajor),
                    angle: angle
                ))
                context.stroke(
                    path,
                    with: isLit ? .style(.tint) : .style(HierarchicalShapeStyle.primary.opacity(0.25)),
                    style: StrokeStyle(lineWidth: isMajor ? 2.6 : 1.8, lineCap: .round)
                )

                if geometry.isLabelled(percent) {
                    let label = Text("\(percent)")
                        .font(.system(size: geometry.labelSize, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(HierarchicalShapeStyle.primary.opacity(isLit ? 0.9 : 0.45))
                    context.draw(
                        label,
                        at: SpeedKnobGeometry.point(from: centre, radius: geometry.labelRadius(major: isMajor), angle: angle)
                    )
                }
            }

            if let saved {
                let dot = SpeedKnobGeometry.point(
                    from: centre,
                    radius: geometry.savedDotRadius,
                    angle: SpeedKnobGeometry.angle(for: Double(saved))
                )
                let side: CGFloat = geometry.detail == .small ? 4.4 : 5.2
                context.fill(
                    Path(ellipseIn: CGRect(x: dot.x - side / 2, y: dot.y - side / 2, width: side, height: side)),
                    with: .style(HierarchicalShapeStyle.primary)
                )
            }
        }
    }

    /// A circle, so the glass never needs to turn; only the markings on it do.
    /// Smoked on a bright cover, where clear glass would leave the light
    /// markings on a light ground.
    private func skirt(_ geometry: SpeedKnobGeometry) -> some View {
        Circle()
            .fill(.clear)
            .frame(width: geometry.skirtRadius * 2, height: geometry.skirtRadius * 2)
            .glassEffect(smokedFill.map { Glass.regular.tint($0) } ?? .regular, in: .circle)
    }

    /// Drawn pointing up; the caller turns them to the value.
    private func markings(_ geometry: SpeedKnobGeometry) -> some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let skirt = geometry.skirtRadius
            let knurlDepth: CGFloat = geometry.detail == .full ? 10 : 7

            for index in 0..<geometry.knurlCount {
                let angle = Angle.degrees(Double(index) * 360 / Double(geometry.knurlCount))
                var path = Path()
                path.move(to: SpeedKnobGeometry.point(from: centre, radius: skirt - 1.5, angle: angle))
                path.addLine(to: SpeedKnobGeometry.point(from: centre, radius: skirt - knurlDepth, angle: angle))
                context.stroke(path, with: .style(HierarchicalShapeStyle.primary.opacity(0.18)), lineWidth: 1.1)
            }

            var pointer = Path()
            pointer.move(to: CGPoint(x: centre.x, y: centre.y - skirt + 4))
            pointer.addLine(to: CGPoint(x: centre.x, y: centre.y - geometry.capRadius - 4))
            context.stroke(
                pointer,
                with: .style(HierarchicalShapeStyle.primary),
                style: StrokeStyle(lineWidth: geometry.pointerWidth, lineCap: .round)
            )
        }
        .frame(width: geometry.skirtRadius * 2, height: geometry.skirtRadius * 2)
        .allowsHitTesting(false)
    }

    /// Still while the skirt turns, unlike a real knob's: a turning number
    /// can't be read, and the exact percent matters more than realism.
    private func cap(_ geometry: SpeedKnobGeometry) -> some View {
        let side = geometry.capRadius * 2
        let size = geometry.readoutSize
        return ZStack {
            Circle()
                .fill(.black.opacity(colorScheme == .dark ? 0.28 : 0.05))
                .overlay(Circle().strokeBorder(.primary.opacity(0.14), lineWidth: 1))

            VStack(spacing: 0) {
                if geometry.showsCaption {
                    Text("SPEED")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .kerning(1.6)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(displayPercent)")
                        .font(.system(size: size, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .animation(.snappy(duration: 0.15), value: displayPercent)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    // MARK: - Gesture

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let centre = CGPoint(x: diameter / 2, y: diameter / 2)
                let dx = value.location.x - centre.x
                let dy = value.location.y - centre.y

                guard hypot(dx, dy) > diameter * 0.18 else {
                    lastTouchAngle = nil
                    return
                }

                // Screen y grows downwards, so atan2 grows clockwise.
                let angle = atan2(dy, dx) * 180 / .pi

                guard let previous = lastTouchAngle else {
                    lastTouchAngle = angle
                    if dragPercent == nil { dragPercent = Double(currentPercent) }
                    if touchDownPercent == nil { touchDownPercent = currentPercent }
                    #if canImport(UIKit)
                    tick.prepare()
                    limit.prepare()
                    #endif
                    return
                }

                lastTouchAngle = angle
                let delta = shortestDelta(from: previous, to: angle)
                update(by: delta / SpeedKnobGeometry.degreesPerPercent)
            }
            // The tap is read here rather than by its own gesture, which could
            // end before this one and have its jump undone by the commit.
            .onEnded { value in
                let isTap = touchDownPercent == displayPercent
                    && hypot(value.translation.width, value.translation.height) < 10
                lastTouchAngle = nil
                touchDownPercent = nil
                if isTap, let target = geometry.tickPercent(at: value.startLocation) {
                    jump(to: target)
                } else if let dragPercent {
                    commit(dragPercent)
                }
                dragPercent = nil
            }
    }

    /// Wrapped into ±180 so crossing the 3 o'clock seam isn't a full turn back.
    private func shortestDelta(from previous: Double, to current: Double) -> Double {
        var delta = current - previous
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    // MARK: - Values

    private var isDragging: Bool { dragPercent != nil }

    private var currentPercent: Int { clamp(Int((speed * 100).rounded())) }

    private var displayPercent: Int {
        dragPercent.map { clamp(Int($0.rounded())) } ?? currentPercent
    }

    /// Unrounded, so the knob turns smoothly rather than stepping.
    private var ringPercent: Double { dragPercent ?? Double(currentPercent) }

    private func clamp(_ percent: Int) -> Int {
        min(max(percent, SpeedKnobGeometry.minPercent), SpeedKnobGeometry.maxPercent)
    }

    /// Clicks once per whole percent crossed and once, harder, on reaching a
    /// stop; past that the finger turns nothing.
    private func update(by amount: Double) {
        let previous = dragPercent ?? Double(currentPercent)
        let clamped = min(max(previous + amount, Double(SpeedKnobGeometry.minPercent)), Double(SpeedKnobGeometry.maxPercent))
        let before = displayPercent
        dragPercent = clamped

        #if canImport(UIKit)
        if isAtLimit(clamped), !isAtLimit(previous) {
            limit.impactOccurred()
        } else if displayPercent != before {
            tick.impactOccurred(intensity: 0.45)
        }
        #endif

        if displayPercent != before { speed = Double(displayPercent) / 100 }
    }

    private func isAtLimit(_ percent: Double) -> Bool {
        percent <= Double(SpeedKnobGeometry.minPercent) || percent >= Double(SpeedKnobGeometry.maxPercent)
    }

    private func commit(_ raw: Double) {
        let snapped = clamp(Int(raw.rounded()))
        guard snapped != currentPercent else { return }
        #if canImport(UIKit)
        tick.impactOccurred(intensity: 0.45)
        #endif
        speed = Double(snapped) / 100
    }

    /// Heads for the saved speed unless already there, in which case full
    /// speed; with nothing saved, full speed is the only destination.
    private func toggleFullSpeed() {
        let savedPercent = savedSpeed.map { clamp(Int(($0 * 100).rounded())) }
        let target: Int
        if let savedPercent, currentPercent != savedPercent {
            target = savedPercent
        } else if currentPercent != SpeedKnobGeometry.maxPercent {
            target = SpeedKnobGeometry.maxPercent
        } else {
            return
        }
        jump(to: target)
    }

    private func jump(to percent: Int) {
        dragPercent = nil
        guard percent != currentPercent else { return }
        #if canImport(UIKit)
        limit.impactOccurred()
        #endif
        speed = Double(percent) / 100
    }
}

#Preview("Phone") {
    @Previewable @State var speed = 0.7
    SpeedWheelPicker(speed: $speed, savedSpeed: 0.8)
        .padding()
}

#Preview("Sizes") {
    @Previewable @State var speed = 0.7
    VStack(spacing: 24) {
        SpeedWheelPicker(speed: $speed, savedSpeed: 0.8, diameter: 300)
        HStack(alignment: .bottom, spacing: 16) {
            SpeedWheelPicker(speed: $speed, savedSpeed: 0.8, diameter: 210)
            SpeedWheelPicker(speed: $speed, savedSpeed: 0.8, diameter: 150)
        }
    }
    .padding()
}

// The compact short window's knob, just inside the small tier, and at the
// readout's widest.
#Preview("Small, 180pt") {
    @Previewable @State var speed = 0.6
    @Previewable @State var full = 1.0
    VStack(spacing: 24) {
        SpeedWheelPicker(speed: $speed, savedSpeed: 0.6, diameter: 180)
        SpeedWheelPicker(speed: $full, diameter: 180)
    }
    .padding()
}

/// Approximates `ArtworkGround` on a dark cover: light text and tint.
#Preview("On a cover") {
    @Previewable @State var speed = 0.7
    VStack(spacing: 24) {
        SpeedWheelPicker(speed: $speed, savedSpeed: 0.8, diameter: 260)
        HStack(alignment: .bottom, spacing: 16) {
            SpeedWheelPicker(speed: $speed, savedSpeed: 0.8, diameter: 210)
            SpeedWheelPicker(speed: $speed, savedSpeed: 0.8, diameter: 150)
        }
    }
    .padding()
    .foregroundStyle(.white)
    .tint(.white)
    .environment(\.colorScheme, .dark)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(colors: [Color(red: 0.2, green: 0.26, blue: 0.3), Color(red: 0.25, green: 0.27, blue: 0.28)], startPoint: .top, endPoint: .bottom))
}
