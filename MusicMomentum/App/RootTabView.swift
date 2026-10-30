//
//  RootTabView.swift
//  MusicMomentum
//

import CoreData
import SwiftData
import SwiftUI

/// Owns the one `PlaybackController`: both screens need it, and `TabView`
/// keeps the practice tab alive so switching away doesn't tear down playback.
/// A wide landscape window drops the tabs and floats Practice over Saved; a
/// Mac window has Saved as a sidebar instead.
struct RootTabView: View {
    /// Stands in for a loaded song; see `SampleSong`.
    var sampleTrack: PracticeView.Track?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var controller = PlaybackController()
    #if os(iOS)
    @State private var tab: TabID = .practice
    #endif
    @State private var practicePalette: ArtworkPalette?
    #if os(iOS)
    @State private var floats = false
    #endif
    #if os(macOS)
    @State private var displayAwake: (any NSObjectProtocol)?
    #endif

    #if os(iOS)
    private enum TabID {
        case practice, saved
    }
    #endif

    var body: some View {
        content
        .task { controller.configure(modelContext: modelContext) }
        #if DEBUG
        .onChange(of: sampleTrack?.id, initial: true) { _, id in
            guard SampleSong.isRequested, let id, let duration = SampleSong.duration(of: id) else { return }
            controller.sampleDuration = duration
            controller.playbackRate = SampleSong.speed(of: id) ?? 1.0
        }
        #endif
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
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = playing
            #elseif os(macOS)
            if playing, displayAwake == nil {
                displayAwake = ProcessInfo.processInfo.beginActivity(options: .idleDisplaySleepDisabled, reason: "Practising")
            } else if !playing, let displayAwake {
                ProcessInfo.processInfo.endActivity(displayAwake)
                self.displayAwake = nil
            }
            #endif
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        MacWindow(controller: controller, sampleTrack: sampleTrack, palette: $practicePalette)
        #else
        Group {
            if floats {
                FloatingLayout(palette: practicePalette) {
                    PracticeView(controller: controller, previewTrack: sampleTrack, savedIsBeside: true) { practicePalette = $0 }
                } saved: {
                    SavedSongsView(controller: controller, isBesidePractice: true, previewCurrentID: sampleTrack?.id) {}
                }
            } else {
                tabs
            }
        }
        .onGeometryChange(for: Bool.self) { Self.floats($0.size, insets: $0.safeAreaInsets) } action: { floats = $0 }
        #endif
    }

    #if os(iOS)
    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Practice", systemImage: "guitars", value: .practice) {
                PracticeView(controller: controller, previewTrack: sampleTrack) { practicePalette = $0 }
                    .environment(\.colorScheme, colorScheme)
            }

            Tab("Saved", systemImage: "bookmark", value: .saved) {
                SavedSongsView(controller: controller, previewCurrentID: sampleTrack?.id) { tab = .practice }
                    .environment(\.colorScheme, colorScheme)
            }
        }
        // Coral vanishes on a red or orange cover, so the selected tab takes
        // the practice screen's text colour while it's showing. That colour is
        // always light, and the glass turns light over a bright cover, so the
        // bar is held dark; each tab gets the real scheme back.
        .tint(tab == .practice ? practicePalette?.foreground : nil)
        .environment(\.colorScheme, tab == .practice && practicePalette != nil ? .dark : colorScheme)
    }

    /// Landscape, with room for Saved beside the narrowest card and for the
    /// card's own height. Measured across the insets: an unfolded iPhone Duo's
    /// camera reserves 84pt down its trailing edge, but only at the top, and
    /// Saved's rows clear it. Width alone floated a landscape iPhone Air
    /// (912×420) and Pro Max, in a card too short for Practice.
    private nonisolated static func floats(_ size: CGSize, insets: EdgeInsets) -> Bool {
        let width = size.width + insets.leading + insets.trailing
        let height = size.height + insets.top + insets.bottom
        return width > height
            && width >= FloatingLayout<EmptyView, EmptyView>.minWindowWidth
            && height >= FloatingLayout<EmptyView, EmptyView>.minWindowHeight
    }
    #endif
}

#if os(iOS)

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
    /// iPadOS's window controls, which sit over the card's top-leading corner.
    @State private var windowControlsHeight: CGFloat = 0
    /// A bent foldable's crease down the window, margins included. The card
    /// ends at it and Saved starts past it, so neither folds.
    @State private var crease: ClosedRange<CGFloat>?

    /// The widest iPhone's width, so the card is the phone layout at its roomiest.
    private static var defaultWidth: CGFloat { 440 }
    private nonisolated static var minWidth: CGFloat { 375 }
    /// Wider than tall would flip the card into Practice's two-column layout,
    /// and a card this wide is no longer the phone layout anyway.
    private static var maxWidth: CGFloat { 640 }
    /// Room the saved rows need before their marker pills start to crowd.
    private nonisolated static var minSavedWidth: CGFloat { 480 }
    private nonisolated static var margin: CGFloat { 28 }
    nonisolated static var minWindowWidth: CGFloat { minWidth + 2 * margin + minSavedWidth }
    /// An iPhone SE's practice screen inside the card's insets: 652pt, over
    /// any phone on its side (a Pro Max is 440) and under an open iPhone
    /// Duo's 669.
    nonisolated static var minWindowHeight: CGFloat { 580 + 2 * contentInset + 2 * margin }
    private static var radius: CGFloat { 40 }
    private nonisolated static var contentInset: CGFloat { 8 }

    private var cardWidth: CGFloat {
        if let crease { return max(Self.minWidth, crease.lowerBound - Self.margin) }
        return clamped(liveWidth ?? savedWidth)
    }

    private func clamped(_ width: CGFloat) -> CGFloat {
        let roomiest = min(Self.maxWidth, windowWidth - 2 * Self.margin - Self.minSavedWidth)
        return min(max(width, Self.minWidth), max(Self.minWidth, roomiest))
    }

    var body: some View {
        // Out here so the geometry closure captures a value, not the generic `Self`.
        let narrowestCardEdge = Self.margin + Self.minWidth
        ZStack(alignment: .leading) {
            glow

            saved
                .scrollContentBackground(.hidden)
                .padding(.leading, crease?.upperBound ?? cardWidth + 2 * Self.margin)

            practice
                // Stands in for a phone's status bar and tab bar, so the
                // header sits as far from the card's top as from its side.
                .safeAreaPadding(.vertical, Self.contentInset)
                .background(Color.secondarySystemGroupedBackground)
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
                .padding(.top, max(0, windowControlsHeight + Self.contentInset - Self.margin))
                // The status bar and home indicator are shorter than the
                // margin, so the card can measure from the screen's edges.
                .ignoresSafeArea(edges: .vertical)
                .onGeometryChange(for: CGFloat.self) { $0.windowControls.height } action: { windowControlsHeight = $0 }

            // Bent, the crease sets the width.
            if crease == nil {
                resizeHandle
                    .offset(x: Self.margin + cardWidth)
            }
        }
        .background(Color.systemBackground)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .onGeometryChange(for: ClosedRange<CGFloat>?.self) { proxy in
            guard #available(iOS 27.1, *),
                  let region = proxy.reservedRegions(kind: .division).first(where: {
                      $0.isActive && $0.frame.height > $0.frame.width
                  }),
                  region.frame.minX >= narrowestCardEdge
            else { return nil }
            return region.frame.minX...region.frame.maxX
        } action: { crease in
            withAnimation(.snappy) { self.crease = crease }
        }
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
#endif

#Preview {
    RootTabView()
        .modelContainer(try! AppSchema.inMemoryContainer())
}

#if os(iOS)
#Preview("Floating, 11-inch", traits: .fixedLayout(width: 1180, height: 820)) {
    floatingPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.88, green: 0.64, blue: 0.05)))
}

#Preview("Floating, 13-inch", traits: .fixedLayout(width: 1376, height: 1032)) {
    floatingPreview(palette: ArtworkPalette(cover: OKLCH(red: 0.88, green: 0.64, blue: 0.05)))
}

#Preview("Floating, nothing loaded", traits: .fixedLayout(width: 1376, height: 1032)) {
    floatingPreview(palette: nil)
}

#Preview("Open iPhone Duo, landscape", traits: .fixedLayout(width: 951, height: 669)) {
    RootTabView(sampleTrack: previewTrack)
        .modelContainer(previewContainer())
}

#Preview("iPhone Air, landscape", traits: .fixedLayout(width: 912, height: 420)) {
    RootTabView(sampleTrack: previewTrack)
        .modelContainer(previewContainer())
}

private let previewTrack = PracticeView.Track(
    id: "1", title: "Count on Me", artistName: "Bruno Mars",
    palette: ArtworkPalette(cover: OKLCH(red: 0.88, green: 0.64, blue: 0.05))
)

@MainActor
private func previewContainer() -> ModelContainer {
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
    return container
}

@MainActor
private func floatingPreview(palette: ArtworkPalette?) -> some View {
    let controller = PlaybackController()
    controller.playbackRate = 0.75
    return FloatingLayout(palette: palette) {
        PracticeView(
            controller: controller,
            previewTrack: palette.map { .init(id: "1", title: "Count on Me", artistName: "Bruno Mars", palette: $0) },
            savedIsBeside: true
        )
    } saved: {
        SavedSongsView(
            controller: controller, isBesidePractice: true,
            previewCurrentID: palette.map { _ in "1" }
        ) {}
    }
    .modelContainer(previewContainer())
}
#endif
