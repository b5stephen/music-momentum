//
//  AddMarkerGlyph.swift
//  MusicMomentum
//

import SwiftUI

/// A bookmark with a plus in it, for the transport's Add marker button. SF
/// Symbols has no such bookmark, and the button sits beside the skip arrows,
/// where Saved's dot-and-plus `MarkGlyph` read as a stray bullet.
struct AddMarkerGlyph: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            let origin = CGPoint(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
            }
            let style = StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round)

            var mark = Path()
            mark.move(to: point(7, 2.5))
            mark.addLine(to: point(17, 2.5))
            mark.addQuadCurve(to: point(19, 4.5), control: point(19, 2.5))
            mark.addLine(to: point(19, 21.5))
            mark.addLine(to: point(12, 16.5))
            mark.addLine(to: point(5, 21.5))
            mark.addLine(to: point(5, 4.5))
            mark.addQuadCurve(to: point(7, 2.5), control: point(5, 2.5))
            mark.closeSubpath()
            context.stroke(mark, with: .style(.foreground), style: style)

            var plus = Path()
            plus.move(to: point(12, 6))
            plus.addLine(to: point(12, 12.5))
            plus.move(to: point(8.75, 9.25))
            plus.addLine(to: point(15.25, 9.25))
            context.stroke(plus, with: .style(.foreground), style: style)
        }
        .accessibilityHidden(true)
    }
}
