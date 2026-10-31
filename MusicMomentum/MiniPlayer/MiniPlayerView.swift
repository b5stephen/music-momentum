//
//  MiniPlayerView.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

/// The mini player: a floating card that is its own window, painted with the
/// cover's mesh. Everything it does goes through the one controller, with the
/// same rules as Practice's timeline.
struct MiniPlayerView: View {
    @Bindable var controller: PlaybackController
    let track: PracticeView.Track?

    @Environment(MiniPlayerSwitch.self) private var miniSwitch
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.onAccent) private var onAccent
    @Query private var savedSongs: [SavedSong]
    @State private var showsWheel = false

    static let size = CGSize(width: 452, height: 120)
    private static let radius: CGFloat = 20

    private var savedSong: SavedSong? {
        guard let track else { return nil }
        return savedSongs.first { $0.matches(songID: track.id, catalogID: track.catalogID) }
    }

    var body: some View {
        Group {
            if let track {
                card(track, clips: savedSong?.sortedClips ?? [])
            } else {
                empty
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .modifier(ArtworkGround(palette: track?.palette, isPlaying: controller.isPlaying))
        .background { if track?.palette == nil { Color.systemBackground } }
        .clipShape(.rect(cornerRadius: Self.radius))
        .overlay { RoundedRectangle(cornerRadius: Self.radius).strokeBorder(.primary.opacity(0.14), lineWidth: 1) }
        .background(WindowAccessor { window in
            // A borderless window has no shadow of its own; the system draws
            // this one round the card's rounded alpha.
            window.hasShadow = true
            window.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
            DispatchQueue.main.async { window.invalidateShadow() }
        })
        // `.windowBackgroundDragBehavior` only reaches bare window, and the
        // card covers all of it. Buttons and the speed chip keep their own
        // clicks and drags; anywhere else moves the window.
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
        .onChange(of: actionsState, initial: true) { miniSwitch.actions = actions }
        .onAppear { miniSwitch.miniAppeared() }
        .onDisappear {
            miniSwitch.actions = nil
            miniSwitch.miniDisappeared()
        }
    }

    // MARK: - Card

    private func card(_ track: PracticeView.Track, clips: [SongMarker]) -> some View {
        let previous = controller.clip(.previous, in: clips)
        let next = controller.clip(.next, in: clips)
        return HStack(spacing: 14) {
            CoverArt(artwork: track.artwork, songID: track.id, side: 96, radius: 9)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        LoopScopeMenu(controller: controller, markers: savedSong?.sortedMarkers ?? [], chevronSize: 7) {
                            Text(loopCaption(clips))
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary.opacity(controller.isLoopOn ? 1 : 0.7))
                        .accessibilityValue(loopCaption(clips))
                    }
                    Spacer(minLength: 0)
                    speedChip
                }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    skipButton("backward.end.fill", label: "Previous clip", hint: "Previous clip", clip: previous)
                    playButton
                    skipButton("forward.end.fill", label: "Next clip", hint: "Next clip", clip: next)
                    Spacer(minLength: 0)
                    loopButton
                    expandButton
                }
                Spacer(minLength: 0)
                progress
            }
            .padding(.vertical, 1)
            .padding(.trailing, 2)
        }
        .padding(12)
    }

    private var empty: some View {
        HStack {
            Text("No song loaded")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            expandButton
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Speed

    private var speedPercent: Int { Int((controller.playbackRate * 100).rounded()) }

    private var speedChip: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            // Held at the widest speed's width, so the chip and the knob's
            // popover don't shift between 99 and 100.
            Text("100")
                .hidden()
                .overlay(alignment: .trailing) { Text("\(speedPercent)") }
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text("%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .opacity(0.6)
        }
        .monospacedDigit()
        .padding(.horizontal, 9)
        .frame(height: 24)
        .modifier(ButtonGlass())
        .contentShape(.capsule)
        .speedDragInput(speed: $controller.playbackRate, range: PlaybackController.speedRange)
        .onTapGesture { showsWheel.toggle() }
        .popover(isPresented: $showsWheel, arrowEdge: .bottom) { speedWheel }
        .help("Click for the speed knob; drag, scroll or \u{2191} \u{2193} to change speed")
        .accessibilityElement()
        .accessibilityLabel("Speed")
        .accessibilityValue("\(speedPercent)%")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showsWheel = true }
        .accessibilityAdjustableAction { direction in
            controller.stepSpeed(up: direction == .increment)
        }
    }

    /// Practice's knob, on the card's mesh, for anyone who clicks the chip
    /// rather than dragging it.
    private var speedWheel: some View {
        SpeedWheelPicker(speed: $controller.playbackRate, savedSpeed: savedSong?.speed, diameter: 200)
            .padding(18)
            .modifier(ArtworkGround(palette: track?.palette, isPlaying: controller.isPlaying))
    }

    // MARK: - Controls

    private func skipButton(_ systemImage: String, label: String, hint: String, clip: SongMarker?) -> some View {
        Button {
            if let clip { controller.choose(clip) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(clip == nil)
        .opacity(clip == nil ? 0.35 : 1)
        .help(clip.map { "\(hint): \($0.name)" } ?? "No \(hint.lowercased())")
        .accessibilityLabel(label)
    }

    /// A solid text-colour fill with dark ink, as on Practice.
    private var playButton: some View {
        Button {
            controller.togglePlayPause()
        } label: {
            Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 14))
                .foregroundStyle(onAccent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(.tint))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Play or pause (Space)")
        .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
    }

    private var loopButton: some View {
        Button {
            controller.toggleLoop()
        } label: {
            Image(systemName: "repeat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(controller.isLoopOn ? AnyShapeStyle(onAccent) : AnyShapeStyle(.primary))
                .frame(width: 28, height: 28)
                .background { if controller.isLoopOn { Circle().fill(.tint) } }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Loop on or off (L)")
        .accessibilityLabel("Loop")
        .accessibilityAddTraits(controller.isLoopOn ? .isSelected : [])
    }

    private var expandButton: some View {
        Button {
            miniSwitch.toggle(open: openWindow, dismiss: dismissWindow)
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .modifier(ButtonGlass())
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Open the full window (\u{2325}\u{2318}M)")
        .accessibilityLabel("Open the full window")
    }

    // MARK: - Progress

    /// The loop's clips are a lighter band under the played fill.
    private var progress: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let duration = max(controller.duration ?? 0, 0.001)
            let played = controller.duration == nil ? 0 : width * min(max(controller.playbackTime / duration, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.16))
                ForEach(Array((controller.loop?.segments ?? []).enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(.primary.opacity(0.28))
                        .frame(width: max(2, width * (segment.end - segment.start) / duration))
                        .offset(x: width * segment.start / duration)
                }
                Capsule().fill(.primary).frame(width: played)
            }
            .clipShape(.capsule)
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(PlaybackScrubber.timeLabel(controller.playbackTime))
    }

    // MARK: - State

    private func loopCaption(_ clips: [SongMarker]) -> String {
        let looping: [LoopCaption.Clip] = (controller.loop?.segments ?? []).map { segment in
            .init(name: clips.first { $0.persistentModelID == segment.markerID }?.name, length: segment.end - segment.start)
        }
        return LoopCaption.text(isOn: controller.isLoopOn, clips: looping)
    }

    /// What the menus can ask of the mini player while it is the key window;
    /// see `MacCommands`. Anything that needs Practice's screen (marking,
    /// zooming) stays off.
    /// What `actions` is built from, so it's handed to the menus again
    /// whenever one of its flags or the clips its 1-9 keys reach change.
    private struct ActionsState: Equatable {
        var songID: String?
        var hasDuration: Bool
        var isPlaying: Bool
        var isLoopOn: Bool
        var canSaveSpeed: Bool
        var clips: [PersistentIdentifier]
        var clipNames: [String]
    }

    private var actionsState: ActionsState {
        let clips = savedSong?.sortedClips ?? []
        return ActionsState(
            songID: track?.id,
            hasDuration: controller.duration != nil,
            isPlaying: controller.isPlaying,
            isLoopOn: controller.isLoopOn,
            canSaveSpeed: track != nil && savedSong?.percent != speedPercent,
            clips: clips.map(\.persistentModelID),
            clipNames: clips.prefix(9).map(\.name)
        )
    }

    private var actions: PracticeActions {
        let clips = savedSong?.sortedClips ?? []
        return PracticeActions(
            hasSong: track != nil,
            hasDuration: controller.duration != nil,
            isPlaying: controller.isPlaying,
            isLoopOn: controller.isLoopOn,
            canSaveSpeed: track != nil && savedSong?.percent != speedPercent,
            canMark: false,
            clipNames: clips.prefix(9).map(\.name),
            playPause: { controller.togglePlayPause() },
            skip: { controller.skip(by: $0) },
            restart: { controller.restart() },
            toggleLoop: { controller.toggleLoop() },
            stepSpeed: { controller.stepSpeed(up: $0) },
            saveSpeed: { controller.saveCurrentSong() },
            loopClip: { number in
                guard clips.indices.contains(number - 1) else { return }
                controller.choose(clips[number - 1])
            }
        )
    }
}

// MARK: - Previews

private let previewPalette = ArtworkPalette(cover: OKLCH(red: 0.18, green: 0.42, blue: 0.45))

@MainActor
private func miniPreview(palette: ArtworkPalette? = previewPalette, loop: Bool = true, rate: Double = 0.75) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let song = SavedSong.save(
        songID: "1", title: "Harbour Lights", artistName: "Mara Ellis",
        artworkData: nil, speed: 0.75, in: context
    )
    SongMarker.add(to: song, name: "Intro riff", startTime: 0, endTime: 24, in: context)
    let chorus = SongMarker.add(to: song, name: "Chorus", startTime: 62, endTime: 96, in: context)
    SongMarker.add(to: song, name: "Solo", startTime: 142, endTime: 170, in: context)
    let controller = PlaybackController()
    #if DEBUG
    controller.sampleDuration = 260
    #endif
    controller.playbackRate = rate
    if loop {
        controller.toggleLoop()
        controller.loop(only: chorus)
    }
    controller.seek(to: 80)
    return MiniPlayerView(
        controller: controller,
        track: .init(id: "1", title: "Harbour Lights", artistName: "Mara Ellis", palette: palette)
    )
    .padding(24)
    .environment(MiniPlayerSwitch())
    .modelContainer(container)
}

#Preview("Looping a clip", traits: .fixedLayout(width: 500, height: 168)) {
    miniPreview()
}

#Preview("Loop off", traits: .fixedLayout(width: 500, height: 168)) {
    miniPreview(loop: false, rate: 1.0)
}

#Preview("No palette", traits: .fixedLayout(width: 500, height: 168)) {
    miniPreview(palette: nil)
}
#endif
