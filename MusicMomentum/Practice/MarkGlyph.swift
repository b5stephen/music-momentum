//
//  MarkGlyph.swift
//  MusicMomentum
//

import SwiftUI

/// The pills' point dot with a plus, so the button reads as "another one of
/// these". No SF Symbol says "put a mark here" — flag came closest and read as
/// reporting a problem.
struct MarkGlyph: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            let dot = CGRect(
                x: (10 - 4.2) * scale,
                y: (14 - 4.2) * scale,
                width: 8.4 * scale,
                height: 8.4 * scale
            )
            context.fill(Path(ellipseIn: dot), with: .style(.foreground))

            var plus = Path()
            plus.move(to: CGPoint(x: 15 * scale, y: 5 * scale))
            plus.addLine(to: CGPoint(x: 21 * scale, y: 5 * scale))
            plus.move(to: CGPoint(x: 18 * scale, y: 2 * scale))
            plus.addLine(to: CGPoint(x: 18 * scale, y: 8 * scale))
            context.stroke(
                plus,
                with: .style(.foreground),
                style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round)
            )
        }
    }
}

