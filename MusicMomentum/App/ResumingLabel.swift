//
//  ResumingLabel.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// Last launch's song, named while it's looked up, where the mini player and
/// the menu bar would otherwise say "No song loaded" about a song that's coming.
struct ResumingLabel: View {
    let title: String
    let artistName: String?
    var alignment: HorizontalAlignment = .center

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: alignment, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let artistName {
                    Text(artistName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading \(title)")
    }
}
#endif
