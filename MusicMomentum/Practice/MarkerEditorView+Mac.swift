//
//  MarkerEditorView+Mac.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftUI

/// The marker and loop sheets as a Mac dialog, with its buttons along the
/// bottom like the song picker's. The iOS `Form` turned each field's
/// placeholder into a label column on the Mac and scrolled under a toolbar of
/// glass circles.
extension MarkerEditorView {
    var macBody: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(isLoop ? "Loop" : "Marker", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                    nameChips
                }

                times

                rangeEditor

                VStack(alignment: .leading, spacing: 10) {
                    nudgeRow
                    if isLoop {
                        infoLine
                    } else {
                        // Make a loop sits on the line naming the section it
                        // would loop.
                        HStack {
                            infoLine
                            Spacer()
                            macMakeLoopButton
                        }
                    }
                }

                if isLoop {
                    macListening
                } else {
                    macMarkerListening
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

            macButtons
        }
        .frame(width: 540)
    }

    /// Loop first, then the cues, a hairline, and the transport. The cues
    /// leave the song running, as on iOS. Loop sits with the transport
    /// because, like Practice's, it changes how playback runs.
    private var macListening: some View {
        HStack(spacing: 6) {
            macLoopButton

            macHairline

            macCue("Play from start", filled: true) { controller.playFrom(start) }
            macCue("Play into end", filled: false) {
                if let end { controller.playFrom(max(start, end - Self.leadIn)) }
            }

            macHairline

            macTransport
        }
        .buttonStyle(.bordered)
    }

    /// Edit Loop's row without Loop. Play from marker starts on the exact
    /// time, to check where it lands; Play into marker is iOS's Preview,
    /// leading in so you hear what runs into it.
    private var macMarkerListening: some View {
        HStack(spacing: 6) {
            macCue("Play from marker", filled: true) { controller.playFrom(start) }
                .help("Play from exactly the marker")
            macCue("Play into marker", filled: false) { controller.playFrom(max(0, start - Self.leadIn)) }
                .help("Play from a second before the marker")

            macHairline

            macTransport
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var macMakeLoopButton: some View {
        if onMakeLoop != nil {
            Button {
                makeLoop()
            } label: {
                Label { Text("Make a loop") } icon: { SpanGlyph() }
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canMakeLoop)
            .help("Save this marker and open a new loop over its section")
        }
    }

    private var macHairline: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 6)
    }

    private var macTransport: some View {
        Group {
            Button {
                controller.skip(by: -Self.skipInterval)
            } label: {
                Image(systemName: "gobackward.5")
            }
            .help("Back 5 seconds")
            Button {
                controller.togglePlayPause()
            } label: {
                // Sized by a skip glyph: play and pause are shorter, which
                // left this button a few points lower than its neighbours.
                ZStack {
                    Image(systemName: "gobackward.5").hidden()
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                }
                .frame(minWidth: 20)
            }
            .help(controller.isPlaying ? "Pause" : "Play")
            Button {
                controller.skip(by: Self.skipInterval)
            } label: {
                Image(systemName: "goforward.5")
            }
            .help("Forward 5 seconds")
        }
    }

    /// Solid coral when on, as looping is wherever the app isn't on a cover.
    @ViewBuilder
    private var macLoopButton: some View {
        let button = Button {
            isLoopingDraft.toggle()
        } label: {
            // Set on the content: the prominent style ignores it on the button.
            if isLoopingDraft {
                Label("Loop", systemImage: "repeat").foregroundStyle(Color.onAccent)
            } else {
                Label("Loop", systemImage: "repeat")
            }
        }
        .help(isLoopingDraft ? "Stop looping while you edit" : "Loop it while you edit, so you hear every change")
        .accessibilityLabel("Loop while editing")
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
            // Still the default action, but neutral: solid coral is for looping.
            Button(isEditing ? "Save" : "Add") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.bordered)
                .tint(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider() }
    }
}
#endif
