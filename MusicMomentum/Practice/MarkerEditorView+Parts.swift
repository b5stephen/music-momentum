//
//  MarkerEditorView+Parts.swift
//  MusicMomentum
//

import SwiftUI

/// The pieces both sheets and both platforms are built from.
extension MarkerEditorView {
    // MARK: Name

    private var suggestions: [String] {
        isLoop
            ? MarkerNameSuggestions.forLoop(among: otherLoopNames)
            : MarkerNameSuggestions.forMarker(at: start, among: otherPoints)
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
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                isSelected ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(.quaternary),
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

    #if os(macOS)
    private static let chipInset: CGFloat = 0
    #else
    private static let chipInset: CGFloat = 16
    #endif

    // MARK: Times

    var times: some View {
        // No divider: one panel is always tinted, and that separates them.
        HStack(spacing: 6) {
            if isLoop {
                timeColumn("Start", time: $start, range: startRange, handle: .start)
                timeColumn("End", time: endBinding, range: endRange, handle: .end)
            } else {
                timeColumn("Starts at", time: $start, range: startRange, handle: .start)
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
        let isSelected = selected == handle || !isLoop
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
                if !isLoop {
                    playheadChip("Set to playhead", onPanel: true)
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
        // light mode, and the coral is left to the handles.
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

    // MARK: Set to playhead

    /// The playhead read as the clock, not the song; the glyph is the strip's
    /// playhead in miniature. Where there's little room it sheds the glyph, then
    /// the words.
    func playheadChip(_ title: String, onPanel: Bool) -> some View {
        Button {
            setSelected(controller.playbackTime)
        } label: {
            ViewThatFits(in: .horizontal) {
                chipBody(onPanel: onPanel) { playheadGlyph; Text(title) }
                chipBody(onPanel: onPanel) { Text(title) }
                chipBody(onPanel: onPanel) { playheadGlyph }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var playheadGlyph: some View {
        VStack(spacing: 0) {
            Circle().frame(width: 5, height: 5)
            Capsule().frame(width: 1.5, height: 7)
        }
    }

    private func chipBody(onPanel: Bool, @ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 4, content: content)
            .font(.caption2.weight(.semibold))
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            // On the tinted panel the chip takes the cell's colour so it stands
            // off it; elsewhere it's a tint like the selected name chip.
            .background(
                onPanel ? AnyShapeStyle(Color.secondarySystemGroupedBackground) : AnyShapeStyle(.tint.opacity(0.14)),
                in: Capsule()
            )
            .foregroundStyle(Color.accentText)
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
        .padding(.vertical, 4)
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
            ViewThatFits(in: .horizontal) {
                HStack {
                    loopFacts(end: end)
                    Spacer(minLength: 8)
                    playheadChip(selected == .end ? "Set end to playhead" : "Set start to playhead", onPanel: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    loopFacts(end: end)
                    playheadChip(selected == .end ? "Set end to playhead" : "Set start to playhead", onPanel: false)
                }
            }
        } else {
            let next = SectionSpan.end(after: start, among: otherPoints, duration: duration)
            Text(next.name.map { "Runs until \($0) at \(PlaybackScrubber.timeLabel(next.time))" }
                ?? "Runs to the end of the song")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func loopFacts(end: TimeInterval) -> some View {
        let length = end - start
        let long = length < 10 ? String(format: "%.1fs", length) : PlaybackScrubber.lengthLabel(length)
        let inside = SectionSpan.name(containing: start, among: otherPoints).map { " · inside \($0)" } ?? ""
        return Text("\(long) long\(inside)")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    // MARK: Marker actions

    /// An explicit play, like Play on Loop: choosing or editing a marker never
    /// starts the song, but Preview exists to be heard. It starts a little
    /// before the marker so you hear what leads into it.
    var previewButton: some View {
        Button {
            controller.playFrom(max(0, start - Self.leadIn))
        } label: {
            HStack(spacing: 6) { Image(systemName: "play.fill"); Text("Preview") }
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Self.actionHeight)
        }
        .accessibilityLabel("Preview from just before the marker")
    }

    @ViewBuilder
    var makeLoopButton: some View {
        if onMakeLoop != nil {
            Button {
                makeLoop()
            } label: {
                HStack(spacing: 6) {
                    SpanGlyph()
                    Text("Make a loop")
                }
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Self.actionHeight)
            }
            .disabled(!canMakeLoop)
            .accessibilityHint("Saves this marker and opens a new loop from it to the end of its section")
        }
    }

    // MARK: Listening controls

    #if !os(macOS)
    /// Loop first, then the transport; the cues drop to a second row since
    /// six controls at 44pt don't fit a phone's width. The cue buttons leave
    /// the song running: a snippet that stops itself can't tell you whether the
    /// loop is the right piece of music.
    var listeningControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                loopButton
                skipButton(-Self.skipInterval)
                playPauseButton
                skipButton(Self.skipInterval)
            }

            // Each cue carries the dot of the time column it plays from.
            HStack(spacing: 8) {
                cueButton("Play from start", handle: .start, spoken: "Play from the start of the loop") {
                    controller.playFrom(start)
                }
                // Before the end, so you hear the loop run into it.
                cueButton("Play into end", handle: .end, spoken: "Play into the end of the loop") {
                    if let end { controller.playFrom(max(start, end - Self.leadIn)) }
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
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
    }

    /// Solid coral when on, as looping is wherever the app isn't on a cover.
    private var loopButton: some View {
        Button {
            isLoopingDraft.toggle()
        } label: {
            HStack(spacing: 6) { Image(systemName: "repeat"); Text("Loop") }
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(FillButtonStyle(isOn: isLoopingDraft))
        .accessibilityLabel("Loop while editing")
        .accessibilityAddTraits(isLoopingDraft ? .isSelected : [])
    }

    private func skipButton(_ offset: TimeInterval) -> some View {
        let seconds = Int(abs(offset))
        return Button {
            controller.skip(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "gobackward.\(seconds)" : "goforward.\(seconds)")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 32)
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
            HStack(spacing: 6) {
                Circle()
                    .fill(handle == .start ? AnyShapeStyle(.secondary) : AnyShapeStyle(.clear))
                    .strokeBorder(.secondary, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                Text(title)
            }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .accessibilityLabel(spoken)
    }
    #endif
}
