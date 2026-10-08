//
//  SpanGlyph.swift
//  MusicMomentum
//

import SwiftUI

/// The clip glyph: a short bar, as clips are drawn in the timeline's marker
/// lane, beside the point's dot. Filled and thick enough to be a lozenge
/// rather than a minus sign next to the clip's length.
struct SpanGlyph: View {
    /// Scaled with the label: the glyph is the only thing telling a clip from
    /// a point, so it can't stay 13pt next to accessibility-sized type.
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 13

    var body: some View {
        Capsule()
            .frame(width: width, height: width * 0.4)
    }
}
