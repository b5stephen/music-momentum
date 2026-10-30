//
//  PracticeView+Mac.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
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
        .help("Save this speed for the song (\u{2318}S)")
        .accessibilityLabel(savedSong != nil ? "Update saved speed to \(percent)%" : "Save at \(percent)%")
    }

    // MARK: - Transport

    private var macTransport: some View {
        HStack(spacing: 6) {
            macSkipButton("gobackward", glyph: 21, side: 40, label: controller.isLoopOn ? "Restart loop" : "Restart", hint: "Restart (\u{2318}\u{2190})") {
                controller.restart()
            }
            macSkipButton("gobackward.10", glyph: 27, side: 44, label: "Back 10 seconds", hint: "Back 10 seconds (\u{2190})") {
                controller.skip(by: -10)
            }
            macPlayButton
            macSkipButton("goforward.10", glyph: 27, side: 44, label: "Forward 10 seconds", hint: "Forward 10 seconds (\u{2192})") {
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
        _ systemImage: String, glyph: CGFloat, side: CGFloat, label: String, hint: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: glyph, weight: .regular))
                .frame(width: side, height: side)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(hint)
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
        .help("Play or pause (Space)")
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
        .help("Loop on or off (L)")
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
                macLoopMenu
                Spacer(minLength: 0)
                if isZoomOffered {
                    TimelineZoomControls(
                        viewport: timelineViewport, duration: controller.duration ?? 0,
                        zoomOut: macZoomOut, fit: macZoomToFit, zoomIn: macZoomIn
                    )
                    .transition(.opacity)
                }
                macMarkButton
            }
            .frame(minHeight: Self.macControlHeight)
            .animation(.easeOut(duration: 0.2), value: isZoomOffered)

            PlaybackScrubber(
                position: controller.playbackTime,
                duration: controller.duration,
                markers: scrubberMarkers,
                pointNameDuration: 3 * controller.playbackRate,
                onScrub: { _ in controller.isScrubbing = true },
                isLoopOn: controller.isLoopOn,
                laneActions: macLaneActions,
                viewport: $timelineViewport,
                onZoomNeeded: { isZoomOffered = $0 },
                onCommit: { controller.endScrub(at: $0) }
            )
        }
        .onChange(of: track?.id) { timelineViewport.fit() }
        .onChange(of: controller.playbackTime) { old, new in
            guard let duration = controller.duration else { return }
            timelineViewport.follow(playhead: new, previous: old, duration: duration)
        }
        .onChange(of: controller.loop) { _, loop in
            guard let duration = controller.duration, let range = Self.macSpan(of: loop) else { return }
            timelineViewport.reveal(range, duration: duration)
        }
    }

    /// From the first clip's start to the last one's end; `nil` for the whole
    /// song or no loop.
    private static func macSpan(of loop: Loop?) -> ClosedRange<TimeInterval>? {
        let segments = loop?.segments ?? []
        guard let first = segments.map(\.start).min(), let last = segments.map(\.end).max() else { return nil }
        return first...max(first, last)
    }

    /// Pauses and opens the marker sheet, as iOS's Mark does.
    func macMark() {
        markerSheet = .new(start: controller.pauseForMarking())
    }

    // MARK: Menu

    /// What the menus can ask of this window; see `MacCommands`.
    var macActions: PracticeActions {
        let duration = controller.duration
        let clips = savedSong?.sortedClips ?? []
        return PracticeActions(
            hasSong: track != nil,
            hasDuration: duration != nil,
            isPlaying: controller.isPlaying,
            isLoopOn: controller.isLoopOn,
            canSaveSpeed: track != nil && !isSpeedSaved,
            canZoomIn: duration.map { timelineViewport.canZoomIn(duration: $0) } ?? false,
            canZoomOut: timelineViewport.isZoomed,
            clipNames: clips.prefix(9).map(\.name),
            isBlocked: markerSheet != nil,
            playPause: { controller.togglePlayPause() },
            skip: { controller.skip(by: $0) },
            restart: { controller.restart() },
            toggleLoop: { controller.toggleLoop() },
            mark: macMark,
            stepSpeed: { up in
                let percent = Int((controller.playbackRate * 100).rounded())
                let range = SpeedKnobGeometry.minPercent...SpeedKnobGeometry.maxPercent
                controller.playbackRate = Double(SpeedInput.stepped(from: percent, up: up, in: range)) / 100
            },
            saveSpeed: { controller.saveCurrentSong() },
            loopClip: { number in
                guard clips.indices.contains(number - 1) else { return }
                macChoose(clips[number - 1], chaining: false)
            },
            zoomIn: macZoomIn,
            zoomOut: macZoomOut,
            zoomToFit: macZoomToFit
        )
    }

    // MARK: Zoom

    /// Zooming for Phase 5's menu and keys, around the playhead as the
    /// buttons do.
    func macZoomIn() { macZoom(by: TimelineViewport.step) }
    func macZoomOut() { macZoom(by: 1 / TimelineViewport.step) }
    func macZoomToFit() { timelineViewport.fit() }

    private func macZoom(by factor: Double) {
        guard let duration = controller.duration else { return }
        timelineViewport.zoom(by: factor, around: controller.playbackTime, duration: duration)
    }

    /// The lane hands back ids, never models: a menu can be open while the
    /// store changes under it.
    private var macLaneActions: MarkerLaneActions {
        MarkerLaneActions(
            clip: { macChoose($0.id, chaining: $1) },
            point: { macChoose($0.id, chaining: false) },
            jump: { if let marker = marker(for: $0.id) { controller.jump(to: marker) } },
            rename: { scrubberMarker, name in
                guard let marker = marker(for: scrubberMarker.id) else { return }
                // A blank name would become "Clip 3"; renaming keeps the old one.
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                update(marker, name: trimmed.isEmpty ? marker.name : trimmed, start: marker.startTime, end: marker.endTime)
            },
            editTimes: { if let marker = marker(for: $0.id) { markerSheet = .edit(marker) } },
            makePoint: {
                guard let marker = marker(for: $0.id) else { return }
                marker.clearEnd(in: modelContext)
                controller.markerChanged(marker)
            },
            delete: { if let marker = marker(for: $0.id) { delete(marker) } },
            createClip: { name, start, end in addMarker(name: name, start: start, end: end) },
            trimming: { scrubberMarker, start, end in
                guard let id = scrubberMarker.id as? PersistentIdentifier else { return }
                controller.reshapeLoop(for: id, start: start, end: end)
            },
            trimmed: { scrubberMarker, start, end in
                guard let marker = marker(for: scrubberMarker.id) else { return }
                marker.set(name: marker.name, start: start, end: end)
                try? modelContext.save()
                // Not `controller.markerChanged`, which seeks into the loop
                // when the playhead is outside it.
                controller.reshapeLoop(for: marker.persistentModelID, start: marker.startTime, end: marker.endTime ?? end)
            }
        )
    }

    /// With the loop off a click can only jump, as a pill tap does: only the
    /// Loop button turns looping on. With it on, a click narrows the loop to
    /// that clip and ⌘-click adds it to the chain or takes it out.
    private func macChoose(_ id: AnyHashable, chaining: Bool) {
        guard let marker = marker(for: id) else { return }
        macChoose(marker, chaining: chaining)
    }

    private func macChoose(_ marker: SongMarker, chaining: Bool) {
        guard marker.isClip, controller.isLoopOn else {
            controller.jump(to: marker)
            return
        }
        if chaining {
            controller.toggleLoop(for: marker)
        } else {
            controller.loop(only: marker)
        }
    }

    /// What's looping, and every marker by name for the cases the lane can't
    /// cover: names too long for their bar, clips stacked or too short to hit.
    /// A SwiftUI menu closes on every click, so ⌘-click adds or removes a clip
    /// and the menu closes anyway.
    private var macLoopMenu: some View {
        let markers = savedSong?.sortedMarkers ?? []
        let clips = markers.filter(\.isClip)
        let points = markers.filter { !$0.isClip }
        return Menu {
            Toggle(
                "Whole song",
                isOn: Binding(
                    get: { controller.loop == .wholeSong },
                    set: { _ in controller.loopWholeSong() }
                )
            )
            .disabled(!controller.isLoopOn)

            if !clips.isEmpty {
                Section("Clips") {
                    ForEach(Array(clips.enumerated()), id: \.element.persistentModelID) { index, clip in
                        Toggle(
                            Self.macMenuTitle(clip, number: index < 9 ? index + 1 : nil),
                            isOn: Binding(
                                get: { controller.isLooping(clip) },
                                set: { _ in macChoose(clip, chaining: NSEvent.modifierFlags.contains(.command)) }
                            )
                        )
                    }
                }
            }
            if !points.isEmpty {
                Section("Points") {
                    ForEach(points, id: \.persistentModelID) { point in
                        Button(Self.macMenuTitle(point, number: nil)) { macChoose(point, chaining: false) }
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                macLoopLabel
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.6)
            }
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose what loops, or jump to a marker. \u{2318}-click a clip to add or remove it")
        .accessibilityLabel("Loop scope")
        .accessibilityValue(loopDescription)
    }

    private static func macMenuTitle(_ marker: SongMarker, number: Int?) -> String {
        let title = "\(marker.name)  \(marker.timeLabel)"
        return number.map { "\(title)  \u{00B7}  \($0)" } ?? title
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
        Button(action: macMark) {
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
        .help("Mark this point (M)")
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
