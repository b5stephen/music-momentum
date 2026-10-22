//
//  MarkerEditorView.swift
//  MusicMomentum
//

import SwiftData
import SwiftUI

/// The Edit Marker sheet. Edits are held here until Done and the view never
/// touches the store: it reports what the user settled on and the caller
/// decides where it goes. The player's own transport stays visible behind
/// the sheet, so there's none here; Preview is the one way it plays.
struct MarkerEditorView: View {
    /// `nil` for a new marker, which Saved's Add marker opens.
    let marker: SongMarker?
    let song: SavedSong?
    let duration: TimeInterval
    let controller: PlaybackController
    /// Saved has no player to show an Undo toast on, so it asks first.
    var confirmsDelete = false
    let onSave: (_ name: String, _ time: TimeInterval) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var time: TimeInterval
    @State private var confirmingDelete = false

    init(
        marker: SongMarker,
        duration: TimeInterval,
        controller: PlaybackController,
        confirmsDelete: Bool = false,
        onSave: @escaping (_ name: String, _ time: TimeInterval) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.marker = marker
        self.song = marker.song
        self.duration = duration
        self.controller = controller
        self.confirmsDelete = confirmsDelete
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: marker.name)
        _time = State(initialValue: marker.startTime)
    }

    init(
        newIn song: SavedSong,
        at start: TimeInterval,
        duration: TimeInterval,
        controller: PlaybackController,
        onSave: @escaping (_ name: String, _ time: TimeInterval) -> Void
    ) {
        self.marker = nil
        self.song = song
        self.duration = duration
        self.controller = controller
        self.onSave = onSave
        _name = State(initialValue: "")
        _time = State(initialValue: start)
    }

    private var range: ClosedRange<TimeInterval> { 0...max(0, duration) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    nameCard
                    startCard
                    previewButton
                    if marker != nil, onDelete != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .contentMargins(.top, 4, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(marker == nil ? "New Marker" : "Edit Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // No `.confirm` role: it fills solid coral, which is kept
                    // for Preview. An explicit `.glass` style nests a second
                    // capsule inside the toolbar's own glass.
                    Button {
                        onSave(name, time)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Done")
                }
            }
            .confirmationDialog(
                "Delete this marker?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: delete)
            }
        }
    }

    // MARK: - Name

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            cardLabel("Name")
            TextField(placeholder, text: $name)
                .font(.title3)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
            QuickNameChips(
                selected: QuickName.all.first { QuickName.matches($0, name: name) },
                style: .sheet
            ) { chip in
                guard !QuickName.matches(chip, name: name) else { return }
                name = QuickName.name(for: chip, taken: otherNames)
            }
            .padding(.horizontal, -Self.cardPadding)
            .padding(.top, 4)
        }
        .modifier(Card())
    }

    /// An unnamed marker shows as "Marker N", so the placeholder says so.
    private var placeholder: String {
        guard let marker, let song = marker.song else { return "Marker" }
        return song.displayName(of: marker)
    }

    private var otherMarkers: [SongMarker] {
        (song?.sortedMarkers ?? []).filter { $0 !== marker }
    }

    private var otherNames: [String] { otherMarkers.map(\.name) }

    // MARK: - Starts at

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    cardLabel("Starts at")
                    PreciseTimeField(time: $time, range: range)
                }
                Spacer(minLength: 8)
                Button {
                    setTime(controller.playbackTime)
                } label: {
                    Text("Set to playhead")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentText)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.accentColor.opacity(0.14), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
            }

            HStack(spacing: 8) {
                nudge(-1)
                nudge(-0.1)
                nudge(0.1)
                nudge(1)
            }

            Text(Self.impliedEnd(
                of: time,
                others: otherMarkers.compactMap { other in
                    song.map { (time: other.startTime, name: $0.displayName(of: other)) }
                },
                duration: duration
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .modifier(Card())
    }

    private func nudge(_ amount: TimeInterval) -> some View {
        let label = PreciseTime.nudgeLabel(abs(amount))
        return Button {
            setTime(time + amount)
        } label: {
            Text(amount > 0 ? "+\(label)" : "−\(label)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.tertiarySystemFill), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(amount > 0 ? "Later by \(label)" : "Earlier by \(label)")
    }

    private func setTime(_ value: TimeInterval) {
        time = max(range.lowerBound, min(value, range.upperBound))
    }

    // MARK: - Actions

    /// Plays from just before the marker, unsaved, so a spot can be checked
    /// before Done; it leaves the song running, since a snippet that stops
    /// itself can't tell you whether the marker is in the right place.
    private var previewButton: some View {
        Button {
            controller.playFrom(Self.previewStart(for: time))
        } label: {
            Label("Preview from marker", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(Color.onAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.accentColor, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if confirmsDelete { confirmingDelete = true } else { delete() }
        } label: {
            Text("Delete Marker")
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }

    private func delete() {
        onDelete?()
        dismiss()
    }

    // MARK: - Layout

    fileprivate static let cardPadding: CGFloat = 14

    private func cardLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.4)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Text

extension MarkerEditorView {
    /// How far before the marker Preview starts, so the bar leading in is heard.
    nonisolated static let previewLead: TimeInterval = 1

    nonisolated static func previewStart(for time: TimeInterval) -> TimeInterval {
        max(0, time - previewLead)
    }

    /// The section's end at the marker's edited time: the first other
    /// marker after it, which may not be the one after it now if the time
    /// was moved past a neighbour.
    nonisolated static func impliedEnd(
        of time: TimeInterval,
        others: [(time: TimeInterval, name: String)],
        duration: TimeInterval
    ) -> String {
        let next = others
            .filter { $0.time > time + MarkerPlacement.sameTime && $0.time < duration - MarkerPlacement.sameTime }
            .min { $0.time < $1.time }
        guard let next else { return "Runs to the end of the song" }
        return "Runs until \(next.name) at \(PlaybackScrubber.timeLabel(next.time))"
    }
}

/// A white card on the sheet's grouped background.
private struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MarkerEditorView.cardPadding)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
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
            .font(.system(size: 36, weight: .bold).monospacedDigit())
            .keyboardType(.numbersAndPunctuation)
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { if !focused { commit() } }
            .onChange(of: time, initial: true) { if !focused { text = PreciseTime.format(time) } }
            .accessibilityLabel("Starts at")
            .accessibilityValue(PreciseTime.format(time))
    }

    private func commit() {
        if let parsed = PreciseTime.parse(text) {
            time = max(range.lowerBound, min(parsed, range.upperBound))
        }
        text = PreciseTime.format(time)
    }
}

// MARK: - Previews

@MainActor
private func previewSong(_ context: ModelContext) -> SavedSong {
    let song = SavedSong(songID: "1", speed: 0.75, title: "Midnight Tide", artistName: "The Harbour Lights")
    context.insert(song)
    return song
}

#Preview("Named") {
    let container = try! AppSchema.inMemoryContainer()
    let song = previewSong(container.mainContext)
    SongMarker.add(to: song, name: "Intro", at: 0, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse", at: 22, in: container.mainContext)
    let chorus = SongMarker.add(to: song, name: "Chorus", at: 72, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse 2", at: 108, in: container.mainContext)
    return MarkerEditorView(marker: chorus, duration: 245, controller: PlaybackController()) { _, _ in } onDelete: {}
        .modelContainer(container)
}

#Preview("Unnamed") {
    let container = try! AppSchema.inMemoryContainer()
    let song = previewSong(container.mainContext)
    SongMarker.add(to: song, name: "Intro", at: 0, in: container.mainContext)
    let marker = SongMarker.add(to: song, at: 96, in: container.mainContext)
    SongMarker.add(to: song, name: "Solo", at: 150, in: container.mainContext)
    return MarkerEditorView(marker: marker, duration: 245, controller: PlaybackController()) { _, _ in } onDelete: {}
        .modelContainer(container)
}

#Preview("Last marker") {
    let container = try! AppSchema.inMemoryContainer()
    let song = previewSong(container.mainContext)
    SongMarker.add(to: song, name: "Verse", at: 22, in: container.mainContext)
    let outro = SongMarker.add(to: song, name: "Outro", at: 210, in: container.mainContext)
    return MarkerEditorView(marker: outro, duration: 245, controller: PlaybackController()) { _, _ in } onDelete: {}
        .modelContainer(container)
}

#Preview("At 0:00") {
    let container = try! AppSchema.inMemoryContainer()
    let song = previewSong(container.mainContext)
    let intro = SongMarker.add(to: song, name: "Intro", at: 0, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse", at: 22, in: container.mainContext)
    return MarkerEditorView(marker: intro, duration: 245, controller: PlaybackController()) { _, _ in } onDelete: {}
        .modelContainer(container)
}

#Preview("New, from Saved") {
    let container = try! AppSchema.inMemoryContainer()
    let song = previewSong(container.mainContext)
    SongMarker.add(to: song, name: "Verse", at: 22, in: container.mainContext)
    return MarkerEditorView(newIn: song, at: 71, duration: 245, controller: PlaybackController()) { _, _ in }
        .modelContainer(container)
}

#Preview("Over the player") {
    let container = try! AppSchema.inMemoryContainer()
    let song = previewSong(container.mainContext)
    let chorus = SongMarker.add(to: song, name: "Chorus", at: 72, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse 2", at: 108, in: container.mainContext)
    return Color.indigo.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            MarkerEditorView(marker: chorus, duration: 245, controller: PlaybackController()) { _, _ in } onDelete: {}
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .modelContainer(container)
}
