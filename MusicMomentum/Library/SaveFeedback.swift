//
//  SaveFeedback.swift
//  MusicMomentum
//

import Observation
import SwiftUI

/// The short "Added … to …" line a row's + raises, so a tap that only turns a
/// glyph into a tick still says where the song went.
@MainActor @Observable
final class SaveFeedback {
    private(set) var message: String?
    private var generation = 0

    func show(_ message: String) {
        generation += 1
        let shown = generation
        withAnimation(.snappy) { self.message = message }
        AccessibilityNotification.Announcement(message).post()
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard shown == generation else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.message = nil }
        }
    }
}

extension EnvironmentValues {
    @Entry var saveFeedback: SaveFeedback?
}

extension View {
    /// Owns a `SaveFeedback` for the rows inside and shows its line at the
    /// bottom of this view.
    func showsSaveFeedback() -> some View {
        modifier(SaveFeedbackHost())
    }
}

private struct SaveFeedbackHost: ViewModifier {
    @State private var feedback = SaveFeedback()

    func body(content: Content) -> some View {
        content
            .environment(\.saveFeedback, feedback)
            .overlay(alignment: .bottom) {
                if let message = feedback.message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}
