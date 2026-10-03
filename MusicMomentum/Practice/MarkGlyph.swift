//
//  MarkGlyph.swift
//  MusicMomentum
//

import SwiftUI

/// The point marker the track draws, with a plus. No SF Symbol says "put a
/// mark here" — flag came closest and read as reporting a problem.
struct MarkGlyph: View {
    var body: some View {
        Canvas { context, size in
            let scale = size.width / 24
            var path = Path()
            path.move(to: CGPoint(x: 3.5 * scale, y: 19.5 * scale))
            path.addLine(to: CGPoint(x: 20.5 * scale, y: 19.5 * scale))
            path.move(to: CGPoint(x: 9 * scale, y: 19.5 * scale))
            path.addLine(to: CGPoint(x: 9 * scale, y: 7.5 * scale))
            path.move(to: CGPoint(x: 15 * scale, y: 5 * scale))
            path.addLine(to: CGPoint(x: 20.5 * scale, y: 5 * scale))
            path.move(to: CGPoint(x: 17.75 * scale, y: 2.25 * scale))
            path.addLine(to: CGPoint(x: 17.75 * scale, y: 7.75 * scale))
            context.stroke(
                path,
                with: .style(.foreground),
                style: StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round)
            )
        }
    }
}
