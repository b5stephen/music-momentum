//
//  MarkerEditorView+Parts.swift
//  MusicMomentum
//

import SwiftUI

/// The pieces both sheets and both platforms are built from.
extension MarkerEditorView {
    // MARK: Name

    private var suggestions: [String] {
        let guessed = isLoop
            ? MarkerNameSuggestions.forLoop(among: otherLoopNames)
            : MarkerNameSuggestions.forMarker(at: start, among: otherPoints)
        // The name the sheet opened with, so an edit shows it selected. Typing
        // doesn't add chips: they'd change on every keystroke.
        // An unnamed "Marker 7" isn't a name worth offering back.
        guard let opened = marker?.name.trimmingCharacters(in: .whitespaces), !opened.isEmpty,
              !MarkerNameSuggestions.isDefaultName(opened),
              !guessed.contains(where: { $0.caseInsensitiveCompare(opened) == .orderedSame })
        else { return guessed }
        return [opened] + guessed
    }

    var nameChips: some View {
        let current = name.trimmingCharacters(in: .whitespaces)
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    let isSelected = current.caseInsensitiveCompare(suggestion) == .orderedSame
                    Button {
                        name = suggestion
                    } label: {
                        Text(suggestion)
                            .font(Self.chipFont.weight(isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.horizontal, Self.chipPadding)
                            .frame(height: Self.chipHeight)
                            .background(
                                isSelected ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(Color.tertiarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentText) : AnyShapeStyle(.primary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Self.chipInset)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityLabel("Suggested names")
    }

    // MARK: Times

    var times: some View {
        // No divider: one panel is always tinted, and that separates them.
        Group {
            if isLoop {
                HStack(spacing: 8) {
                    timeColumn("Start", time: $start, range: startRange, handle: .start)
                    timeColumn("End", time: endBinding, range: endRange, handle: .end)
                }
            } else {
                HStack(alignment: .bottom) {
                    timeColumn("Starts at", time: $start, range: startRange, handle: .start)
                    Spacer(minLength: 8)
                    playheadChip("Set to playhead")
                }
            }
        }
    }

    private func timeColumn(
        _ title: String,
        time: Binding<TimeInterval>,
        range: ClosedRange<TimeInterval>,
        handle: MarkerHandle
    ) -> some View {
        let isSelected = isLoop && selected == handle
        return VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentText) : AnyShapeStyle(.secondary))
                .fixedSize()
            PreciseTimeField(
                time: time,
                range: range,
                onFocus: { selected = handle },
                onType: { typedTimes[handle] = $0 },
                size: isLoop ? Self.loopTimeSize : nil
            )
        }
        .frame(maxWidth: isLoop ? .infinity : nil, alignment: .leading)
        .padding(.vertical, isLoop ? 8 : 0)
        .padding(.horizontal, isLoop ? 12 : 0)
        .background(
            isLoop ? (isSelected ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(Color.tertiarySystemFill)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: Self.panelRadius, style: .continuous)
        )
        .contentShape(.rect)
        .onTapGesture { selected = handle }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Set to playhead

    /// The playhead read as the clock, not the song.
    func playheadChip(_ title: String) -> some View {
        Button {
            setSelected(controller.playbackTime)
        } label: {
            Text(title)
                .font(Self.chipFont.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Self.chipPadding)
                .frame(height: Self.chipHeight)
                .background(.tint.opacity(0.14), in: Capsule())
                .foregroundStyle(Color.accentText)
        }
        .buttonStyle(.plain)
    }

    // MARK: Nudge and facts

    var nudgeRow: some View {
        HStack(spacing: 8) {
            nudge(-1)
            nudge(-0.1)
            nudge(0.1)
            nudge(1)
        }
        #if !os(macOS)
        .buttonStyle(FillButtonStyle())
        #else
        .buttonStyle(.bordered)
        #endif
    }

    func nudge(_ amount: TimeInterval) -> some View {
        Button {
            setSelected(selectedValue + amount)
        } label: {
            Text(amount > 0 ? "+\(PreciseTime.nudgeLabel(amount))" : "−\(PreciseTime.nudgeLabel(-amount))")
                .font(Self.nudgeFont.monospacedDigit())
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(amount > 0 ? "Later by \(PreciseTime.nudgeLabel(amount))" : "Earlier by \(PreciseTime.nudgeLabel(-amount))")
    }

    /// What the marker covers, or how long the loop is and where it sits.
    @ViewBuilder
    var infoLine: some View {
        if let end {
            let title = selected == .end ? "Set end to playhead" : "Set start to playhead"
            ViewThatFits(in: .horizontal) {
                HStack {
                    loopFacts(end: end)
                    Spacer(minLength: 8)
                    playheadChip(title)
                }
                VStack(alignment: .leading, spacing: 8) {
                    loopFacts(end: end)
                    playheadChip(title)
                }
            }
        } else {
            #if os(macOS)
            markerFacts
            #else
            // Make a loop sits on the line naming the section it would loop,
            // where Edit Loop keeps Set start to playhead.
            ViewThatFits(in: .horizontal) {
                HStack {
                    markerFacts
                    Spacer(minLength: 8)
                    makeLoopChip
                }
                VStack(alignment: .leading, spacing: 8) {
                    markerFacts
                    makeLoopChip
                }
            }
            #endif
        }
    }

    private var markerFacts: some View {
        let next = SectionSpan.end(after: start, among: otherPoints, duration: duration)
        return VStack(alignment: .leading, spacing: 2) {
                Text(next.name.map { "Runs until \($0) at \(PlaybackScrubber.timeLabel(next.time))" }
                    ?? "Runs to the end of the song")
                if onMakeLoop != nil, case .replaced(let name) = makeLoopMarker {
                    Text("Make a loop replaces \(name)")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func loopFacts(end: TimeInterval) -> some View {
        let length = end - start
        let long = length < 10 ? String(format: "%.1fs", length) : PlaybackScrubber.lengthLabel(length)
        let inside = SectionSpan.name(containing: start, among: otherPoints).map { " · inside \($0)" } ?? ""
        return Text("\(long) long\(inside)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    // MARK: Make a loop

    #if !os(macOS)
    /// Styled like Set to playhead, which holds this spot on Edit Loop.
    @ViewBuilder
    private var makeLoopChip: some View {
        if onMakeLoop != nil {
            Button {
                makeLoop()
            } label: {
                HStack(spacing: 6) {
                    SpanGlyph()
                    Text("Make a loop")
                }
                .font(Self.chipFont.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Self.chipPadding)
                .frame(height: Self.chipHeight)
                .background(.tint.opacity(0.14), in: Capsule())
                .foregroundStyle(Color.accentText)
            }
            .buttonStyle(.plain)
            .disabled(!canMakeLoop)
            .opacity(canMakeLoop ? 1 : 0.4)
            .accessibilityHint(makeLoopHint)
        }
    }
    #endif

    var makeLoopHint: String {
        switch makeLoopMarker {
        case .kept: "Saves this marker and opens a new loop from it to the end of its section"
        case .replaced(let name): "Opens a new loop from here to the end of its section, in place of \(name)"
        case .skipped: "Opens a new loop from here to the end of its section, without saving a marker"
        }
    }

    // MARK: Listening controls

    #if !os(macOS)
    /// The transport, with Loop first on a loop, then the cues on a second
    /// row, since six controls at 48pt don't fit a phone's width. The cues
    /// leave the song running: a snippet that stops itself can't tell you
    /// whether the loop is the right piece of music, or the marker on the beat.
    var listeningControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if isLoop { loopButton }
                skipButton(-Self.skipInterval)
                playPauseButton
                skipButton(Self.skipInterval)
            }

            // Each cue carries the dot of the time column it plays from;
            // into-cues lead in, so you hear what runs into the time.
            HStack(spacing: 8) {
                if isLoop {
                    cueButton("Play from start", filled: true, spoken: "Play from the start of the loop") {
                        controller.playFrom(start)
                    }
                    cueButton("Play into end", filled: false, spoken: "Play into the end of the loop") {
                        if let end { controller.playFrom(max(start, end - Self.leadIn)) }
                    }
                } else {
                    cueButton("Play from marker", filled: true, spoken: "Play from exactly the marker") {
                        controller.playFrom(start)
                    }
                    cueButton("Play into marker", filled: false, spoken: "Play from a second before the marker") {
                        controller.playFrom(max(0, start - Self.leadIn))
                    }
                }
            }
        }
        .font(Self.actionFont)
        .buttonStyle(FillButtonStyle(size: .action))
    }

    private var playPauseButton: some View {
        Button {
            controller.togglePlayPause()
        } label: {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
    }

    /// Solid coral when on, as looping is wherever the app isn't on a cover.
    private var loopButton: some View {
        Button {
            isLoopingDraft.toggle()
        } label: {
            HStack(spacing: 6) { Image(systemName: "repeat"); Text("Loop") }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(FillButtonStyle(size: .action, isOn: isLoopingDraft))
        .accessibilityLabel("Loop while editing")
        .accessibilityAddTraits(isLoopingDraft ? .isSelected : [])
    }

    private func skipButton(_ offset: TimeInterval) -> some View {
        let seconds = Int(abs(offset))
        return Button {
            controller.skip(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "gobackward.\(seconds)" : "goforward.\(seconds)")
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(offset < 0 ? "Back \(seconds) seconds" : "Forward \(seconds) seconds")
    }

    private func cueButton(
        _ title: String,
        filled: Bool,
        spoken: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(filled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.clear))
                    .strokeBorder(.secondary, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                Text(title)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(spoken)
    }
    #endif
}
