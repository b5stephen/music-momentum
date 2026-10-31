//
//  MarkerEditorView+Mac.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// The marker sheet as a Mac dialog, with its buttons along the bottom like
/// the song picker's. The iOS `Form` turned each field's placeholder into a
/// label column on the Mac and scrolled under a toolbar of glass circles.
extension MarkerEditorView {
    var macBody: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Marker" : "New Marker")
                .font(.headline)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    TextField(end == nil ? "Marker" : "Clip", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                    macKindSwitch
                }

                MarkerRangeEditor(
                    start: $start,
                    end: $end,
                    duration: duration,
                    playhead: controller.playbackTime,
                    onGrab: { selected = $0 },
                    onScrub: { controller.isScrubbing = true },
                    onSeek: { controller.endScrub(at: $0) }
                )

                VStack(alignment: .leading, spacing: 10) {
                    times
                    HStack(spacing: 6) {
                        nudge(-1)
                        nudge(-0.1)
                        nudge(0.1)
                        nudge(1)
                    }
                    .buttonStyle(.bordered)
                    if end == nil {
                        Text(canAddEnd
                            ? "Switch to Clip to give this an end time you can loop."
                            : "Too close to the end of the song for a clip.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                macTransport
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

            macButtons
        }
        .frame(width: 540)
    }

    /// Drawn by hand rather than as a segmented `Picker`, which can't show the
    /// dot and bar that say which kind is which.
    private var macKindSwitch: some View {
        HStack(spacing: 0) {
            macKindSegment(.point, title: "Point") {
                Circle().frame(width: 6, height: 6)
            }
            macKindSegment(.clip, title: "Clip") {
                SpanGlyph()
            }
            .disabled(end == nil && !canAddEnd)
        }
        .padding(2)
        .background(.quaternary, in: .rect(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kind")
    }

    private func macKindSegment(
        _ value: Kind,
        title: String,
        @ViewBuilder glyph: () -> some View
    ) -> some View {
        let isSelected = kind.wrappedValue == value
        return Button {
            kind.wrappedValue = value
        } label: {
            HStack(spacing: 6) {
                glyph()
                    .opacity(0.8)
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(
                isSelected ? AnyShapeStyle(Color.primary.opacity(0.18)) : AnyShapeStyle(.clear),
                in: .rect(cornerRadius: 5, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The cue buttons leave the song running, as on iOS. Loop sits with the
    /// transport because, like Practice's, it changes how playback runs.
    private var macTransport: some View {
        HStack(spacing: 6) {
            Button {
                controller.skip(by: -Self.skipInterval)
            } label: {
                Image(systemName: "gobackward.5")
            }
            .help("Back 5 seconds")
            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 20)
            }
            .help(controller.isPlaying ? "Pause" : "Play")
            Button {
                controller.skip(by: Self.skipInterval)
            } label: {
                Image(systemName: "goforward.5")
            }
            .help("Forward 5 seconds")
            macLoopButton

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 6)

            if let end {
                macCue("Play from start", filled: true) { controller.playFrom(start) }
                macCue("Play into end", filled: false) {
                    controller.playFrom(max(start, end - Self.leadIn))
                }
            } else {
                macCue("Play from marker", filled: true) { controller.playFrom(start) }
            }
        }
        .buttonStyle(.bordered)
    }

    /// Solid coral when on, as looping is wherever the app isn't on a cover.
    @ViewBuilder
    private var macLoopButton: some View {
        let button = Button {
            isLoopingDraft.toggle()
        } label: {
            // Set on the glyph: the prominent style ignores it on the button.
            // Off, it's left alone so the disabled state can dim it.
            if isLoopingDraft {
                Image(systemName: "repeat").foregroundStyle(Color.onAccent)
            } else {
                Image(systemName: "repeat")
            }
        }
        .disabled(end == nil)
        .help(end == nil ? "Switch to Clip to loop it" : isLoopingDraft ? "Stop looping this clip" : "Loop this clip while you edit it")
        .accessibilityLabel("Loop this clip")
        .accessibilityAddTraits(isLoopingDraft ? .isSelected : [])

        if isLoopingDraft {
            button
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
        } else {
            button
        }
    }

    private func macCue(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Circle()
                    .fill(filled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.clear))
                    .strokeBorder(.secondary, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            }
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
    }

    private var macButtons: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button("Delete…", role: .destructive) { confirmingDelete = true }
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Add") { save() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider() }
    }
}
#endif
