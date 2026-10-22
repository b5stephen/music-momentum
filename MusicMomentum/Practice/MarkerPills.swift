//
//  MarkerPills.swift
//  MusicMomentum
//

import SwiftData
import SwiftUI

/// A song's markers as a row of pills, each standing for the section it
/// starts; the fill means only state. Expects the markers in time order,
/// which is what numbers the unnamed ones.
///
/// Everything past the tap is optional, since the saved list has no loop.
struct MarkerPills: View {
    let markers: [SongMarker]
    /// Content margins; the row still scrolls edge to edge.
    var inset: CGFloat = 32
    var leadingInset: CGFloat?
    var trailingInset: CGFloat?
    /// On a plain page a grey fill under every song outweighs the titles, so
    /// Saved draws idle pills as a hairline instead of glass.
    var outlinesIdle = false
    var isLooping: (SongMarker) -> Bool = { _ in false }
    /// With the loop on, a pill tap changes what's looping, so the pills that
    /// could take it over say so.
    var isLoopOn = false
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
    /// Which edges have pills scrolled past them, so the fade only hints at
    /// more when there is more.
    @State private var clipped: (leading: Bool, trailing: Bool) = (false, false)
    @Environment(\.onAccent) private var onAccent
    @Environment(\.inGlassPanel) private var inGlassPanel
    @Environment(\.displayScale) private var displayScale

    private enum PillState {
        case idle, joinable, looping
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
        .contentMargins(.trailing, trailingInset ?? inset, for: .scrollContent)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.x > -geometry.contentInsets.leading + 1
        } action: { _, isClipped in
            clipped.leading = isClipped
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.x + geometry.containerSize.width
                < geometry.contentSize.width + geometry.contentInsets.trailing - 1
        } action: { _, isClipped in
            clipped.trailing = isClipped
        }
        // Past the margin, or the cut-off pill reads as cropped rather than as
        // carrying on; 56 started fading pills well clear of the edge.
        .edgeFade(leading: clipped.leading, trailing: clipped.trailing, width: 40)
        .animation(.easeOut(duration: 0.2), value: clipped.leading)
        .animation(.easeOut(duration: 0.2), value: clipped.trailing)
    }

    /// The VoiceOver actions hang off here so both branches of `pillControl`
    /// share them.
    private func pill(_ marker: SongMarker) -> some View {
        pillControl(marker)
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(marker, state: state(of: marker)))
            .accessibilityValue(marker.timeLabel)
            .ifLet(onPlayLoop) { view, playLoop in
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
        onPlayLoop != nil
            || onJump != nil
            || onEdit != nil
            || onDelete != nil
    }

    private func pillLabel(_ marker: SongMarker) -> some View {
        let state = state(of: marker)

        return HStack(spacing: 5) {
            Circle()
                .frame(width: dotSize, height: dotSize)
                .opacity(state == .idle ? 0.55 : 0.8)
            Text(displayName(marker))
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background { background(state) }
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
        if let onPlayLoop {
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

    private func displayName(_ marker: SongMarker) -> String {
        let index = markers.firstIndex { $0 === marker } ?? 0
        return SongSection<PersistentIdentifier>.markerName(marker.name, index: index)
    }

    private func state(of marker: SongMarker) -> PillState {
        if isLooping(marker) { return .looping }
        return isLoopOn ? .joinable : .idle
    }

    /// Glass, as Practice's other buttons are: grey beside them read as a
    /// different, disabled kind of control. In a glass panel, a flat fill and
    /// a hairline instead. Looping is solid in every case.
    @ViewBuilder
    private func background(_ state: PillState) -> some View {
        if state == .looping {
            Capsule().fill(.tint)
        } else if outlinesIdle {
            Color.clear
        } else if inGlassPanel {
            Capsule()
                .fill(.primary.opacity(0.1))
                .overlay { Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 1) }
        } else {
            Color.clear
                .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    /// White on the coral tint is under 3:1, too faint for footnote text, so
    /// looping uses the dark on-accent colour.
    private func foreground(_ state: PillState) -> AnyShapeStyle {
        switch state {
        case .idle, .joinable: AnyShapeStyle(.primary)
        case .looping: AnyShapeStyle(onAccent)
        }
    }

    private func accessibilityLabel(_ marker: SongMarker, state: PillState) -> String {
        let name = displayName(marker)
        switch state {
        case .idle: return "\(name), marker"
        case .joinable: return "\(name), marker, not looping"
        case .looping: return "\(name), marker, looping"
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
    SongMarker.add(to: song, name: "Intro", at: 4, in: container.mainContext)
    SongMarker.add(to: song, name: "Verse riff", at: 18, in: container.mainContext)
    SongMarker.add(to: song, at: 31, in: container.mainContext)
    SongMarker.add(to: song, name: "Solo", at: 96, in: container.mainContext)
    SongMarker.add(to: song, name: "Outro", at: 180, in: container.mainContext)

    return VStack(spacing: 10) {
        PlaybackScrubber(
            position: 71,
            duration: 245,
            markers: song.sortedMarkers.map {
                .init(
                    id: $0.persistentModelID,
                    name: $0.name,
                    start: $0.startTime,
                    end: nil
                )
            }
        ) { _ in }
        .padding(.horizontal, 32)

        MarkerPills(
            markers: song.sortedMarkers,
            isLooping: { $0.name == "Solo" },
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
