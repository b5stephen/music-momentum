//
//  MarkerEditorView.swift
//  MusicMomentum
//

import SwiftData
import SwiftUI

/// The sheet for placing or adjusting a marker (a point) or a loop (a point
/// with an end). Which one is fixed when the sheet opens; there's no turning one
/// into the other. Nothing is written until Save, and the view never touches
/// the store: it reports what the user settled on and the caller decides where
/// it goes. What it shows about the rest of the song comes in as plain values.
struct MarkerEditorView: View {
    let marker: SongMarker?
    let isLoop: Bool
    let duration: TimeInterval
    let controller: PlaybackController
    /// The song's other points, for the suggested names and "Runs until".
    let otherPoints: [(name: String, start: TimeInterval)]
    let otherLoopNames: [String]
    let onSave: (_ name: String, _ start: TimeInterval, _ end: TimeInterval?) -> Void
    /// Saves the marker as edited, then the caller swaps this sheet for a new
    /// loop's; the sheet doesn't dismiss itself. `nil` hides Make a loop.
    var onMakeLoop: ((_ name: String, _ start: TimeInterval, _ end: TimeInterval) -> Void)?
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) var dismiss
    @State var name: String
    @State var start: TimeInterval
    @State var end: TimeInterval?
    @State var confirmingDelete = false
    /// Which time the nudge row and Set to playhead act on.
    @State var selected: MarkerHandle = .start
    /// What's typed in a time field that hasn't been committed yet. Save
    /// applies it: a click on Save, or Return in a field on the Mac, can land
    /// before the field's focus change commits it.
    @State var typedTimes: [MarkerHandle: String] = [:]
    /// The sheet's own Loop: it loops this loop as edited, over whatever
    /// Practice was looping, until it's turned off or the sheet closes.
    @State var isLoopingDraft: Bool

    /// How far before a time the cues drop the playhead, so you hear the run-up.
    static let leadIn: TimeInterval = 2
    /// Half Practice's 10: here it's for finding a spot, and 10 would leap
    /// clean across the 5s zoom.
    static let skipInterval: TimeInterval = 5

    #if os(macOS)
    static let panelRadius: CGFloat = 10
    static let actionHeight: CGFloat? = nil
    static let nudgeFont: Font = .callout
    #else
    static let panelRadius: CGFloat = 16
    /// With the capsule's padding, a 44pt target.
    static let actionHeight: CGFloat? = 32
    static let nudgeFont: Font = .footnote
    #endif

    /// A loop that isn't saved yet comes with `initialEnd`, and starts with
    /// Loop on so it's heard straight away.
    init(
        marker: SongMarker? = nil,
        initialStart: TimeInterval = 0,
        initialEnd: TimeInterval? = nil,
        duration: TimeInterval,
        controller: PlaybackController,
        otherPoints: [(name: String, start: TimeInterval)] = [],
        otherLoopNames: [String] = [],
        onSave: @escaping (_ name: String, _ start: TimeInterval, _ end: TimeInterval?) -> Void,
        onMakeLoop: ((_ name: String, _ start: TimeInterval, _ end: TimeInterval) -> Void)? = nil,
        onDelete: @escaping () -> Void = {}
    ) {
        let end = marker?.endTime ?? initialEnd
        self.marker = marker
        isLoop = end != nil
        self.duration = duration
        self.controller = controller
        self.otherPoints = otherPoints
        self.otherLoopNames = otherLoopNames
        self.onSave = onSave
        self.onMakeLoop = onMakeLoop
        self.onDelete = onDelete
        _name = State(initialValue: marker?.name ?? "")
        _start = State(initialValue: marker?.startTime ?? initialStart)
        _end = State(initialValue: end)
        _selected = State(initialValue: end == nil ? .start : .end)
        _isLoopingDraft = State(initialValue: marker == nil && initialEnd != nil)
    }

    var isEditing: Bool { marker != nil }

    var endBinding: Binding<TimeInterval> {
        Binding(get: { end ?? start }, set: { end = $0 })
    }

    private var selectedTime: Binding<TimeInterval> {
        selected == .end && end != nil ? endBinding : $start
    }

    var startRange: ClosedRange<TimeInterval> {
        0...max(0, end.map { $0 - SongMarker.minimumClipLength } ?? duration)
    }

    var endRange: ClosedRange<TimeInterval> {
        min(start + SongMarker.minimumClipLength, duration)...duration
    }

    private var selectedRange: ClosedRange<TimeInterval> {
        selected == .end && end != nil ? endRange : startRange
    }

    var title: String {
        switch (isLoop, isEditing) {
        case (false, false): "New Marker"
        case (false, true): "Edit Marker"
        case (true, false): "New Loop"
        case (true, true): "Edit Loop"
        }
    }

    var deleteTitle: String { isLoop ? "Delete this loop?" : "Delete this marker?" }

    var body: some View {
        editor
            // A sheet swapped for another (Make a loop) is torn down and built
            // afresh, and which of the two runs first isn't promised. Only a
            // loop turns the draft on or off, and a marker sheet never does, so
            // the marker's `onDisappear` can't undo the loop's `onAppear`.
            .onAppear { if isLoopingDraft { controller.loopDraft(draftRange) } }
            .onChange(of: isLoopingDraft) { controller.loopDraft(draftRange) }
            .onChange(of: start) { if isLoopingDraft { controller.loopDraft(draftRange) } }
            .onChange(of: end) { if isLoopingDraft { controller.loopDraft(draftRange) } }
            .onDisappear { if isLoopingDraft { controller.loopDraft(nil) } }
    }

    private var draftRange: Range<TimeInterval>? {
        guard isLoopingDraft, let end else { return nil }
        return start..<end
    }

    @ViewBuilder
    private var editor: some View {
        #if os(macOS)
        macBody
            .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                deleteConfirmation
            }
        #else
        NavigationStack {
            Form {
                if isLoop { loopSections } else { markerSections }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Text(isLoop ? "Delete Loop" : "Delete Marker")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            #if os(iOS)
            .listSectionSpacing(20)
            #endif
            .contentMargins(.top, 4, for: .scrollContent)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Save")
                }
            }
            .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                deleteConfirmation
            }
        }
        #endif
    }

    private var deleteConfirmation: some View {
        Button("Delete", role: .destructive) {
            onDelete()
            dismiss()
        }
    }

    #if !os(macOS)
    @ViewBuilder
    private var markerSections: some View {
        Section {
            nameField
            nameChips.listRowInsets(.init(top: 0, leading: 0, bottom: 10, trailing: 0))
        }

        Section { times }

        Section {
            rangeEditor.padding(.vertical, 8)
        }

        Section {
            nudgeRow
            infoLine
        }

        Section {
            HStack(spacing: 8) {
                previewButton
                makeLoopButton
            }
            .buttonStyle(FillButtonStyle())
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var loopSections: some View {
        Section {
            nameField
            nameChips.listRowInsets(.init(top: 0, leading: 0, bottom: 10, trailing: 0))
        }

        Section { times }

        Section {
            rangeEditor.padding(.vertical, 8)
        }

        Section {
            nudgeRow
            infoLine
        }

        Section { listeningControls }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
    #endif

    var nameField: some View {
        TextField(isLoop ? "Loop" : "Marker", text: $name)
            #if os(iOS)
            .textInputAutocapitalization(.words)
            #endif
    }

    var rangeEditor: some View {
        MarkerRangeEditor(
            start: $start,
            end: $end,
            duration: duration,
            playhead: controller.playbackTime,
            onGrab: { selected = $0 },
            onScrub: { controller.isScrubbing = true },
            onSeek: { controller.endScrub(at: $0) }
        )
    }

    func commitTypedTimes() {
        if let typed = typedTimes[.start], let time = PreciseTime.parse(typed) {
            start = max(startRange.lowerBound, min(time, startRange.upperBound))
        }
        if let typed = typedTimes[.end], let time = PreciseTime.parse(typed), end != nil {
            end = max(endRange.lowerBound, min(time, endRange.upperBound))
        }
    }

    func save() {
        commitTypedTimes()
        onSave(name, start, end)
        dismiss()
    }

    var canMakeLoop: Bool {
        SectionSpan.loopEnd(from: start, among: otherPoints, duration: duration) != nil
    }

    func makeLoop() {
        commitTypedTimes()
        guard let loopEnd = SectionSpan.loopEnd(from: start, among: otherPoints, duration: duration) else { return }
        onMakeLoop?(name, start, loopEnd)
    }

    func setSelected(_ value: TimeInterval) {
        let range = selectedRange
        selectedTime.wrappedValue = max(range.lowerBound, min(value, range.upperBound))
    }

    var selectedValue: TimeInterval { selectedTime.wrappedValue }
}

// MARK: - Previews

private let previewPoints: [(name: String, start: TimeInterval)] = [
    ("Intro", 0), ("Verse", 24), ("Chorus", 72), ("Verse 2", 108),
]

private func previewEditor(
    marker: SongMarker? = nil,
    start: TimeInterval = 71,
    end: TimeInterval? = nil
) -> some View {
    MarkerEditorView(
        marker: marker,
        initialStart: start,
        initialEnd: end,
        duration: 245,
        controller: PlaybackController(),
        otherPoints: previewPoints,
        otherLoopNames: ["Riff"],
        onSave: { _, _, _ in },
        onMakeLoop: { _, _, _ in }
    )
}

private func previewMarker(
    name: String,
    start: TimeInterval,
    end: TimeInterval? = nil
) -> (SongMarker, ModelContainer) {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong(songID: "1", speed: 0.8, title: "Little Wing", artistName: "Jimi Hendrix")
    container.mainContext.insert(song)
    return (SongMarker.add(to: song, name: name, startTime: start, endTime: end, in: container.mainContext), container)
}

#Preview("New marker") {
    previewEditor(start: 71)
}

#Preview("Edit marker") {
    let (marker, container) = previewMarker(name: "Chorus", start: 72)
    return previewEditor(marker: marker).modelContainer(container)
}

#Preview("Edit marker, last point") {
    let (marker, container) = previewMarker(name: "Verse 2", start: 108)
    return previewEditor(marker: marker).modelContainer(container)
}

#Preview("Edit loop") {
    let (marker, container) = previewMarker(name: "Solo", start: 96, end: 112.4)
    return previewEditor(marker: marker).modelContainer(container)
}

#Preview("New loop, looping") {
    previewEditor(start: 72, end: 108)
}

#if os(macOS)
#Preview("Marker over a cover, Mac") {
    InheritedGround {
        previewEditor(start: 71)
            .outsideArtworkGround()
    }
}

#Preview("Loop over a cover, Mac") {
    InheritedGround {
        previewEditor(start: 72, end: 108)
            .outsideArtworkGround()
    }
}

/// What a sheet presented from inside `MacWindow`'s ground inherits, drawn on
/// the system background its window has: previews don't draw sheets.
private struct InheritedGround<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme
    private let palette = ArtworkPalette(cover: OKLCH(red: 0.62, green: 0.52, blue: 0.40))

    var body: some View {
        content
            .foregroundStyle(palette.foreground)
            .tint(palette.foreground)
            .environment(\.colorScheme, .dark)
            .environment(\.systemColorScheme, scheme)
            .background(Color.systemBackground)
    }
}
#endif
