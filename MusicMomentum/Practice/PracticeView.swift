//
//  PracticeView.swift
//  MusicMomentum
//

import MusicKit
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PracticeView: View {
    @Bindable var controller: PlaybackController
    /// Stands in for `controller.selectedSong` in previews, since `Song` has
    /// no public initialiser.
    var previewTrack: Track?
    /// Hands the practice screen's tint up to the tab bar, which sits outside it.
    var onTint: (Color?) -> Void = { _ in }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var savedSongs: [SavedSong]
    @State private var showPicker = false
    @State private var markerSheet: MarkerSheet?
    /// The selected song's palette, kept so `track` doesn't rebuild it on
    /// every read: `Artwork.backgroundColor`'s, then the sampled cover's.
    @State private var palette: (songID: String, palette: ArtworkPalette?)?
    /// Measured, so the wide layout's wheel takes exactly what the title leaves.
    @State private var wideHeaderHeight: CGFloat = 110

    /// Editing carries the marker's identity so switching straight from one
    /// marker to another rebuilds the sheet.
    private enum MarkerSheet: Identifiable {
        case new(start: TimeInterval)
        case edit(SongMarker)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let marker): "edit-\(marker.persistentModelID.hashValue)"
            }
        }
    }

    /// What the loaded screen shows of the song.
    struct Track {
        var id: String
        var title: String
        var artistName: String
        var palette: ArtworkPalette?
        var artwork: Artwork?
    }

    private var track: Track? {
        guard let song = controller.selectedSong else { return previewTrack }
        return Track(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            palette: palette?.songID == song.id.rawValue
                ? palette?.palette
                : ArtworkPalette(song.artwork),
            artwork: song.artwork
        )
    }

    /// Tinted text: the cover's text colour, or the coral that stays legible on white.
    private var textTint: Color { track?.palette?.foreground ?? .accentText }

    private var onAccent: Color { track?.palette?.background ?? .onAccent }

    var body: some View {
        // Spacers absorb spare height (below the controls with a song loaded on
        // a phone, around everything on an iPad or without a song); the screen
        // only scrolls once they've given it all back.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if let track {
                        if Self.isWide(proxy.size) {
                            loadedSongWide(track, size: proxy.size)
                        } else {
                            loadedSong(track, size: proxy.size)
                        }
                    } else if controller.isRestoringLastSong {
                        RestoringState(
                            diameter: arrivalDiameter(proxy.size),
                            leadingWidth: arrivalLeadingWidth(proxy.size)
                        )
                    } else if controller.canUseMusic {
                        noSong(size: proxy.size)
                    } else {
                        noAccess(size: proxy.size)
                    }

                    messages
                }
                .padding(.top, track == nil ? 16 : 6)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .modifier(ArtworkGround(palette: track?.palette, isPlaying: controller.isPlaying))
        .task(id: controller.selectedSong?.id) {
            guard let song = controller.selectedSong else { return }
            if palette?.songID != song.id.rawValue {
                palette = (song.id.rawValue, ArtworkPalette(song.artwork))
            }
            // A superseded song's sample can land after the next song's
            // fallback was cached, and would evict it.
            guard let sampled = await ArtworkPalette.sampled(from: song), !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                palette = (song.id.rawValue, sampled)
            }
        }
        .onChange(of: track?.palette, initial: true) { _, palette in
            onTint(palette?.foreground)
        }
        .sheet(isPresented: $showPicker) {
            SongPickerView { song in
                Task { await controller.select(song: song) }
            }
            .tint(nil as Color?)
        }
        .sheet(item: $markerSheet) { sheet in
            Group {
                if let duration = controller.duration {
                    switch sheet {
                    case .new(let start):
                        MarkerEditorView(
                            initialStart: start,
                            duration: duration,
                            controller: controller,
                            onSave: addMarker
                        )
                    case .edit(let marker):
                        MarkerEditorView(
                            marker: marker,
                            duration: duration,
                            controller: controller,
                            onSave: { name, start, end in update(marker, name: name, start: start, end: end) },
                            onDelete: { delete(marker) }
                        )
                    }
                }
            }
            // `RootTabView` tints the tab bar with the cover's near-white text
            // colour, and sheets inherit it; on a light sheet it all but vanishes.
            // Cleared rather than set to the accent: an explicit tint also turns
            // the toolbar's Close coral, which a sheet from Saved doesn't do.
            .tint(nil as Color?)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.refreshPlaybackTime() }
        }
    }

    // MARK: - Practising

    @ViewBuilder
    private func loadedSong(_ track: Track, size: CGSize) -> some View {
        // On an iPad-sized window the spare height is too much to leave under
        // the controls, so the stack sits in the middle instead.
        if size.width >= Self.roomyWidth {
            Spacer(minLength: 0)
        }

        nowPlaying(track)

        wheelGap

        SpeedWheelPicker(
            speed: $controller.playbackRate,
            savedSpeed: savedSong?.speed,
            diameter: min(wheelDiameter(width: size.width), max(150, size.height - Self.controlsHeight))
        )

        wheelGap

        timeline
            .frame(maxWidth: Self.roomyWidth)
            .padding(.bottom, 34)

        transportControls

        loopCaptionLine

        // Past the wheel gaps' 30pt, spare height collects above the tab bar
        // rather than spreading the controls apart on tall phones.
        Spacer(minLength: 0)
    }

    /// Landscape phones and wide iPad windows: the song and its speed on the
    /// left, playback on the right. Stacked, the wheel would be left too
    /// short to turn and the transport would scroll under the tab bar.
    private func loadedSongWide(_ track: Track, size: CGSize) -> some View {
        let leading = Self.wideLeadingWidth(size.width)
        let diameter = Self.wideWheelDiameter(
            width: leading,
            height: size.height - Self.verticalPadding - wideHeaderHeight - Self.wideHeaderGap
        )
        let coverSide = min(180, size.height - Self.verticalPadding - Self.widePlayerHeight - Self.wideCoverGap)
        return HStack(alignment: .wheelCentre, spacing: 0) {
            VStack(spacing: Self.wideHeaderGap) {
                nowPlaying(track, showsCover: false)
                    .lineLimit(2)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        wideHeaderHeight = $0
                    }

                SpeedWheelPicker(
                    speed: $controller.playbackRate,
                    savedSpeed: savedSong?.speed,
                    diameter: diameter
                )
                .alignmentGuide(.wheelCentre) { $0[VerticalAlignment.center] }
            }
            .frame(width: leading)

            VStack(spacing: 0) {
                // On a short landscape phone there's no room left for it.
                if coverSide >= 64 {
                    cover(track.artwork, side: coverSide)
                        .padding(.bottom, Self.wideCoverGap)
                }
                timeline
                    .padding(.bottom, 24)
                transportControls
                loopCaptionLine
            }
            .alignmentGuide(.wheelCentre) { $0[VerticalAlignment.center] }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 960)
        .frame(maxHeight: .infinity)
    }

    // Always laid out so toggling the loop doesn't shift everything above it.
    private var loopCaptionLine: some View {
        Text(loopCaption ?? " ")
            .font(.footnote.weight(.medium))
            .foregroundStyle(textTint)
            .lineLimit(1)
            .opacity(loopCaption == nil ? 0 : 1)
            .accessibilityHidden(loopCaption == nil)
            .padding(.top, 14)
            .padding(.horizontal, 24)
    }

    /// Wider than tall, and with room for the transport beside the wheel.
    private static func isWide(_ size: CGSize) -> Bool {
        size.width > size.height && size.width >= 700
    }

    /// The top and bottom padding round the screen's content.
    private static let verticalPadding: CGFloat = 22
    private static let wideHeaderGap: CGFloat = 20
    /// Roughly the timeline, marker pills, transport and loop caption.
    private static let widePlayerHeight: CGFloat = 230
    private static let wideCoverGap: CGFloat = 24

    /// Grows with the window up to what the wheel needs, and never takes so
    /// much that the transport's five controls are squeezed.
    private static func wideLeadingWidth(_ width: CGFloat) -> CGFloat {
        min(380, width * 0.46)
    }

    private static func wideWheelDiameter(width: CGFloat, height: CGFloat) -> CGFloat {
        max(150, min(320, width - 48, height))
    }

    /// Gives up height on short phones before the screen has to scroll.
    private var wheelGap: some View {
        Spacer(minLength: 16).frame(maxHeight: 30)
    }

    /// Roughly everything on the loaded screen but the wheel. Subtracted from
    /// the height so on a short phone the wheel shrinks and the transport
    /// stays above the tab bar instead of scrolling under it.
    private static let controlsHeight: CGFloat = 420

    private func wheelDiameter(width: CGFloat) -> CGFloat {
        min(width >= Self.roomyWidth ? 320 : 260, max(160, width - 130))
    }

    /// Past a phone's width: the wheel grows to the wide layout's size, so
    /// resizing an iPad window between the layouts doesn't resize the wheel.
    private static let roomyWidth: CGFloat = 600

    /// Wide, the silhouette sits where the wheel's column goes, beside the copy.
    private func arrivalDiameter(_ size: CGSize) -> CGFloat {
        guard let leading = arrivalLeadingWidth(size) else { return wheelDiameter(width: size.width) }
        return Self.wideWheelDiameter(width: leading, height: size.height - Self.verticalPadding - 32)
    }

    private func arrivalLeadingWidth(_ size: CGSize) -> CGFloat? {
        Self.isWide(size) ? Self.wideLeadingWidth(size.width) : nil
    }

    @ViewBuilder
    private var timeline: some View {
        VStack(spacing: 10) {
            PlaybackScrubber(
                position: controller.playbackTime,
                duration: controller.duration,
                markers: scrubberMarkers,
                onScrub: { _ in controller.isScrubbing = true },
                onCommit: { controller.endScrub(at: $0) }
            )
            .padding(.horizontal, 32)

            if let saved = savedSong, !saved.sortedMarkers.isEmpty {
                MarkerPills(
                    markers: saved.sortedMarkers,
                    isLooping: { controller.isLooping($0) },
                    isCued: { isCued($0) },
                    onTap: { tapped($0) },
                    onPlayLoop: { controller.playOnLoop($0) },
                    onJump: { controller.jump(to: $0) },
                    onEdit: { markerSheet = .edit($0) },
                    onDelete: { delete($0) }
                )
            }
        }
    }

    /// Five controls, not six: an odd number puts play/pause dead centre.
    /// Restart was dropped — dragging to the start does the same job.
    private var transportControls: some View {
        HStack(spacing: 0) {
            loopButton
                .frame(maxWidth: .infinity)

            transportButton("gobackward.10", label: "Back 10 seconds") {
                controller.skip(by: -10)
            }
            .frame(maxWidth: .infinity)

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
            .frame(maxWidth: .infinity)

            transportButton("goforward.10", label: "Forward 10 seconds") {
                controller.skip(by: 10)
            }
            .frame(maxWidth: .infinity)

            markButton
                .frame(maxWidth: .infinity)
        }
        // Equal shares rather than a fixed gap keeps play/pause on the centre
        // line at any width, and the ends on screen on a 390pt phone.
        .frame(maxWidth: 430)
        .padding(.horizontal, 12)
    }

    private var loopButton: some View {
        Button {
            controller.toggleLoop()
        } label: {
            Image(systemName: "repeat")
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(
                    controller.isLoopOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    in: Circle()
                )
                .foregroundStyle(controller.isLoopOn ? AnyShapeStyle(onAccent) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Loop")
        .accessibilityValue(loopDescription)
        .accessibilityAddTraits(controller.isLoopOn ? .isSelected : [])
    }

    private var markButton: some View {
        Button {
            markerSheet = .new(start: controller.pauseForMarking())
        } label: {
            MarkGlyph()
                .frame(width: 22, height: 22)
                .frame(width: 46, height: 46)
                .background(.quaternary, in: Circle())
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(controller.duration == nil)
        .accessibilityLabel("Mark this point")
    }

    private var loopCaption: String? {
        guard let loop = controller.loop else { return nil }
        let segments = loop.segments
        switch segments.count {
        case 0:
            return "Looping whole song"
        case 1:
            guard let name = marker(for: segments[0].markerID)?.name else { return "Looping one clip" }
            return "Looping \(name)"
        default:
            let total = segments.reduce(0) { $0 + ($1.end - $1.start) }
            return "Looping \(segments.count) clips · \(PlaybackScrubber.lengthLabel(total))"
        }
    }

    /// For VoiceOver: the caption is a separate element to the button.
    private var loopDescription: String {
        guard let loop = controller.loop else { return "Off" }
        let clips = loop.segments.count
        switch clips {
        case 0: return "Whole song"
        case 1: return "One clip"
        default: return "\(clips) clips"
        }
    }

    // MARK: - Markers

    /// With the loop off a tap navigates; with it on, a clip tap reshapes the
    /// scope instead (the menu's Jump to Start still navigates).
    private func tapped(_ marker: SongMarker) {
        if controller.isLoopOn, marker.isClip {
            controller.toggleLoop(for: marker)
        } else {
            controller.jump(to: marker)
        }
    }

    /// Playhead inside this clip with the loop off.
    private func isCued(_ marker: SongMarker) -> Bool {
        guard !controller.isLoopOn, let end = marker.endTime else { return false }
        return controller.playbackTime >= marker.startTime && controller.playbackTime < end
    }

    private func marker(for id: AnyHashable) -> SongMarker? {
        savedSong?.markers?.first { $0.persistentModelID == id as? PersistentIdentifier }
    }

    private var scrubberMarkers: [PlaybackScrubber.Marker] {
        (savedSong?.sortedMarkers ?? []).map {
            .init(
                id: $0.persistentModelID,
                start: $0.startTime,
                end: $0.endTime,
                isLooping: controller.isLooping($0)
            )
        }
    }

    /// Markers live on the saved entry, so marking an unsaved song saves it.
    private func addMarker(name: String, start: TimeInterval, end: TimeInterval?) {
        guard let song = savedSong ?? controller.saveCurrentSong() else { return }
        SongMarker.add(to: song, name: name, startTime: start, endTime: end, in: modelContext)
    }

    private func update(_ marker: SongMarker, name: String, start: TimeInterval, end: TimeInterval?) {
        marker.set(name: name, start: start, end: end)
        try? modelContext.save()
        controller.markerChanged(marker)
    }

    private func delete(_ marker: SongMarker) {
        controller.markerDeleted(marker)
        SongMarker.delete(marker, in: modelContext)
    }

    private func transportButton(
        _ systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Header

    /// The cover shows where the screen's colours come from. Wide, it sits
    /// over the player instead.
    private func nowPlaying(_ track: Track, showsCover: Bool = true) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                if showsCover {
                    cover(track.artwork, side: 64)
                }

                VStack(alignment: showsCover ? .leading : .center, spacing: 4) {
                    Text(track.title)
                        .font(.title2.bold())
                    Text(track.artistName)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(showsCover ? .leading : .center)
            }

            HStack(spacing: 8) {
                saveChip
                changeSongChip
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func cover(_ artwork: Artwork?, side: CGFloat) -> some View {
        let radius = side / 8
        if let artwork {
            ArtworkImage(artwork, width: side, height: side)
                .clipShape(.rect(cornerRadius: radius))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: radius)
                .fill(.quaternary)
                .frame(width: side, height: side)
                .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var saveChip: some View {
        let percent = Int((controller.playbackRate * 100).rounded())
        let saved = savedSong
        let isCurrent = saved?.percent == percent

        // Settled, it's a label rather than a disabled button, which would
        // dim it below legible.
        if isCurrent {
            chipLabel("Saved at \(percent)%", systemImage: "bookmark.fill", isPrompting: false)
        } else {
            Button {
                controller.saveCurrentSong()
            } label: {
                if saved != nil {
                    chipLabel("Update to \(percent)%", systemImage: "bookmark.fill", isPrompting: true)
                } else {
                    chipLabel("Save at \(percent)%", systemImage: "bookmark", isPrompting: true)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var changeSongChip: some View {
        Button {
            Task { showPicker = await controller.requestAuthorizationIfNeeded() }
        } label: {
            chipLabel("Change song", systemImage: "arrow.left.arrow.right", isPrompting: false)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canUseMusic)
    }

    private func chipLabel(_ title: String, systemImage: String, isPrompting: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { ChipFill(isPrompting: isPrompting) }
            .foregroundStyle(isPrompting ? AnyShapeStyle(textTint) : AnyShapeStyle(.secondary))
    }

    /// Reads the `@Query` results rather than fetching, so the chip restyles
    /// the moment the store changes — including from the Saved tab.
    private var savedSong: SavedSong? {
        guard let songID = track?.id else { return nil }
        return savedSongs.first { $0.songID == songID }
    }

    // MARK: - Arriving

    @ViewBuilder
    private func noSong(size: CGSize) -> some View {
        ArrivalState(
            diameter: arrivalDiameter(size),
            leadingWidth: arrivalLeadingWidth(size),
            systemImage: "music.note.list",
            headline: "Nothing loaded yet",
            detail: "Pick a song from Apple Music and slow it down to a speed you can actually play.",
            actionTitle: "Choose a Song",
            footnote: "Or open Saved to pick up where you left off."
        ) {
            Task { showPicker = await controller.requestAuthorizationIfNeeded() }
        }
    }

    /// Once denied the system won't prompt again, so the button goes to Settings.
    @ViewBuilder
    private func noAccess(size: CGSize) -> some View {
        ArrivalState(
            diameter: arrivalDiameter(size),
            leadingWidth: arrivalLeadingWidth(size),
            systemImage: "lock",
            headline: "Apple Music access needed",
            detail: "Music Momentum plays songs from your own library and Apple Music. It can't reach either one until you allow it.",
            actionTitle: "Open Settings",
            footnote: "Settings › Music Momentum › Media & Apple Music"
        ) {
            #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messages: some View {
        VStack(spacing: 8) {
            if let warning = controller.rateWarning {
                banner(warning, systemImage: "exclamationmark.triangle.fill", icon: .yellow, background: .yellow.opacity(0.18))
            }
            if let error = controller.errorMessage {
                banner(error, systemImage: "exclamationmark.circle.fill", icon: .accentColor, background: .gray.opacity(0.14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, controller.rateWarning == nil && controller.errorMessage == nil ? 0 : 16)
    }

    private func banner(
        _ text: String,
        systemImage: String,
        icon: Color,
        background: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(icon)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// The practice screen with no song: the dial's silhouette above the copy,
/// the pair centred. Pinned to the top like the loaded wheel, it left the
/// copy stranded at the bottom of a phone with a void between them.
private struct ArrivalState: View {
    var diameter: CGFloat
    /// Set when wide: the silhouette's column, beside the copy.
    var leadingWidth: CGFloat?
    var systemImage: String
    var headline: String
    var detail: String
    var actionTitle: String
    var footnote: String
    var action: () -> Void

    var body: some View {
        if let leadingWidth {
            HStack(spacing: 0) {
                DialSilhouette(diameter: diameter, systemImage: systemImage)
                    .frame(width: leadingWidth)
                copy
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 960, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 16)

                DialSilhouette(diameter: diameter, systemImage: systemImage)

                Spacer(minLength: 16)
                    .frame(maxHeight: 40)

                copy
                    .frame(maxWidth: 480)

                Spacer(minLength: 16)
            }
            // So its own gaps, not the stack around it, absorb the spare space.
            .frame(maxHeight: .infinity)
        }
    }

    private var copy: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(headline)
                    .font(.title2.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            // Tinted rather than solid, so it's the same coral as the chips and
            // speed pills: a solid fill reads as a brighter, other colour. Drawn
            // by hand because `.bordered` turns grey once its text is recoloured.
            Button(action: action) {
                Text(actionTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentText)
                    .frame(height: 50)
                    .padding(.horizontal, 30)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 24)

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 40)
        }
    }
}

/// Paints the loaded screen in the cover's colours. Covers without colours
/// keep the system look and the coral tint.
private struct ArtworkGround: ViewModifier {
    let palette: ArtworkPalette?
    /// The mesh drifts while the song plays, as Apple Music's does, and holds
    /// still while it's paused.
    var isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = DriftClock()

    func body(content: Content) -> some View {
        if let palette {
            content
                .foregroundStyle(palette.foreground)
                .tint(palette.foreground)
                .backgroundStyle(palette.background)
                .environment(\.onAccent, palette.background)
                .environment(\.smokedFill, palette.isBright ? palette.shadow.opacity(0.24) : nil)
                .environment(\.colorScheme, .dark)
                .background { backdrop(palette) }
        } else {
            content
        }
    }

    /// Darkening from a third of the way down, as Apple Music's does,
    /// towards the cover's own colour: black greys it and turns gold olive.
    private func backdrop(_ palette: ArtworkPalette) -> some View {
        let drifts = isPlaying && !reduceMotion
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: !drifts)) { context in
            MeshGradient(
                width: 3,
                height: 3,
                points: Self.points(at: clock.time(at: context.date, running: drifts)),
                colors: palette.mesh
            )
        }
        .overlay {
            LinearGradient(
                stops: [.init(color: .clear, location: 0.35), .init(color: palette.shadow.opacity(0.55), location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Corners stay put and edge points only slide along their edge, so the
    /// mesh always covers the screen. Periods share no common factor, so the
    /// pattern doesn't visibly repeat.
    private static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        func wave(_ period: Double, _ phase: Double) -> Float {
            Float(sin(time * 2 * .pi / period + phase))
        }
        return [
            [0, 0], [0.5 + 0.15 * wave(23, 0), 0], [1, 0],
            [0, 0.5 + 0.12 * wave(19, 1)], [0.5 + 0.18 * wave(17, 2), 0.5 + 0.15 * wave(29, 3)], [1, 0.5 + 0.12 * wave(31, 4)],
            [0, 1], [0.5 + 0.15 * wave(37, 5), 1], [1, 1],
        ]
    }
}

/// Time that only passes while the song plays, so a paused mesh resumes from
/// where it stopped rather than jumping ahead.
private final class DriftClock {
    private var banked: TimeInterval = 0
    private var runningSince: Date?

    func time(at date: Date, running: Bool) -> TimeInterval {
        if running, runningSince == nil {
            runningSince = date
        } else if !running, let since = runningSince {
            banked += date.timeIntervalSince(since)
            runningSince = nil
        }
        return banked + (runningSince.map { date.timeIntervalSince($0) } ?? 0)
    }
}

/// A chip's capsule: tinted when it prompts, light glass when settled, and
/// smoked either way on a bright cover.
private struct ChipFill: View {
    var isPrompting: Bool
    @Environment(\.smokedFill) private var smokedFill

    var body: some View {
        if let smokedFill {
            Capsule().fill(smokedFill)
        } else {
            Capsule().fill(isPrompting ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(.quaternary))
        }
    }
}

/// Last launch's song is on its way: the silhouette, with a spinner where the
/// arrival copy goes, so a song landing looks the same as it does from the picker.
private struct RestoringState: View {
    var diameter: CGFloat
    var leadingWidth: CGFloat?

    var body: some View {
        if let leadingWidth {
            HStack(spacing: 0) {
                DialSilhouette(diameter: diameter, systemImage: "music.note.list")
                    .frame(width: leadingWidth)
                spinner
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 960, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 16)

                DialSilhouette(diameter: diameter, systemImage: "music.note.list")

                Spacer(minLength: 16)
                    .frame(maxHeight: 40)

                spinner

                Spacer(minLength: 16)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var spinner: some View {
        ProgressView()
            .controlSize(.large)
            .accessibilityLabel("Loading your last song")
    }
}

/// The speed wheel's rim and teeth with a glyph where the number would be.
private struct DialSilhouette: View {
    var diameter: CGFloat
    var systemImage: String

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.quaternary, lineWidth: 6)
                .padding(9)

            Canvas { context, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let outer = size.width / 2 - 28
                for index in 0..<90 {
                    let isMajor = index % 5 == 0
                    let angle = Angle.degrees(Double(index) * 4)
                    var path = Path()
                    path.move(to: point(from: centre, radius: outer, angle: angle))
                    path.addLine(to: point(from: centre, radius: outer - (isMajor ? 14 : 8), angle: angle))
                    context.stroke(
                        path,
                        with: .color(.primary.opacity(0.12)),
                        style: StrokeStyle(lineWidth: isMajor ? 2 : 1.5, lineCap: .round)
                    )
                }
            }

            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.2, weight: .light))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private func point(from centre: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: centre.x + radius * cos(angle.radians),
            y: centre.y + radius * sin(angle.radians)
        )
    }
}

#Preview {
    PracticeView(controller: PlaybackController())
        .modelContainer(try! AppSchema.inMemoryContainer())
}

#Preview("Dark cover") {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)))
}

#Preview("Bright cover") {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.88, green: 0.64, blue: 0.05)))
}

#Preview("Grey cover") {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.25, green: 0.25, blue: 0.25)))
}

#Preview("Cover without colours") {
    loadedPreview(palette: nil)
}

#Preview("Landscape", traits: .landscapeLeft) {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)))
}

#Preview("Landscape, nothing loaded", traits: .landscapeLeft) {
    PracticeView(controller: PlaybackController())
        .modelContainer(try! AppSchema.inMemoryContainer())
}

@MainActor
private func loadedPreview(palette: ArtworkPalette?) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong.save(
        songID: "1", title: "Little Wing", artistName: "Jimi Hendrix",
        artworkData: nil, speed: 0.6, in: container.mainContext
    )
    SongMarker.add(to: song, name: "Intro", startTime: 0, endTime: 22, in: container.mainContext)
    SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 112, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse 2", startTime: 150, endTime: nil, in: container.mainContext)
    let controller = PlaybackController()
    controller.playbackRate = 0.6
    return PracticeView(
        controller: controller,
        previewTrack: .init(id: "1", title: "Little Wing", artistName: "Jimi Hendrix", palette: palette)
    )
    .modelContainer(container)
}

#Preview("Nothing loaded") {
    ArrivalState(
        diameter: 260,
        systemImage: "music.note.list",
        headline: "Nothing loaded yet",
        detail: "Pick a song from Apple Music and slow it down to a speed you can actually play.",
        actionTitle: "Choose a Song",
        footnote: "Or open Saved to pick up where you left off."
    ) {}
        .padding(.vertical, 16)
}

#Preview("Restoring") {
    RestoringState(diameter: 260)
        .padding(.vertical, 16)
}

#Preview("No access") {
    ArrivalState(
        diameter: 260,
        systemImage: "lock",
        headline: "Apple Music access needed",
        detail: "Music Momentum plays songs from your own library and Apple Music. It can't reach either one until you allow it.",
        actionTitle: "Open Settings",
        footnote: "Settings › Music Momentum › Media & Apple Music"
    ) {}
        .padding(.vertical, 16)
}

private extension VerticalAlignment {
    /// Lines the wide layout's playback column up with the wheel's centre
    /// rather than the title above it.
    enum WheelCentre: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let wheelCentre = VerticalAlignment(WheelCentre.self)
}
