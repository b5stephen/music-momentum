//
//  MarkerEditorView.swift
//  MusicMomentum
//

import SwiftData
import SwiftUI

/// The sheet for placing or adjusting a marker. Nothing is written until
/// Save, and the view never touches the store: it reports what the user
/// settled on and the caller decides where it goes.
struct MarkerEditorView: View {
    let marker: SongMarker?
    let duration: TimeInterval
    let controller: PlaybackController
    let onSave: (_ name: String, _ time: TimeInterval) -> Void
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var time: TimeInterval
    @State private var confirmingDelete = false

    /// Half Practice's 10: here it's for finding a spot.
    private static let skipInterval: TimeInterval = 5

    init(
        marker: SongMarker? = nil,
        initialStart: TimeInterval = 0,
        duration: TimeInterval,
        controller: PlaybackController,
        onSave: @escaping (_ name: String, _ time: TimeInterval) -> Void,
        onDelete: @escaping () -> Void = {}
    ) {
        self.marker = marker
        self.duration = duration
        self.controller = controller
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: marker?.name ?? "")
        _time = State(initialValue: marker?.startTime ?? initialStart)
    }

    private var isEditing: Bool { marker != nil }
    private var range: ClosedRange<TimeInterval> { 0...max(0, duration) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    timeColumn
                    nudgeRow
                }

                Section {
                    transportRow
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Text("Delete Marker")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .listSectionSpacing(20)
            .contentMargins(.top, 4, for: .scrollContent)
            .navigationTitle(isEditing ? "Edit Marker" : "New Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // No `.confirm` role: it fills solid coral, and in this app only
                    // looping fills solid. An explicit `.glass` style nests a second
                    // capsule inside the toolbar's own glass, so it's left to the
                    // toolbar to draw it like Close.
                    Button {
                        onSave(name, time)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Save")
                }
            }
            .confirmationDialog(
                "Delete this marker?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
    }

    /// An unnamed marker shows as "Marker N", so the placeholder says so.
    private var placeholder: String {
        guard let marker, let song = marker.song else { return "Marker" }
        return song.displayName(of: marker)
    }

    private var timeColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("TIME")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.4)
                    .fixedSize()
                    .layoutPriority(1)
                Spacer(minLength: 4)
                playheadChip
            }
            PreciseTimeField(time: $time, range: range)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.tint.opacity(0.16), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time")
    }

    /// "Now" read as the clock, not the song.
    private var playheadChip: some View {
        Button {
            setTime(controller.playbackTime)
        } label: {
            ViewThatFits(in: .horizontal) {
                chipBody { playheadGlyph; Text("Playhead") }
                chipBody { Text("Playhead") }
                chipBody { playheadGlyph }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set the time to the current position")
    }

    private var playheadGlyph: some View {
        VStack(spacing: 0) {
            Circle().frame(width: 5, height: 5)
            Capsule().frame(width: 1.5, height: 7)
        }
    }

    private func chipBody(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 4, content: content)
            .font(.caption2.weight(.semibold))
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            // The cell's colour, so it stands off the tinted panel it sits in.
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(Color.accentText)
    }

    private var nudgeRow: some View {
        HStack(spacing: 8) {
            nudge(-1)
            nudge(-0.1)
            nudge(0.1)
            nudge(1)
        }
        .buttonStyle(FillButtonStyle())
        .padding(.vertical, 4)
    }

    private func nudge(_ amount: TimeInterval) -> some View {
        Button {
            setTime(time + amount)
        } label: {
            Text(amount > 0 ? "+\(PreciseTime.nudgeLabel(amount))" : "−\(PreciseTime.nudgeLabel(-amount))")
                .font(.footnote.monospacedDigit())
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(amount > 0 ? "Later by \(PreciseTime.nudgeLabel(amount))" : "Earlier by \(PreciseTime.nudgeLabel(-amount))")
    }

    private func setTime(_ value: TimeInterval) {
        time = max(range.lowerBound, min(value, range.upperBound))
    }

    /// The cue button leaves the song running: a snippet that stops itself
    /// can't tell you whether the marker is in the right place.
    private var transportRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                skipButton(-Self.skipInterval)
                playPauseButton
                skipButton(Self.skipInterval)
            }

            Button {
                controller.playFrom(time)
            } label: {
                Text("Play from marker")
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
        }
        .buttonStyle(FillButtonStyle())
    }

    private var playPauseButton: some View {
        Button {
            controller.togglePlayPause()
        } label: {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
    }

    private func skipButton(_ offset: TimeInterval) -> some View {
        let seconds = Int(abs(offset))
        return Button {
            controller.skip(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "gobackward.\(seconds)" : "goforward.\(seconds)")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .accessibilityLabel(offset < 0 ? "Back \(seconds) seconds" : "Forward \(seconds) seconds")
    }

}

/// The nudge and cue buttons: a capsule on the lightest system fill, which
/// keeps them quieter than `.bordered` and leaves the coral to the time.
private struct FillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.5 : isEnabled ? 1 : 0.4)
    }
}

// MARK: - Time field

/// Only writes back a time it could parse, and only once editing ends.
private struct PreciseTimeField: View {
    @Binding var time: TimeInterval
    let range: ClosedRange<TimeInterval>

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0:00.0", text: $text)
            .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
            .keyboardType(.numbersAndPunctuation)
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { if !focused { commit() } }
            .onChange(of: time, initial: true) { if !focused { text = PreciseTime.format(time) } }
            .accessibilityLabel("Time")
            .accessibilityValue(PreciseTime.format(time))
    }

    private func commit() {
        if let parsed = PreciseTime.parse(text) {
            time = max(range.lowerBound, min(parsed, range.upperBound))
        }
        text = PreciseTime.format(time)
    }
}

#Preview("New") {
    MarkerEditorView(initialStart: 71, duration: 245, controller: PlaybackController()) { _, _ in }
}

#Preview("Edit unnamed") {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong(songID: "1", speed: 0.8, title: "Little Wing", artistName: "Jimi Hendrix")
    container.mainContext.insert(song)
    SongMarker.add(to: song, name: "Intro", at: 0, in: container.mainContext)
    let marker = SongMarker.add(to: song, at: 96, in: container.mainContext)
    return MarkerEditorView(marker: marker, duration: 245, controller: PlaybackController()) { _, _ in }
        .modelContainer(container)
}
