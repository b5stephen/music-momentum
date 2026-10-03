//
//  RootTabView.swift
//  MusicMomentum
//

import CoreData
import SwiftData
import SwiftUI

/// Owns the one `PlaybackController`: both screens need it, and `TabView`
/// keeps the practice tab alive so switching away doesn't tear down playback.
/// A wide landscape window drops the tabs and floats Practice over Saved.
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var controller = PlaybackController()
    @State private var tab: TabID = .practice
    @State private var practicePalette: ArtworkPalette?
    @State private var floats = false

    private enum TabID {
        case practice, saved
    }

    var body: some View {
        Group {
            if floats {
                FloatingLayout(palette: practicePalette) {
                    PracticeView(controller: controller, savedIsBeside: true) { practicePalette = $0 }
                } saved: {
                    SavedSongsView(controller: controller, isBesidePractice: true) {}
                }
            } else {
                tabs
            }
        }
        .onGeometryChange(for: Bool.self) { Self.floats($0.size) } action: { floats = $0 }
        .task { controller.configure(modelContext: modelContext) }
        // Duplicates and another device's library artwork only ever arrive by
        // sync, so tidying on each import is enough.
        .task {
            SavedSong.mergeDuplicates(in: modelContext)
            await ArtworkRepair.run(in: modelContext)
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                SavedSong.mergeDuplicates(in: modelContext)
                await ArtworkRepair.run(in: modelContext)
            }
        }
        // Hands are on the guitar, not the screen. iOS ignores this while
        // the app is in the background, so it needs no scene-phase check.
        .onChange(of: controller.isPlaying, initial: true) { _, playing in
            UIApplication.shared.isIdleTimerDisabled = playing
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Practice", systemImage: "guitars", value: .practice) {
                PracticeView(controller: controller) { practicePalette = $0 }
            }

            Tab("Saved", systemImage: "bookmark", value: .saved) {
                SavedSongsView(controller: controller) { tab = .practice }
            }
        }
        // Coral vanishes on a red or orange cover, so the selected tab takes
        // the practice screen's text colour while it's showing.
        .tint(tab == .practice ? practicePalette?.foreground : nil)
    }

    /// Landscape, with room for Saved beside a phone-width card. Narrower
    /// than this, the saved rows' marker pills start to wrap.
    private nonisolated static func floats(_ size: CGSize) -> Bool {
        size.width > size.height && size.width >= 1000
    }
}

/// Practice as a phone-width card hovering over Saved, which runs the full
/// width of the window behind it. The cover's colour glows on the page
/// around the card, so it reads as lit from within rather than as a column.
private struct FloatingLayout<Practice: View, Saved: View>: View {
    var palette: ArtworkPalette?
    @ViewBuilder var practice: Practice
    @ViewBuilder var saved: Saved
    @Environment(\.colorScheme) private var colorScheme
    /// Per device rather than synced: it's how this iPad is set up, not data.
    @AppStorage("floatingCardWidth") private var savedWidth = Double(Self.defaultWidth)
    @State private var dragStartWidth: CGFloat?
    @State private var liveWidth: CGFloat?
    @State private var windowWidth: CGFloat = 1376

    /// The widest iPhone's width, so the card is the phone layout at its roomiest.
    private static var defaultWidth: CGFloat { 440 }
    private static var minWidth: CGFloat { 375 }
    /// Wider than tall would flip the card into Practice's two-column layout,
    /// and a card this wide is no longer the phone layout anyway.
    private static var maxWidth: CGFloat { 640 }
    /// Room the saved rows need before their marker pills start to crowd.
    private static var minSavedWidth: CGFloat { 480 }
    private static var margin: CGFloat { 28 }
    private static var radius: CGFloat { 40 }

    private var cardWidth: CGFloat {
        clamped(liveWidth ?? savedWidth)
    }

    private func clamped(_ width: CGFloat) -> CGFloat {
        let roomiest = min(Self.maxWidth, windowWidth - 2 * Self.margin - Self.minSavedWidth)
        return min(max(width, Self.minWidth), max(Self.minWidth, roomiest))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            glow

            saved
                .scrollContentBackground(.hidden)
                .padding(.leading, cardWidth + 2 * Self.margin)

            practice
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: Self.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: Self.radius)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.14 : 0.3), lineWidth: 0.5)
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.6 : 0.2),
                    radius: colorScheme == .dark ? 40 : 30,
                    y: colorScheme == .dark ? 24 : 16
                )
                .frame(width: cardWidth)
                .padding(Self.margin)
                // The status bar and home indicator are shorter than the
                // margin, so the card can measure from the screen's edges.
                .ignoresSafeArea(edges: .vertical)

            resizeHandle
                .offset(x: Self.margin + cardWidth)
        }
        .background(Color(.systemBackground))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
    }

    private var glow: some View {
        let width = cardWidth + 320
        return Ellipse()
            .fill(palette?.mesh[4] ?? .clear)
            .frame(width: width)
            .padding(.vertical, 40)
            .offset(x: Self.margin + cardWidth / 2 - width / 2)
            .blur(radius: 90)
            .opacity(colorScheme == .dark ? 0.5 : 0.3)
            .animation(.easeInOut(duration: 0.4), value: palette)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    /// Sits in the gap beside the card, as Split View's divider does. A double
    /// tap puts the card back to the phone width.
    private var resizeHandle: some View {
        Capsule()
            .fill(.tertiary)
            .frame(width: 5, height: 44)
            .frame(width: Self.margin, height: 120)
            .contentShape(.rect)
            .hoverEffect(.highlight)
            .gesture(
                // Global, because the handle moves with the width it sets: measured
                // locally, each step shifts the frame the next translation is read in.
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? cardWidth
                        dragStartWidth = start
                        liveWidth = clamped(start + value.translation.width)
                    }
                    .onEnded { _ in
                        if let liveWidth { savedWidth = Double(liveWidth) }
                        liveWidth = nil
                        dragStartWidth = nil
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { savedWidth = Double(Self.defaultWidth) }
            }
            .accessibilityElement()
            .accessibilityLabel("Practice width")
            .accessibilityValue("\(Int(cardWidth)) points")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 40 : -40
                withAnimation(.snappy) { savedWidth = Double(clamped(cardWidth + step)) }
            }
    }
}

#Preview {
    RootTabView()
        .modelContainer(try! AppSchema.inMemoryContainer())
}

#Preview("Floating", traits: .fixedLayout(width: 1376, height: 1032)) {
    floatingPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.88, green: 0.64, blue: 0.05)))
}

#Preview("Floating, nothing loaded", traits: .fixedLayout(width: 1376, height: 1032)) {
    floatingPreview(palette: nil)
}

@MainActor
private func floatingPreview(palette: ArtworkPalette?) -> some View {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong.save(
        songID: "1", title: "Count on Me", artistName: "Bruno Mars",
        artworkData: nil, speed: 0.75, in: container.mainContext
    )
    SongMarker.add(to: song, name: "Intro", startTime: 0, endTime: nil, in: container.mainContext)
    SongMarker.add(to: song, name: "Chorus", startTime: 82, endTime: 113, in: container.mainContext)
    SavedSong.save(
        songID: "2", title: "Little Wing", artistName: "Jimi Hendrix",
        artworkData: nil, speed: 0.6, in: container.mainContext
    )
    let controller = PlaybackController()
    controller.playbackRate = 0.75
    return FloatingLayout(palette: palette) {
        PracticeView(
            controller: controller,
            previewTrack: palette.map { .init(id: "1", title: "Count on Me", artistName: "Bruno Mars", palette: $0) },
            savedIsBeside: true
        )
    } saved: {
        SavedSongsView(controller: controller, isBesidePractice: true) {}
    }
    .modelContainer(container)
}
