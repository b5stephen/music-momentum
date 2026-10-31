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
    let onSave: (_ name: String, _ start: TimeInterval, _ end: TimeInterval?) -> Void
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) var dismiss
    @State var name: String
    @State var start: TimeInterval
    @State var end: TimeInterval?
    @State var confirmingDelete = false
    /// Which time the nudge row and Now act on.
    @State var selected: MarkerHandle = .start
    /// What's typed in a time field that hasn't been committed yet. Save
    /// applies it: a click on Save, or Return in a field on the Mac, can land
    /// before the field's focus change commits it.
    @State var typedTimes: [MarkerHandle: String] = [:]
    /// The sheet's own Loop: it loops this clip as edited, over whatever
    /// Practice was looping, until it's turned off or the sheet closes.
    @State var isLoopingDraft = false

    /// How far before the end handle the End cue drops the playhead.
    static let leadIn: TimeInterval = 2
    private static let defaultClipLength: TimeInterval = 4
    /// Half Practice's 10: here it's for finding a spot, and 10 would leap
    /// clean across the 5s zoom.
    static let skipInterval: TimeInterval = 5

    init(
        marker: SongMarker? = nil,
        initialStart: TimeInterval = 0,
        duration: TimeInterval,
        controller: PlaybackController,
        onSave: @escaping (_ name: String, _ start: TimeInterval, _ end: TimeInterval?) -> Void,
        onDelete: @escaping () -> Void = {}
    ) {
        self.marker = marker
        self.duration = duration
        self.controller = controller
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: marker?.name ?? "")
        _start = State(initialValue: marker?.startTime ?? initialStart)
        _end = State(initialValue: marker?.endTime)
        _selected = State(initialValue: marker?.endTime == nil ? .start : .end)
    }

    var isEditing: Bool { marker != nil }
    var canAddEnd: Bool { start + SongMarker.minimumClipLength <= duration }

    enum Kind: Hashable {
        case point, clip
    }

    var kind: Binding<Kind> {
        Binding(
            get: { end == nil ? .point : .clip },
            set: { newKind in
                withAnimation {
                    switch newKind {
                    case .point:
                        end = nil
                        selected = .start
                    case .clip:
                        end = min(duration, start + Self.defaultClipLength)
                        selected = .end
                    }
                }
            }
        )
    }

    /// Writes are dropped once the marker is a point again: a field being
    /// torn off screen mustn't bring the end back.
    var endBinding: Binding<TimeInterval> {
        Binding(get: { end ?? start }, set: { if end != nil { end = $0 } })
    }

    private var selectedTime: Binding<TimeInterval> {
        switch selected {
        case .end where end != nil: endBinding
        default: $start
        }
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

    var body: some View {
        editor
            .onChange(of: isLoopingDraft) { controller.loopDraft(draftRange) }
            .onChange(of: start) { if isLoopingDraft { controller.loopDraft(draftRange) } }
            .onChange(of: end) {
                if end == nil { isLoopingDraft = false } else if isLoopingDraft { controller.loopDraft(draftRange) }
            }
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
        #else
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        TextField(end == nil ? "Marker" : "Clip", text: $name)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            #endif
                        kindSwitch
                    }
                }

                Section {
                    MarkerRangeEditor(
                        start: $start,
                        end: $end,
                        duration: duration,
                        playhead: controller.playbackTime,
                        onGrab: { selected = $0 },
                        onScrub: { controller.isScrubbing = true },
                        onSeek: { controller.endScrub(at: $0) }
                    )
                    .padding(.vertical, 8)
                }

                Section {
                    times
                    nudgeRow
                } footer: {
                    if end == nil {
                        Text(canAddEnd
                            ? "Switch to Clip to give this an end time you can loop."
                            : "Too close to the end of the song for a clip.")
                    }
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
            #if os(iOS)
            .listSectionSpacing(20)
            #endif
            .contentMargins(.top, 4, for: .scrollContent)
            .navigationTitle(isEditing ? "Edit Marker" : "New Marker")
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
        #endif
    }

    func save() {
        if let typed = typedTimes[.start], let time = PreciseTime.parse(typed) {
            start = max(startRange.lowerBound, min(time, startRange.upperBound))
        }
        if let typed = typedTimes[.end], let time = PreciseTime.parse(typed), end != nil {
            end = max(endRange.lowerBound, min(time, endRange.upperBound))
        }
        onSave(name, start, end)
        dismiss()
    }

    /// Drawn as the pills themselves, since that's what the choice looks like.
    private var kindSwitch: some View {
        HStack(spacing: 6) {
            kindButton(.point, title: "Point") {
                Circle().frame(width: 6, height: 6)
            }
            kindButton(.clip, title: "Clip") {
                SpanGlyph()
            }
            .disabled(end == nil && !canAddEnd)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kind")
    }

    private func kindButton(
        _ value: Kind,
        title: String,
        @ViewBuilder glyph: () -> some View
    ) -> some View {
        let isSelected = kind.wrappedValue == value
        return Button {
            kind.wrappedValue = value
        } label: {
            HStack(spacing: 5) {
                glyph()
                    .opacity(isSelected ? 0.8 : 0.55)
                Text(title)
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                isSelected ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(.quaternary),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentText) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var times: some View {
        // No divider: one panel is always tinted, and that separates them.
        HStack(spacing: 6) {
            if end != nil {
                timeColumn("Start", time: $start, range: startRange, handle: .start)
                timeColumn("End", time: endBinding, range: endRange, handle: .end)
            } else {
                timeColumn("Time", time: $start, range: startRange, handle: .start)
            }
        }
        .padding(.vertical, 4)
    }

    private func timeColumn(
        _ title: String,
        time: Binding<TimeInterval>,
        range: ClosedRange<TimeInterval>,
        handle: MarkerHandle
    ) -> some View {
        let isSelected = selected == handle || end == nil
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(handle == .start ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                    .strokeBorder(.tint, lineWidth: 2)
                    .frame(width: 9, height: 9)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .fixedSize()
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if isSelected {
                    playheadChip(for: title)
                }
            }
            PreciseTimeField(
                time: time,
                range: range,
                onFocus: { selected = handle },
                onType: { typedTimes[handle] = $0 }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        // A tinted panel rather than tinted text: the big time stays legible in
        // light mode, and the coral is left to the clip and the handles.
        .background(
            isSelected ? AnyShapeStyle(.tint.opacity(0.16)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: Self.panelRadius, style: .continuous)
        )
        .contentShape(.rect)
        .onTapGesture { selected = handle }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "Now" read as the clock, not the song. The glyph is the strip's
    /// playhead in miniature. Half a clip on a mini can't fit both beside the
    /// column title, so it sheds the glyph, then the word.
    #if os(macOS)
    private static let panelRadius: CGFloat = 10
    private static let nudgeFont: Font = .callout
    #else
    private static let panelRadius: CGFloat = 16
    private static let nudgeFont: Font = .footnote
    #endif

    private func playheadChip(for title: String) -> some View {
        Button {
            setSelected(controller.playbackTime)
        } label: {
            ViewThatFits(in: .horizontal) {
                chipBody { playheadGlyph; Text("Playhead") }
                chipBody { Text("Playhead") }
                chipBody { playheadGlyph }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set \(title.lowercased()) to the current position")
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
            .background(Color.secondarySystemGroupedBackground, in: Capsule())
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

    func nudge(_ amount: TimeInterval) -> some View {
        Button {
            setSelected(selectedTime.wrappedValue + amount)
        } label: {
            Text(amount > 0 ? "+\(PreciseTime.nudgeLabel(amount))" : "−\(PreciseTime.nudgeLabel(-amount))")
                .font(Self.nudgeFont.monospacedDigit())
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(amount > 0 ? "Later by \(PreciseTime.nudgeLabel(amount))" : "Earlier by \(PreciseTime.nudgeLabel(-amount))")
    }

    func setSelected(_ value: TimeInterval) {
        let range = selectedRange
        selectedTime.wrappedValue = max(range.lowerBound, min(value, range.upperBound))
    }

    /// The cue buttons leave the song running: a snippet that stops itself
    /// can't tell you whether the clip is the right piece of music.
    private var transportRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                skipButton(-Self.skipInterval)
                playPauseButton
                skipButton(Self.skipInterval)
                loopButton
            }

            // Each cue carries the dot of the time column it plays from.
            HStack(spacing: 8) {
                if let end {
                    cueButton("Play from start", handle: .start, spoken: "Play from the start of the clip") {
                        controller.playFrom(start)
                    }
                    // Before the end, so you hear the clip run into it.
                    cueButton("Play into end", handle: .end, spoken: "Play into the end of the clip") {
                        controller.playFrom(max(start, end - Self.leadIn))
                    }
                } else {
                    cueButton("Play from marker", handle: .start, spoken: "Play from the marker") {
                        controller.playFrom(start)
                    }
                }
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

    /// Solid coral when on, as looping is wherever the app isn't on a cover.
    private var loopButton: some View {
        Button {
            isLoopingDraft.toggle()
        } label: {
            Image(systemName: "repeat")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(FillButtonStyle(isOn: isLoopingDraft))
        .disabled(end == nil)
        .accessibilityLabel("Loop this clip")
        .accessibilityAddTraits(isLoopingDraft ? .isSelected : [])
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

    private func cueButton(
        _ title: String,
        handle: MarkerHandle,
        spoken: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Circle()
                    .fill(handle == .start ? AnyShapeStyle(.secondary) : AnyShapeStyle(.clear))
                    .strokeBorder(.secondary, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .accessibilityLabel(spoken)
    }
}

/// The nudge and cue buttons: a capsule on the lightest system fill, which
/// keeps them quieter than `.bordered` and leaves the coral to the clip. Loop
/// fills solid when on.
private struct FillButtonStyle: ButtonStyle {
    var isOn = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .background(isOn ? Color.accentColor : Color.tertiarySystemFill, in: Capsule())
            .foregroundStyle(isOn ? AnyShapeStyle(Color.onAccent) : AnyShapeStyle(.primary))
            .opacity(configuration.isPressed ? 0.5 : isEnabled ? 1 : 0.4)
    }
}

// MARK: - Time field

/// Only writes back a time it could parse, and only once editing ends.
/// Until then `onType` hears the text, and `nil` once it's committed.
private struct PreciseTimeField: View {
    @Binding var time: TimeInterval
    let range: ClosedRange<TimeInterval>
    var onFocus: () -> Void = {}
    var onType: (String?) -> Void = { _ in }

    @State private var text = ""
    @FocusState private var focused: Bool

    #if os(macOS)
    private static let size: CGFloat = 26
    #else
    private static let size: CGFloat = 32
    #endif

    var body: some View {
        TextField("0:00.0", text: $text)
            .font(.system(size: Self.size, weight: .semibold, design: .rounded).monospacedDigit())
            #if os(iOS)
            .keyboardType(.numbersAndPunctuation)
            #else
            .textFieldStyle(.plain)
            .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                commit()
                let step: TimeInterval = press.modifiers.contains(.shift) ? 1 : 0.1
                let nudged = time + (press.key == .upArrow ? step : -step)
                time = max(range.lowerBound, min(nudged, range.upperBound))
                text = PreciseTime.format(time)
                return .handled
            }
            .help("↑ or ↓ for a tenth of a second, with ⇧ for a second")
            #endif
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { focused ? onFocus() : commit() }
            .onChange(of: text) { if focused { onType(text) } }
            .onChange(of: time, initial: true) { if !focused { text = PreciseTime.format(time) } }
            .accessibilityLabel("Time")
            .accessibilityValue(PreciseTime.format(time))
    }

    private func commit() {
        if let parsed = PreciseTime.parse(text) {
            time = max(range.lowerBound, min(parsed, range.upperBound))
        }
        text = PreciseTime.format(time)
        onType(nil)
    }
}

#Preview("New") {
    MarkerEditorView(initialStart: 71, duration: 245, controller: PlaybackController()) { _, _, _ in }
}

#Preview("Edit clip") {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong(songID: "1", speed: 0.8, title: "Little Wing", artistName: "Jimi Hendrix")
    container.mainContext.insert(song)
    let marker = SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 112.4, in: container.mainContext)
    return MarkerEditorView(marker: marker, duration: 245, controller: PlaybackController()) { _, _, _ in }
        .modelContainer(container)
}
