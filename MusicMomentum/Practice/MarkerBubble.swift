//
//  MarkerBubble.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// The timeline's tooltip: dark, rounded, with a hairline. It shows at once,
/// where `.help` waits a second and would clash with it.
struct MarkerBubble: View {
    private let text: Text

    init(_ text: Text) {
        self.text = text
    }

    /// "**Chorus** · 1:02 – 1:36 · click to loop".
    init(name: String, detail: String) {
        self.init(Text("\(Text(name).bold()) \u{00B7} \(detail)"))
    }

    var body: some View {
        text
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 30 / 255, green: 34 / 255, blue: 36 / 255).opacity(0.96))
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
            }
    }
}

#Preview("Marker bubbles", traits: .fixedLayout(width: 460, height: 150)) {
    VStack(alignment: .leading, spacing: 14) {
        MarkerBubble(name: "Chorus", detail: "1:02 \u{2013} 1:36 \u{00B7} click to loop")
        MarkerBubble(name: "Bridge", detail: "2:08 \u{00B7} click to jump")
        MarkerBubble(Text("1:20").monospacedDigit())
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color(red: 9 / 255, green: 21 / 255, blue: 23 / 255))
}
#endif
