//
//  MenuBarPanel.swift
//  MusicMomentum
//

#if os(macOS)
import SwiftData
import SwiftUI

/// The menu bar extra's panel: the song, the five usual speeds and the clips,
/// on the cover's mesh, so a guitar can stay in hand.
struct MenuBarPanel: View {
    @Bindable var controller: PlaybackController
    let track: PracticeView.Track?

    @Environment(MiniPlayerSwitch.self) private var miniSwitch
    @Environment(\.openWindow) private var openWindow
    @Environment(\.onAccent) private var onAccent
    @Query private var savedSongs: [SavedSong]
    @State private var hoveredClip: PersistentIdentifier?

    private var clips: [SongMarker] {
        guard let track else { return [] }
        return savedSongs.first { $0.matches(songID: track.id, catalogID: track.catalogID) }?.sortedClips ?? []
    }

    /// Past this many clips the list scrolls, rather than growing the panel
    /// down the screen.
    private static let visibleClips = 8
    private static let clipRowHeight: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let track {
                songRow(track)
                presets
                if !clips.isEmpty { clipList }
            } else {
                emptyState
            }
        }
        .padding(14)
        .frame(width: 300)
        .modifier(ArtworkGround(palette: track?.palette, isPlaying: controller.isPlaying))
    }

    // MARK: - Song

    private func songRow(_ track: PracticeView.Track) -> some View {
        HStack(spacing: 11) {
            CoverArt(artwork: track.artwork, songID: track.id, side: 42, radius: 7)
            VStack(alignment: .leading, spacing: 0) {
                Text(track.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(onAccent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.tint))
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .help("Play or pause")
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
        }
    }

    // MARK: - Speed

    private var presets: some View {
        let current = SpeedInput.preset(matching: controller.playbackRate)
        return HStack(spacing: 2) {
            ForEach(SpeedInput.presets, id: \.self) { percent in
                Button {
                    controller.playbackRate = Double(percent) / 100
                } label: {
                    Text("\(percent)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(percent == current ? AnyShapeStyle(onAccent) : AnyShapeStyle(.primary.opacity(0.85)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background { if percent == current { RoundedRectangle(cornerRadius: 9).fill(.tint) } }
                        .contentShape(.rect(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Speed \(percent)%")
                .accessibilityAddTraits(percent == current ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.black.opacity(0.2), in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08), lineWidth: 1) }
    }

    // MARK: - Clips

    @ViewBuilder
    private var clipList: some View {
        let rows = VStack(spacing: 1) {
            ForEach(clips) { clip in
                clipRow(clip)
            }
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Clips")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            if clips.count > Self.visibleClips {
                ScrollView { rows }
                    .scrollIndicators(.hidden)
                    .frame(height: CGFloat(Self.visibleClips) * (Self.clipRowHeight + 1))
            } else {
                rows
            }
        }
    }

    private func clipRow(_ clip: SongMarker) -> some View {
        let isLooping = controller.isLooping(clip)
        let isHovered = hoveredClip == clip.persistentModelID
        return Button {
            controller.choose(clip)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.foreground)
                    .frame(width: 10, height: 4)
                    .opacity(0.8)
                Text(clip.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(PlaybackScrubber.timeLabel(clip.startTime))
                    .monospacedDigit()
                    .opacity(0.6)
            }
            .font(.system(size: 12, weight: isLooping ? .semibold : .medium))
            .foregroundStyle(isLooping ? AnyShapeStyle(onAccent) : AnyShapeStyle(.primary))
            .padding(.horizontal, 8)
            .frame(height: Self.clipRowHeight)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isLooping ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(isHovered ? 0.1 : 0)))
            }
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hoveredClip = $0 ? clip.persistentModelID : nil }
        .help(controller.isLoopOn ? "Loop \(clip.name)" : "Jump to \(clip.name)")
        .accessibilityLabel(clip.name)
        .accessibilityValue(PlaybackScrubber.timeLabel(clip.startTime))
        .accessibilityAddTraits(isLooping ? .isSelected : [])
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No song loaded")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Button {
                miniSwitch.showMain(open: openWindow)
            } label: {
                Text("Open Music Momentum")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .modifier(ButtonGlass())
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - Previews

private let previewPalette = ArtworkPalette(cover: OKLCH(red: 0.18, green: 0.42, blue: 0.45))

@MainActor
private func panelPreview(loaded: Bool) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let song = SavedSong.save(
        songID: "1", title: "Harbour Lights", artistName: "Mara Ellis",
        artworkData: nil, speed: 0.75, in: context
    )
    SongMarker.add(to: song, name: "Intro riff", startTime: 0, endTime: 24, in: context)
    let chorus = SongMarker.add(to: song, name: "Chorus", startTime: 62, endTime: 96, in: context)
    SongMarker.add(to: song, name: "Solo", startTime: 142, endTime: 170, in: context)
    SongMarker.add(to: song, name: "Outro lick", startTime: 222, endTime: 250, in: context)
    let controller = PlaybackController()
    #if DEBUG
    controller.sampleDuration = 260
    #endif
    controller.playbackRate = 0.75
    controller.toggleLoop()
    controller.loop(only: chorus)
    return MenuBarPanel(
        controller: controller,
        track: loaded ? .init(id: "1", title: "Harbour Lights", artistName: "Mara Ellis", palette: previewPalette) : nil
    )
    .padding(30)
    .environment(MiniPlayerSwitch())
    .modelContainer(container)
}

#Preview("Song loaded", traits: .fixedLayout(width: 360, height: 380)) {
    panelPreview(loaded: true)
}

#Preview("Nothing loaded", traits: .fixedLayout(width: 360, height: 180)) {
    panelPreview(loaded: false)
}
#endif
