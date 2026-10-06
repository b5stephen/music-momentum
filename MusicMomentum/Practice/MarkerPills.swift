//
//  MarkerPills.swift
//  MusicMomentum
//

import SwiftData
import SwiftUI

/// A song's markers as a row of pills. Kind is carried by the glyph alone
/// (dot for a point, span for a clip); the fill means only state.
///
/// Everything past the tap is optional, since the saved list has no loop.
struct MarkerPills: View {
    let markers: [SongMarker]
    /// Content margins; the row still scrolls edge to edge.
    var inset: CGFloat = 32
    var leadingInset: CGFloat?
    /// On a plain page a grey fill under every song outweighs the titles, so
    /// Saved draws idle pills as a hairline instead.
    var outlinesIdle = false
    var isLooping: (SongMarker) -> Bool = { _ in false }
    /// With the loop on, a clip tap changes what's looping, so the clips that
    /// could join it say so.
    var isLoopOn = false
    /// Playhead inside this clip while the loop is off.
    var isCued: (SongMarker) -> Bool = { _ in false }
    var onTap: (SongMarker) -> Void
    var onPlayLoop: ((SongMarker) -> Void)?
    /// The saved list's jump loads the song and changes tab, so it says so.
    var jumpTitle: String = "Jump to Start"
    var onJump: ((SongMarker) -> Void)?
    var onEdit: ((SongMarker) -> Void)?
    var onDelete: ((SongMarker) -> Void)?

    @ScaledMetric(relativeTo: .footnote) private var dotSize: CGFloat = 6
    /// A pill's height.
    @ScaledMetric(relativeTo: .footnote) private var pillHeight: CGFloat = 32
    @Environment(\.onAccent) private var onAccent
    @Environment(\.displayScale) private var displayScale

    private enum PillState {
        case idle, cued, joinable, looping
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(markers) { marker in
                    pill(marker)
                }
            }
            // Holds a pill's height with no pills, so the practice screen
            // doesn't jump between songs with and without markers.
            .frame(minHeight: pillHeight)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.leading, leadingInset ?? inset, for: .scrollContent)
        .contentMargins(.trailing, inset, for: .scrollContent)
    }

    /// The VoiceOver actions hang off here so both branches of `pillControl`
    /// share them.
    private func pill(_ marker: SongMarker) -> some View {
        pillControl(marker)
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(marker, state: state(of: marker)))
            .accessibilityValue(marker.timeLabel)
            .ifLet(marker.isClip ? onPlayLoop : nil) { view, playLoop in
                view.accessibilityAction(named: "Play on loop") { playLoop(marker) }
            }
            .ifLet(onJump) { view, jump in
                view.accessibilityAction(named: jumpTitle) { jump(marker) }
            }
            .ifLet(onEdit) { view, edit in
                view.accessibilityAction(named: "Edit") { edit(marker) }
            }
            .ifLet(onDelete) { view, remove in
                view.accessibilityAction(named: "Delete") { remove(marker) }
            }
    }

    /// A `Menu` with a primary action rather than `.contextMenu`: a context
    /// menu declared inside a `List` row is hoisted to the whole cell, so on
    /// the saved list every pill shared one menu that ran the *first* marker's
    /// actions whichever pill you pressed.
    @ViewBuilder
    private func pillControl(_ marker: SongMarker) -> some View {
        if hasMenu(for: marker) {
            Menu {
                menuItems(marker)
            } label: {
                pillLabel(marker)
            } primaryAction: {
                onTap(marker)
            }
        } else {
            Button { onTap(marker) } label: { pillLabel(marker) }
        }
    }

    private func hasMenu(for marker: SongMarker) -> Bool {
        (marker.isClip && onPlayLoop != nil)
            || onJump != nil
            || onEdit != nil
            || onDelete != nil
    }

    private func pillLabel(_ marker: SongMarker) -> some View {
        let state = state(of: marker)

        return HStack(spacing: 5) {
            glyph(marker)
                .foregroundStyle(state == .cued ? AnyShapeStyle(.tint) : foreground(state))
                .opacity(state == .idle ? 0.55 : 0.8)
            Text(marker.name)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            if let length = clipLength(marker) {
                Text(length)
                    .font(.footnote.monospacedDigit())
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(fill(state), in: Capsule())
        .overlay {
            if outlinesIdle, state == .idle {
                Capsule().strokeBorder(.quaternary, lineWidth: 1 / displayScale)
            } else if state == .joinable {
                // Dashed rather than coloured: on a cover the tint is the same
                // near-white as the looping fill, so only the shape tells them apart.
                Capsule().strokeBorder(.tint.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
        }
        .foregroundStyle(foreground(state))
    }

    @ViewBuilder
    private func menuItems(_ marker: SongMarker) -> some View {
        if let onPlayLoop, marker.isClip {
            Button { onPlayLoop(marker) } label: { Label("Play on Loop", systemImage: "repeat") }
        }
        if let onJump {
            Button { onJump(marker) } label: { Label(jumpTitle, systemImage: "arrow.turn.down.right") }
        }
        if let onEdit {
            Button { onEdit(marker) } label: { Label("Edit", systemImage: "pencil") }
        }
        if let onDelete {
            Button(role: .destructive) { onDelete(marker) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private func glyph(_ marker: SongMarker) -> some View {
        if marker.isClip {
            SpanGlyph()
        } else {
            Circle().frame(width: dotSize, height: dotSize)
        }
    }

    private func clipLength(_ marker: SongMarker) -> String? {
        guard let end = marker.endTime else { return nil }
        return PlaybackScrubber.lengthLabel(max(0, end - marker.startTime))
    }

    private func state(of marker: SongMarker) -> PillState {
        if isLooping(marker) { return .looping }
        if isLoopOn, marker.isClip { return .joinable }
        return isCued(marker) ? .cued : .idle
    }

    private func fill(_ state: PillState) -> AnyShapeStyle {
        switch state {
        case .idle, .joinable: outlinesIdle ? AnyShapeStyle(.clear) : AnyShapeStyle(.quaternary)
        case .cued: AnyShapeStyle(.tint.opacity(0.12))
        case .looping: AnyShapeStyle(.tint)
        }
    }

    /// Cued keeps the primary text so only the fill and glyph hint at it;
    /// looping is the one state that shouts. White on the coral tint is under
    /// 3:1, too faint for footnote text, so looping uses the dark on-accent colour.
    private func foreground(_ state: PillState) -> AnyShapeStyle {
        switch state {
        case .idle, .cued, .joinable: AnyShapeStyle(.primary)
        case .looping: AnyShapeStyle(onAccent)
        }
    }

    private func accessibilityLabel(_ marker: SongMarker, state: PillState) -> String {
        let kind = marker.isClip ? "clip" : "marker"
        switch state {
        case .idle: return "\(marker.name), \(kind)"
        case .joinable: return "\(marker.name), \(kind), not looping"
        case .cued: return "\(marker.name), \(kind), at the playhead"
        case .looping: return "\(marker.name), \(kind), looping"
        }
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T>(_ value: T?, @ViewBuilder transform: (Self, T) -> some View) -> some View {
        if let value { transform(self, value) } else { self }
    }
}

#Preview {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong(songID: "1", speed: 0.8, title: "Little Wing", artistName: "Jimi Hendrix")
    container.mainContext.insert(song)
    SongMarker.add(to: song, name: "Intro", startTime: 4, endTime: nil, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse riff", startTime: 18, endTime: 31, in: container.mainContext)
    SongMarker.add(to: song, name: "Solo", startTime: 96, endTime: 128, in: container.mainContext)
    SongMarker.add(to: song, name: "Outro", startTime: 180, endTime: nil, in: container.mainContext)

    return VStack(spacing: 10) {
        PlaybackScrubber(
            position: 71,
            duration: 245,
            markers: song.sortedMarkers.map {
                .init(
                    id: $0.persistentModelID,
                    start: $0.startTime,
                    end: $0.endTime,
                    isLooping: $0.name == "Solo"
                )
            }
        ) { _ in }
        .padding(.horizontal, 32)

        MarkerPills(
            markers: song.sortedMarkers,
            isLooping: { $0.name == "Solo" },
            isCued: { $0.name == "Verse riff" },
            onTap: { _ in }, onPlayLoop: { _ in }, onJump: { _ in },
            onEdit: { _ in }, onDelete: { _ in }
        )

        MarkerPills(
            markers: song.sortedMarkers,
            isLooping: { $0.name == "Solo" },
            isLoopOn: true,
            onTap: { _ in }
        )

        MarkerPills(markers: [], onTap: { _ in })
    }
    .modelContainer(container)
}
