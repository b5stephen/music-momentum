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
    /// Set when Saved is on screen beside it rather than in another tab.
    var savedIsBeside = false
    /// Hands the cover's palette up to the tab bar and the floating card's
    /// glow, which sit outside the screen.
    var onPalette: (ArtworkPalette?) -> Void = { _ in }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var savedSongs: [SavedSong]
    @State private var showPicker = false
    @State private var markerSheet: MarkerSheet?
    /// The selected song's palette, kept so `track` doesn't rebuild it on
    /// every read: `Artwork.backgroundColor`'s, then the sampled cover's.
    @State private var palette: (songID: String, palette: ArtworkPalette?)?
    /// Measured, so a long title that wraps is allowed for.
    @State private var titleBlockHeight = PracticeLayout.Heights.standard.titleBlock
    /// Measured, so the wide layout's wheel takes exactly what the title leaves.
    @State private var wideHeaderHeight = PracticeLayout.Heights.standard.wideHeader
    /// The size the screen last laid out at; see `isDragged(to:)`.
    @State private var laidOutSize: CGSize?
    /// Measured, so the wide layout's cover takes exactly what the player leaves.
    @State private var widePlayerHeight: CGFloat = 200
    /// Measured, so the title fades out just short of a save prompt growing over it.
    @State private var headerButtonsWidth: CGFloat = 0

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
        // Spacers absorb spare height; the screen only scrolls once they've
        // given it all back.
        GeometryReader { proxy in
            let layout = PracticeLayout(size: proxy.size, heights: layoutHeights)
            ScrollView {
                VStack(spacing: 0) {
                    if let track {
                        Group {
                            if layout.isWide {
                                loadedSongWide(
                                    track,
                                    layout: layout,
                                    size: proxy.size,
                                    tabBarInset: verticalSizeClass == .compact ? proxy.safeAreaInsets.bottom : 0
                                )
                            } else {
                                loadedSong(track, layout: layout, width: proxy.size.width)
                            }
                        }
                        .animation(isDragged(to: proxy.size) ? .snappy : nil, value: layout.isCompact)
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
                .padding(.top, track == nil ? 16 : layout.isWide ? Self.wideTopPadding : layout.topMargin)
                .padding(.bottom, PracticeLayout.bottomMargin)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: proxy.size, initial: true) { _, size in
                laidOutSize = size
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
            onPalette(palette)
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

    /// Whether the compact switch should animate: only while a window is
    /// dragged across it, a few points a frame. The first layout and a
    /// rotation jump straight there; animating them slid the wheel's hub in
    /// from a size the screen never settled at.
    private func isDragged(to size: CGSize) -> Bool {
        guard let laidOutSize, laidOutSize != size else { return false }
        return abs(laidOutSize.width - size.width) < 80 && abs(laidOutSize.height - size.height) < 80
    }

    private func loadedSong(_ track: Track, layout: PracticeLayout, width: CGFloat) -> some View {
        // The wheel's frame is about 23pt emptier below its scale than above
        // it, and the scrubber's bar sits 20pt down its touch area, so equal
        // gaps looked bigger under the wheel. Spacers share spare height
        // equally whatever their minimums, so the difference is a fixed block.
        let lift = min(43, 2 * layout.wheelGap)
        return VStack(spacing: 0) {
            if layout.isCompact {
                compactNowPlaying(track, coverSide: layout.coverSide)
            } else {
                nowPlaying(track, coverSide: layout.coverSide, width: width)
            }

            // Spare height goes either side of the wheel and under the
            // player, so the header holds its edge while a floating card is
            // dragged wider and its wheel grows. Centring the whole stack
            // slid the cover 50pt up the card; giving it all to the gap under
            // the title left a tall card lopsided; held to the bottom edge,
            // the player made an iPhone Air look bottom-heavy.
            Spacer(minLength: layout.wheelGap - lift / 2)
            Color.clear.frame(height: lift)

            SpeedWheelPicker(
                speed: $controller.playbackRate,
                savedSpeed: savedSong?.speed,
                diameter: layout.wheelDiameter
            )

            Spacer(minLength: layout.wheelGap - lift / 2)

            player(layout)

            // Last, so on a screen with nothing spare the gaps above take
            // their minimums before this takes anything.
            Spacer(minLength: 0)
        }
        // Past a phone's height the gaps would only drift apart, as they did
        // on an iPad upright, so the stack centres instead. A fixed height
        // keeps it still while a card is dragged wider.
        .frame(maxHeight: PracticeLayout.maxStackedHeight)
    }

    /// Landscape phones and wide iPad windows: the song and its speed on the
    /// left, playback on the right. Stacked, the wheel would be left too
    /// short to turn and the transport would scroll under the tab bar.
    /// On a landscape phone the tab bar floats in the middle of the bottom
    /// edge, so the inset it reserves is empty beside it. The columns centre
    /// on the whole screen by dropping half of `tabBarInset`, and the player's
    /// cover gives up the height that costs it.
    private func loadedSongWide(_ track: Track, layout: PracticeLayout, size: CGSize, tabBarInset: CGFloat) -> some View {
        // Centred, the player column reaches half its height below the
        // middle, which `tabBarInset` has dropped; the transport stays clear
        // of the tab bar.
        let verticalPadding = PracticeLayout.verticalPadding
        let middle = Self.wideTopPadding + (size.height - verticalPadding) / 2 + tabBarInset / 2
        let playerColumnHeight = min(size.height - verticalPadding, 2 * (size.height - 8 - middle)) - PracticeLayout.roundingSlack
        let coverSide = min(180, playerColumnHeight - widePlayerHeight - Self.wideCoverGap)
        return HStack(spacing: 0) {
            VStack(spacing: PracticeLayout.wideHeaderGap) {
                nowPlaying(track, coverSide: nil)
                    .lineLimit(2)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        wideHeaderHeight = $0
                    }

                SpeedWheelPicker(
                    speed: $controller.playbackRate,
                    savedSpeed: savedSong?.speed,
                    diameter: layout.wheelDiameter
                )
            }
            .frame(width: PracticeLayout.wideLeadingWidth(size.width))

            VStack(spacing: 0) {
                // On a short landscape phone there's no room left for it.
                if coverSide >= 64 {
                    cover(track.artwork, side: coverSide)
                        .padding(.bottom, Self.wideCoverGap)
                }
                player(layout)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    widePlayerHeight = $0
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 960)
        .frame(maxHeight: .infinity)
        .offset(y: tabBarInset / 2)
    }

    /// Playback, then what's being practised: the clips sit under the loop
    /// button that reshapes them, with the caption saying what's looping.
    /// Every row shares `sideMargin` with the header, so the cover, the
    /// scrubber's ends, the first pill and the outer buttons line up.
    private func player(_ layout: PracticeLayout) -> some View {
        VStack(spacing: 0) {
            PlaybackScrubber(
                position: controller.playbackTime,
                duration: controller.duration,
                markers: scrubberMarkers,
                pointNameDuration: 3 * controller.playbackRate,
                onScrub: { _ in controller.isScrubbing = true },
                onCommit: { controller.endScrub(at: $0) }
            )
            .padding(.horizontal, Self.sideMargin)
            .padding(.bottom, layout.scrubberGap)

            transportControls(layout)
                .padding(.bottom, layout.transportGap)

            if layout.isCompact {
                // The caption's line is the height compact gives back; the
                // loop button and the clips' fills still say what's looping.
                HStack(spacing: 0) {
                    markerPills(trailingInset: 8)
                    markButton(showsTitle: false)
                        .padding(.trailing, Self.sideMargin - 12)
                }
            } else {
                markerPills(trailingInset: nil)

                // Mark shares the caption's line rather than taking a pill's
                // width from the row, which only fitted two and a half clips.
                HStack(spacing: 12) {
                    Text(loopCaption ?? " ")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(textTint)
                        .lineLimit(1)
                        .opacity(loopCaption == nil ? 0 : 1)
                        .accessibilityHidden(loopCaption == nil)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    markButton(showsTitle: true)
                }
                .padding(.top, 8)
                .padding(.horizontal, Self.sideMargin)
            }
        }
        .frame(maxWidth: Self.playerWidth)
    }

    /// Always laid out, so switching between songs with and without markers
    /// doesn't shift the centred stack.
    private func markerPills(trailingInset: CGFloat?) -> some View {
        MarkerPills(
            markers: savedSong?.sortedMarkers ?? [],
            inset: Self.sideMargin,
            trailingInset: trailingInset,
            isLooping: { controller.isLooping($0) },
            isLoopOn: controller.isLoopOn,
            onTap: { tapped($0) },
            onPlayLoop: { controller.playOnLoop($0) },
            onJump: { controller.jump(to: $0) },
            onEdit: { markerSheet = .edit($0) },
            onDelete: { delete($0) }
        )
    }

    private static let sideMargin: CGFloat = 24
    /// Wide enough for a precise scrubber, narrow enough that the transport's
    /// five buttons still read as one row.
    private static let playerWidth: CGFloat = 500

    private static let wideTopPadding: CGFloat = 6
    private static let wideCoverGap: CGFloat = 16

    /// Wide, the silhouette sits where the wheel's column goes, beside the copy.
    private func arrivalDiameter(_ size: CGSize) -> CGFloat {
        guard let leading = arrivalLeadingWidth(size) else {
            return max(160, PracticeLayout.wheelCap(width: size.width))
        }
        return max(150, min(280, leading - 48, size.height - PracticeLayout.verticalPadding - 32))
    }

    private func arrivalLeadingWidth(_ size: CGSize) -> CGFloat? {
        PracticeLayout.isWide(size) ? PracticeLayout.wideLeadingWidth(size.width) : nil
    }

    private var layoutHeights: PracticeLayout.Heights {
        #if canImport(UIKit)
        PracticeLayout.Heights(
            dynamicTypeSize: dynamicTypeSize,
            titleBlock: titleBlockHeight,
            wideHeader: wideHeaderHeight
        )
        #else
        PracticeLayout.Heights.standard
        #endif
    }

    /// Five controls, not six: an odd number puts play/pause dead centre.
    /// Marking moved under the pill row it adds to.
    private func transportControls(_ layout: PracticeLayout) -> some View {
        HStack(spacing: 0) {
            transportButton(
                "gobackward",
                size: layout.transportGlyph,
                label: controller.isLoopOn ? "Restart loop" : "Restart"
            ) {
                controller.restart()
            }

            Spacer(minLength: 0)

            transportButton("gobackward.10", size: layout.transportGlyph, label: "Back 10 seconds") {
                controller.skip(by: -10)
            }

            Spacer(minLength: 0)

            playButton(layout)

            Spacer(minLength: 0)

            transportButton("goforward.10", size: layout.transportGlyph, label: "Forward 10 seconds") {
                controller.skip(by: 10)
            }

            Spacer(minLength: 0)

            loopButton(layout)
        }
        // Symmetric, so play/pause stays on the centre line. Inset by the
        // touch area's slack so the glyphs, not their 44pt frames, meet the
        // scrubber's ends.
        .padding(.horizontal, Self.sideMargin - 10)
    }

    /// Compact, a bare glyph: as a disc the size of the other buttons it
    /// looked the same as the loop button switched on.
    private func playButton(_ layout: PracticeLayout) -> some View {
        Button {
            controller.togglePlayPause()
        } label: {
            if layout.isCompact {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            } else {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: layout.playSize))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
    }

    private func markButton(showsTitle: Bool) -> some View {
        Button {
            markerSheet = .new(start: controller.pauseForMarking())
        } label: {
            Group {
                if showsTitle {
                    Label {
                        Text("Mark")
                    } icon: {
                        MarkGlyph()
                            .frame(width: 15, height: 15)
                    }
                } else {
                    MarkGlyph()
                        .frame(width: 20, height: 20)
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.primary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(controller.duration == nil)
        .accessibilityLabel("Mark this point")
    }

    /// Plain like its neighbours until it's on, when it's the one control that
    /// fills: looping is the state that shouts.
    private func loopButton(_ layout: PracticeLayout) -> some View {
        Button {
            controller.toggleLoop()
        } label: {
            Image(systemName: "repeat")
                // Sized with its neighbours, not its fill: shrinking with the
                // play button left it smaller than them whenever it was off.
                .font(.system(size: layout.transportGlyph * 20 / 24, weight: .semibold))
                .frame(width: layout.loopFill, height: layout.loopFill)
                .background {
                    if controller.isLoopOn { Circle().fill(.tint) }
                }
                .foregroundStyle(controller.isLoopOn ? AnyShapeStyle(onAccent) : AnyShapeStyle(.primary))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Loop")
        .accessibilityValue(loopDescription)
        .accessibilityAddTraits(controller.isLoopOn ? .isSelected : [])
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

    private func marker(for id: AnyHashable) -> SongMarker? {
        savedSong?.markers?.first { $0.persistentModelID == id as? PersistentIdentifier }
    }

    private var scrubberMarkers: [PlaybackScrubber.Marker] {
        (savedSong?.sortedMarkers ?? []).map {
            .init(
                id: $0.persistentModelID,
                name: $0.name,
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
        size: CGFloat,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Header

    private static let headerButtonSide: CGFloat = 44
    private static let headerButtonGap: CGFloat = 8
    private static let collapsedHeaderButtons = 2 * headerButtonSide + headerButtonGap
    /// What the title always leaves beside it, so a save prompt growing over
    /// it never reflows it.
    private static let headerButtonsReserve = collapsedHeaderButtons + 10
    private static let titleFadeLength: CGFloat = 24

    /// The cover shows where the screen's colours come from. Wide, it sits
    /// over the player instead and `coverSide` is nil.
    @ViewBuilder
    private func nowPlaying(_ track: Track, coverSide: CGFloat?, width: CGFloat = 0) -> some View {
        if let coverSide {
            HStack(spacing: 14) {
                cover(track.artwork, side: coverSide, radius: coverSide / 4)
                titleBlock(track, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(alignment: .topLeading) {
                // Measured at the width the largest cover leaves, so the cover
                // shrinking can't unwrap the title and feed back into the layout.
                titleBlock(track, alignment: .leading)
                    .frame(
                        width: max(0, min(width, Self.playerWidth) - 2 * Self.sideMargin - 72 - 14 - Self.headerButtonsReserve),
                        alignment: .leading
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        titleBlockHeight = $0
                    }
            }
            .modifier(HeaderButtonsBeside(reserve: Self.headerButtonsReserve, buttons: headerButtons, fade: titleFade))
            // A floating card's corner is 40pt round; less this inset, that's
            // the cover's 16, so the two curves are concentric. At 32pt and a
            // sharper corner, a title as short as "Count on Me" wrapped on a
            // 375pt screen.
            .padding(.horizontal, Self.sideMargin)
            .frame(maxWidth: Self.playerWidth)
        } else {
            VStack(spacing: 12) {
                titleBlock(track, alignment: .center)
                headerButtons
            }
            .padding(.horizontal)
        }
    }

    private func compactNowPlaying(_ track: Track, coverSide: CGFloat) -> some View {
        HStack(spacing: 12) {
            cover(track.artwork, side: coverSide)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.headline)
                Text(track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .dynamicTypeSize(...PracticeLayout.headerTypeLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(HeaderButtonsBeside(reserve: Self.headerButtonsReserve, buttons: headerButtons, fade: titleFade))
        .padding(.horizontal, Self.sideMargin)
        .frame(maxWidth: Self.playerWidth)
    }

    /// Clear under the buttons, but only while the save prompt has grown past
    /// the room the title always leaves; collapsed, the fade sits in that room.
    private var titleFade: some View {
        let expanded = headerButtonsWidth > Self.collapsedHeaderButtons + 1
        return HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.titleFadeLength)
            Color.clear
                .frame(width: expanded ? headerButtonsWidth + 4 : 0)
        }
        .animation(.bouncy(duration: 0.4), value: headerButtonsWidth)
    }

    private var headerButtons: some View {
        HStack(spacing: Self.headerButtonGap) {
            saveButton
            changeSongButton
        }
        .dynamicTypeSize(...PracticeLayout.headerTypeLimit)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            headerButtonsWidth = $0
        }
    }

    private func titleBlock(_ track: Track, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(track.title)
                .font(.title3.bold())
            Text(track.artistName)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .center)
        .dynamicTypeSize(...PracticeLayout.headerTypeLimit)
    }

    @ViewBuilder
    private func cover(_ artwork: Artwork?, side: CGFloat, radius: CGFloat? = nil) -> some View {
        let radius = radius ?? side / 8
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

    /// Settled, a filled bookmark; the saved speed itself is the dot on the
    /// knob's scale. A different speed grows it into a prompt, which shrinks
    /// back once saved. One view throughout, so the glass morphs rather than
    /// cross-fading between two buttons.
    private var saveButton: some View {
        let percent = Int((controller.playbackRate * 100).rounded())
        let saved = savedSong
        let isCurrent = saved?.percent == percent
        let title = isCurrent ? "Saved at \(percent)%"
            : saved != nil ? "Update saved speed to \(percent)%"
            : "Save at \(percent)%"

        return Button {
            controller.saveCurrentSong()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCurrent ? "bookmark.fill" : "bookmark")
                if !isCurrent {
                    Text("Save \(percent)%")
                        .monospacedDigit()
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, isCurrent ? 0 : 14)
            .frame(minWidth: Self.headerButtonSide, minHeight: Self.headerButtonSide)
            .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(textTint))
            .modifier(HeaderGlass(prompt: isCurrent ? nil : textTint))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        // Settled, it's a label rather than a disabled button, which would
        // dim it below legible.
        .allowsHitTesting(!isCurrent)
        .accessibilityLabel(title)
        .accessibilityRemoveTraits(isCurrent ? .isButton : [])
        .animation(.bouncy(duration: 0.4), value: isCurrent)
    }

    private var changeSongButton: some View {
        Button {
            Task { showPicker = await controller.requestAuthorizationIfNeeded() }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
                .frame(width: Self.headerButtonSide, height: Self.headerButtonSide)
                .modifier(HeaderGlass(prompt: nil))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canUseMusic)
        .accessibilityLabel("Change song")
    }

    /// Reads the `@Query` results rather than fetching, so the save button restyles
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
            footnote: savedIsBeside
                ? "Or tap one of your saved songs."
                : "Or open Saved to pick up where you left off."
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

            // Tinted rather than solid, so it's the same coral as the save prompt and
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

/// The header's buttons over the title's trailing edge, with the title
/// masked so it fades out under them instead of showing through the glass.
private struct HeaderButtonsBeside<Buttons: View, Fade: View>: ViewModifier {
    var reserve: CGFloat
    var buttons: Buttons
    var fade: Fade

    func body(content: Content) -> some View {
        content
            .padding(.trailing, reserve)
            .mask(fade)
            .overlay(alignment: .trailing) { buttons }
    }
}

/// Glass for the header's buttons: tinted when it prompts, and smoked either
/// way on a bright cover, where clear glass under light text washes out.
private struct HeaderGlass: ViewModifier {
    var prompt: Color?
    @Environment(\.smokedFill) private var smokedFill

    func body(content: Content) -> some View {
        content.glassEffect(glass.interactive(), in: .capsule)
    }

    private var glass: Glass {
        if let smokedFill { return .regular.tint(smokedFill) }
        if let prompt { return .regular.tint(prompt.opacity(0.2)) }
        return .regular
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

/// The speed knob's scale and skirt with a glyph where the number would be.
private struct DialSilhouette: View {
    var diameter: CGFloat
    var systemImage: String

    var body: some View {
        let geometry = SpeedKnobGeometry(diameter: diameter)
        ZStack {
            Canvas { context, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                for percent in stride(from: SpeedKnobGeometry.minPercent, through: SpeedKnobGeometry.maxPercent, by: geometry.tickStep) {
                    let isMajor = percent.isMultiple(of: 10)
                    let angle = SpeedKnobGeometry.angle(for: Double(percent))
                    var path = Path()
                    path.move(to: SpeedKnobGeometry.point(from: centre, radius: geometry.tickInnerRadius, angle: angle))
                    path.addLine(to: SpeedKnobGeometry.point(
                        from: centre,
                        radius: geometry.tickInnerRadius + geometry.tickLength(major: isMajor),
                        angle: angle
                    ))
                    context.stroke(
                        path,
                        with: .color(.primary.opacity(0.12)),
                        style: StrokeStyle(lineWidth: isMajor ? 2.6 : 1.8, lineCap: .round)
                    )
                }
            }

            Circle()
                .strokeBorder(.quaternary, lineWidth: 1.5)
                .frame(width: geometry.skirtRadius * 2, height: geometry.skirtRadius * 2)

            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.2, weight: .light))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
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

// Sizes where the layout gives way, off the saved speed so the wheel's way back
// is showing. Fixed layouts have no safe area, so these are the space the
// screen gets, not whole devices.

#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 580)) {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)), rate: 0.72, loopOn: true)
}

#Preview("Controls giving way", traits: .fixedLayout(width: 402, height: 660)) {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)))
}

#Preview("Compact, short window", traits: .fixedLayout(width: 500, height: 436)) {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.25, green: 0.25, blue: 0.25)), rate: 0.72, loopOn: true)
}

#Preview("Compact, landscape phone", traits: .fixedLayout(width: 750, height: 350)) {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)), rate: 0.72, loopOn: true)
}

#Preview("Roomy, iPad portrait", traits: .fixedLayout(width: 834, height: 1090)) {
    loadedPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)))
}

#Preview("Landscape, nothing loaded", traits: .landscapeLeft) {
    PracticeView(controller: PlaybackController())
        .modelContainer(try! AppSchema.inMemoryContainer())
}

// The save prompt grown over the title, which fades rather than reflowing.
#Preview("Speed changed, long title") {
    loadedPreview(
        palette: ArtworkPalette(cover: OKLCH(red: 0.53, green: 0.19, blue: 0.18)),
        title: "Don't Dream It's Over (2010 Remaster)",
        artistName: "Crowded House",
        rate: 0.72
    )
}

#Preview("Speed changed, no cover colours") {
    loadedPreview(palette: nil, rate: 0.72)
}

@MainActor
private func loadedPreview(
    palette: ArtworkPalette?,
    title: String = "Little Wing",
    artistName: String = "Jimi Hendrix",
    rate: Double = 0.6,
    loopOn: Bool = false
) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong.save(
        songID: "1", title: title, artistName: artistName,
        artworkData: nil, speed: 0.6, in: container.mainContext
    )
    SongMarker.add(to: song, name: "Intro", startTime: 0, endTime: 22, in: container.mainContext)
    SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 112, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse 2", startTime: 150, endTime: nil, in: container.mainContext)
    let controller = PlaybackController()
    controller.playbackRate = rate
    if loopOn { controller.toggleLoop() }
    return PracticeView(
        controller: controller,
        previewTrack: .init(id: "1", title: title, artistName: artistName, palette: palette)
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
