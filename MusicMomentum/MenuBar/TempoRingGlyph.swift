//
//  TempoRingGlyph.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftUI

/// The menu bar's mark: a faint full ring, a lit arc running up from the
/// lower left round towards the right (a speed dial a little under full), and
/// a dot at the centre. Drawn in the shapes of a 24pt grid, so it scales.
struct TempoRingGlyph: View {
    /// How much of the 270° sweep, lower left to lower right, is lit.
    private static let lit = 0.75

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 24
            let center = CGPoint(x: 12 * unit, y: 12 * unit)
            let radius = 8.5 * unit
            let round = StrokeStyle(lineWidth: 2.2 * unit, lineCap: .round)

            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)),
                with: .color(.primary.opacity(0.35)),
                lineWidth: 2 * unit
            )

            // Screen angles run clockwise from 3 o'clock; the lower left is 135°.
            var arc = Path()
            arc.addArc(
                center: center, radius: radius,
                startAngle: .degrees(135), endAngle: .degrees(135 + 270 * Self.lit),
                clockwise: false
            )
            context.stroke(arc, with: .color(.primary), style: round)

            let dot = 2.2 * unit
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: 2 * dot, height: 2 * dot)),
                with: .color(.primary)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// For the menu bar, which wants a template image: only its alpha is
    /// used, so the system draws it in the bar's own colour, light or dark.
    @MainActor
    static var menuBarImage: NSImage {
        let renderer = ImageRenderer(content: TempoRingGlyph().frame(width: 18, height: 18).foregroundStyle(.black))
        renderer.scale = 3
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}

#Preview("Glyph", traits: .fixedLayout(width: 240, height: 120)) {
    HStack(spacing: 28) {
        TempoRingGlyph().frame(width: 72, height: 72)
        // As the bar shows it: the template image, at its own size.
        Image(nsImage: TempoRingGlyph.menuBarImage)
            .padding(8)
            .background(.black.opacity(0.1), in: .rect(cornerRadius: 6))
    }
    .padding()
}
#endif
