//
//  PracticeView+Mac.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftData
import SwiftUI

/// Practice on the Mac: the song and its transport on the left, the knob on
/// the right, the timeline across the full width beneath. No panels, dividers
/// or cards; space separates things.
extension PracticeView {
    func macLoadedSong(_ track: Track, size: CGSize) -> some View {
        let layout = MacPracticeLayout(size: size)
        return VStack(spacing: layout.sectionGap) {
            HStack(alignment: .center, spacing: layout.heroGap) {
                macSongColumn(track, layout: layout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                macKnobColumn(layout)
            }
            macTimeline
        }
        .padding(.horizontal, layout.sideMargin)
        .padding(.top, 4)
        .padding(.bottom, layout.bottomMargin)
        .frame(maxWidth: 1392)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Song

    private func macSongColumn(_ track: Track, layout: MacPracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.columnGap) {
            HStack(spacing: 22) {
                cover(track, side: layout.coverSide, radius: 10)
                    .shadow(color: .black.opacity(0.45), radius: 22, y: 9)
                macTitleBlock(track, layout: layout)
            }
            macTransport
        }
    }

    private func macTitleBlock(_ track: Track, layout: MacPracticeLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(track.title)
                .font(.system(size: layout.titleSize, weight: .bold))
                .tracking(-0.02 * layout.titleSize)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .help(track.title)
            Text(macSubtitle(track))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 4)
            // Held at the prompt's height, so it appearing never moves the title.
            ZStack(alignment: .leading) {
                Color.clear
                if !isSpeedSaved { macSaveButton }
            }
            .frame(height: Self.macControlHeight)
            .padding(.top, 14)
            .animation(.snappy(duration: 0.2), value: isSpeedSaved)
        }
    }

    private func macSubtitle(_ track: Track) -> String {
        guard let album = track.albumTitle, !album.isEmpty else { return track.artistName }
        return "\(track.artistName) \u{2014} \(album)"
    }

    private static let macControlHeight: CGFloat = 30

    private var macSaveButton: some View {
        let percent = Int((controller.playbackRate * 100).rounded())
        return Button {
            controller.saveCurrentSong()
        } label: {
            Text("Save at \(percent)%")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 14)
                .frame(height: Self.macControlHeight)
                .modifier(ButtonGlass())
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
        .help("Save this speed for the song")
        .accessibilityLabel(savedSong != nil ? "Update saved speed to \(percent)%" : "Save at \(percent)%")
    }

    // MARK: - Transport

    private var macTransport: some View {
        HStack(spacing: 6) {
            macSkipButton("gobackward", glyph: 21, side: 40, label: controller.isLoopOn ? "Restart loop" : "Restart") {
                controller.restart()
            }
            macSkipButton("gobackward.10", glyph: 27, side: 44, label: "Back 10 seconds") {
                controller.skip(by: -10)
            }
            macPlayButton
            macSkipButton("goforward.10", glyph: 27, side: 44, label: "Forward 10 seconds") {
                controller.skip(by: 10)
            }
            Rectangle()
                .fill(.primary.opacity(0.14))
                .frame(width: 1, height: 22)
                .padding(.horizontal, 8)
                .accessibilityHidden(true)
            macLoopButton
        }
    }

    private func macSkipButton(
        _ systemImage: String, glyph: CGFloat, side: CGFloat, label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: glyph, weight: .regular))
                .frame(width: side, height: side)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    /// A solid text-colour fill with dark ink: the one control that is always
    /// "on", and the largest.
    private var macPlayButton: some View {
        Button {
            controller.togglePlayPause()
        } label: {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22))
                .foregroundStyle(onAccent)
                .frame(width: 54, height: 54)
                .background(Circle().fill(.tint))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .help(controller.isPlaying ? "Pause" : "Play")
        .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
    }

    /// Solid when on, a bare glyph when off, so looping is the state that shouts.
    private var macLoopButton: some View {
        Button {
            controller.toggleLoop()
        } label: {
            Image(systemName: "repeat")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(controller.isLoopOn ? AnyShapeStyle(onAccent) : AnyShapeStyle(.primary))
                .frame(width: 40, height: 40)
                .background { if controller.isLoopOn { Circle().fill(.tint) } }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Loop")
        .accessibilityLabel("Loop")
        .accessibilityValue(loopDescription)
        .accessibilityAddTraits(controller.isLoopOn ? .isSelected : [])
    }

    // MARK: - Knob

    private func macKnobColumn(_ layout: MacPracticeLayout) -> some View {
        VStack(spacing: 10) {
            SpeedWheelPicker(
                speed: $controller.playbackRate,
                savedSpeed: savedSong?.speed,
                diameter: layout.knobDiameter
            )
            VolumeSlider(tint: track?.palette?.foreground, hidesWhenFixed: true)
                .frame(width: layout.volumeWidth)
                .help("System volume")
        }
    }

    // MARK: - Timeline

    private var macTimeline: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                macLoopLabel
                Spacer(minLength: 0)
                macMarkButton
            }
            .frame(minHeight: Self.macControlHeight)

            PlaybackScrubber(
                position: controller.playbackTime,
                duration: controller.duration,
                markers: scrubberMarkers,
                pointNameDuration: 3 * controller.playbackRate,
                onScrub: { _ in controller.isScrubbing = true },
                onCommit: { controller.endScrub(at: $0) }
            )
            .padding(.bottom, -4)

            // Phase 4 replaces the pills with the lane. They scroll edge to edge,
            // their inset putting the first one back on the margin.
            markerPills(trailingInset: 0)
                .padding(.horizontal, -Self.sideMargin)
        }
    }

    @ViewBuilder
    private var macLoopLabel: some View {
        if let loop = controller.loop {
            let (name, detail) = macLoopText(loop)
            HStack(spacing: 10) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text("Loop off")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }

    /// What's looping, and its range and length: a single clip's range, a
    /// chain's total, the whole song's duration.
    private func macLoopText(_ loop: Loop) -> (name: String, detail: String?) {
        let segments = loop.segments
        switch segments.count {
        case 0:
            return ("Looping whole song", controller.duration.map(PlaybackScrubber.timeLabel))
        case 1:
            let segment = segments[0]
            let range = "\(PlaybackScrubber.timeLabel(segment.start)) \u{2013} \(PlaybackScrubber.timeLabel(segment.end))"
            let length = PlaybackScrubber.lengthLabel(segment.end - segment.start)
            let name = marker(for: segment.markerID)?.name
            return (name.map { "Looping \($0)" } ?? "Looping one clip", "\(range) \u{00B7} \(length)")
        default:
            let total = segments.reduce(0) { $0 + ($1.end - $1.start) }
            return ("Looping \(segments.count) clips", PlaybackScrubber.lengthLabel(total))
        }
    }

    private var macMarkButton: some View {
        Button {
            markerSheet = .new(start: controller.pauseForMarking())
        } label: {
            HStack(spacing: 6) {
                MarkGlyph()
                    .frame(width: 13, height: 13)
                Text("Mark")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 13)
            .frame(height: Self.macControlHeight)
            .modifier(ButtonGlass())
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(controller.duration == nil)
        .help("Mark this point")
        .accessibilityLabel("Mark this point")
    }
}

// MARK: - Previews

private let macCoverPalette = ArtworkPalette(cover: OKLCH(red: 0.18, green: 0.42, blue: 0.45))

@MainActor
private func macPreview(
    palette: ArtworkPalette? = macCoverPalette,
    markers: Bool = true,
    rate: Double = 0.6,
    loopOn: Bool = false,
    title: String = "Slow Burn Avenue"
) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let song = SavedSong.save(
        songID: "1", title: title, artistName: "The Kettle Lines",
        artworkData: nil, speed: 0.6, in: context
    )
    if markers {
        SongMarker.add(to: song, name: "Intro", startTime: 0, endTime: 22, in: context)
        SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 112, in: context)
        SongMarker.add(to: song, name: "Verse 2", startTime: 150, endTime: nil, in: context)
    }
    let controller = PlaybackController()
    controller.playbackRate = rate
    if loopOn { controller.toggleLoop() }
    return PracticeView(
        controller: controller,
        previewTrack: .init(
            id: "1", title: title, artistName: "The Kettle Lines", albumTitle: "Low Light Hours", palette: palette
        )
    )
    .modelContainer(container)
}

#Preview("Mac wide", traits: .fixedLayout(width: 1000, height: 740)) {
    macPreview()
}

#Preview("Mac wide, no markers", traits: .fixedLayout(width: 1000, height: 740)) {
    macPreview(markers: false)
}

#Preview("Mac wide, speed unsaved, loop on", traits: .fixedLayout(width: 1000, height: 740)) {
    macPreview(rate: 0.72, loopOn: true)
}

#Preview("Mac wide, no palette", traits: .fixedLayout(width: 1000, height: 740)) {
    macPreview(palette: nil, rate: 0.72)
}

#Preview("Mac compact", traits: .fixedLayout(width: 720, height: 600)) {
    macPreview()
}

#Preview("Mac compact, no markers", traits: .fixedLayout(width: 720, height: 600)) {
    macPreview(markers: false)
}

#Preview("Mac compact, speed unsaved, loop on", traits: .fixedLayout(width: 720, height: 600)) {
    macPreview(rate: 0.72, loopOn: true, title: "Don't Dream It's Over (2010 Remaster)")
}

#Preview("Mac compact, no palette", traits: .fixedLayout(width: 720, height: 600)) {
    macPreview(palette: nil)
}
#endif
