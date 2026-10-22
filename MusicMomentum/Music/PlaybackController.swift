//
//  PlaybackController.swift
//  MusicMomentum
//

import Foundation
import MusicKit
import Observation
import SwiftData

/// Wraps `ApplicationMusicPlayer`; the only thing in the app that talks to it.
@MainActor
@Observable
final class PlaybackController {
    static let speedRange: ClosedRange<Double> = 0.3...1.0

    private let player = ApplicationMusicPlayer.shared
    private let playerBox = MusicPlayerBox(player: ApplicationMusicPlayer.shared)
    private var modelContext: ModelContext?

    /// Stops `playbackRate`'s `didSet` poking the player mid-load.
    private var isLoadingSavedSpeed = false

    var selectedSong: Song?
    /// True while last launch's song is being looked up, so the practice
    /// screen can hold off showing "nothing loaded" for a song that's coming.
    private(set) var isRestoringLastSong = false
    /// Mirrored: read straight off `player.state` (`Observable` since iOS
    /// 26.4), the marker sheet's button was left showing Pause after the song
    /// stopped. The status stream and the ticker both refresh it, so it still
    /// follows playback started or stopped from outside the app.
    private(set) var isPlaying = false
    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus

    /// MusicKit publishes no change signal for the playhead, so it's polled.
    private var tickObservation: Task<Void, Never>?

    private(set) var playbackTime: TimeInterval = 0
    var duration: TimeInterval? {
        #if DEBUG
        if selectedSong == nil, let sampleDuration { return sampleDuration }
        #endif
        return selectedSong?.duration
    }
    #if DEBUG
    /// The loaded `SampleSong`'s length, so it can be marked up.
    var sampleDuration: TimeInterval?

    /// Places the playhead for a preview, which has no player to seek.
    var previewPlaybackTime: TimeInterval {
        get { playbackTime }
        set { playbackTime = newValue }
    }
    #endif
    /// Suspends the ticker so the thumb doesn't fight the playhead.
    var isScrubbing = false
    /// A queue that has been prepared but never played drops any
    /// `playbackTime` written to it and starts at the top.
    private var hasPlayed = false
    /// A seek asked for before `hasPlayed`, re-applied once it will stick.
    private var pendingStart: TimeInterval?
    /// For a moment after a seek the player still reports the *old* position,
    /// which would yank the bar back to where the user just dragged from.
    private var lastSeek: ContinuousClock.Instant?

    /// `nil` when nothing's looping. Here rather than in the screen so a
    /// relayout (rotating, folding, resizing a window) keeps it.
    private(set) var loop: Loop?
    /// Which timeline the player shows. Here for the same reason as `loop`;
    /// a saved song's last mode is loaded with its speed.
    var mode: PlayerMode = .play
    /// Whether the playhead was last inside the loop's range. Cleared by a
    /// jump or scrub: the ticker waits until it plays back into the range.
    private var wasInsideLoop = false

    var playbackRate: Double = 1.0 {
        didSet {
            guard !isLoadingSavedSpeed else { return }
            // Assigning `playbackRate` on a paused player starts it.
            if isPlaying {
                applyRateIfPossible()
            }
        }
    }

    var errorMessage: String?
    /// Set when the player silently refuses the requested rate.
    var rateWarning: String?

    // MARK: - Setup

    /// Kept out of `init` so the class stays easy to preview.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshIsPlaying()
        readPlaybackTime()
        startTicking()
        startObservingStatus()
        Task { await restoreLastSong() }
    }

    /// Resuming from the lock screen or Control Centre bypasses `play()`, and
    /// the player always resumes at full speed, so the rate is re-applied on
    /// every start. The background audio mode is what keeps this running while
    /// the phone is locked.
    private var statusObservation: Task<Void, Never>?

    private func startObservingStatus() {
        guard statusObservation == nil else { return }
        statusObservation = Task { [weak self] in
            let statuses = Observations { @MainActor in ApplicationMusicPlayer.shared.state.playbackStatus }
            for await status in statuses {
                guard let self else { return }
                self.refreshIsPlaying()
                guard status == .playing, self.selectedSong != nil,
                      abs(Double(self.player.state.playbackRate) - self.playbackRate) > 0.01
                else { continue }
                self.applyRateIfPossible()
                try? await Task.sleep(for: .milliseconds(300))
                self.verifyRateStuck()
            }
        }
    }

    /// Never prompts for access: an app that hasn't been authorised comes up
    /// empty and waits for the user to reach for the library. Failing is
    /// quiet: the user didn't ask for this song, so an empty screen is the
    /// whole answer. A song that's gone is forgotten; a lookup that merely
    /// failed keeps it for next time.
    private func restoreLastSong() async {
        guard selectedSong == nil, authorizationStatus == .authorized,
              let last = LastLoadedSong.stored
        else { return }
        isRestoringLastSong = true
        defer { isRestoringLastSong = false }
        do {
            guard let song = try await SongLookup.song(libraryID: last.songID, catalogID: last.catalogID) else {
                LastLoadedSong.forget()
                return
            }
            await select(song: song)
            if errorMessage != nil {
                selectedSong = nil
                errorMessage = nil
            }
        } catch {}
    }

    /// For coming back from the background, where the ticker couldn't keep up.
    func refreshPlaybackTime() {
        readPlaybackTime()
    }

    private func startTicking() {
        guard tickObservation == nil else { return }
        tickObservation = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                self.refreshIsPlaying()
                guard self.isPlaying, !self.isScrubbing else { continue }
                self.readPlaybackTime()
            }
        }
    }

    private func refreshIsPlaying() {
        let playing = player.state.playbackStatus == .playing
        if playing != isPlaying { isPlaying = playing }
    }

    private func readPlaybackTime() {
        guard pendingStart == nil else { return }
        if let lastSeek {
            guard lastSeek.duration(to: .now) > .milliseconds(500) else { return }
            self.lastSeek = nil
        }
        let time = player.playbackTime
        // The player can report a hair past the end as a track wraps.
        playbackTime = max(0, min(time, duration ?? time))

        wrapLoopIfNeeded()
    }

    /// Whole-song looping isn't here: that's the player's own repeat mode,
    /// which wraps seamlessly instead of up to a poll late.
    private func wrapLoopIfNeeded() {
        guard case .range(let start, let end) = loop else { return }

        switch Loop.step(start: start, end: end, time: playbackTime, wasInside: wasInsideLoop) {
        case .inside:
            wasInsideLoop = true
        case .jump(to: let time):
            // Set before the seek: a short range can be swallowed whole by the
            // settling window, and the next reading past its end must still wrap.
            wasInsideLoop = true
            seek(to: time)
        case .wait:
            break
        }
    }

    // MARK: - Seeking

    /// Unlike `playbackRate`, assigning `playbackTime` doesn't start playback.
    func seek(to time: TimeInterval) {
        let target = max(0, min(time, duration ?? time))
        playbackTime = target
        player.playbackTime = target
        lastSeek = .now
        guard !hasPlayed else { return }
        pendingStart = target
        if isPlaying {
            Task { await applyPendingStart() }
        }
    }

    /// Forgets the playhead was in the loop, so landing past its end isn't
    /// read as "the loop just finished" and bounced back.
    private func userSeek(to time: TimeInterval) {
        wasInsideLoop = false
        seek(to: time)
    }

    func skip(by offset: TimeInterval) {
        userSeek(to: playbackTime + offset)
    }

    func endScrub(at time: TimeInterval) {
        userSeek(to: time)
        isScrubbing = false
    }

    /// Called when the user reaches for the library, never on launch, so the
    /// system prompt turns up with a reason attached.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        if authorizationStatus != .authorized {
            authorizationStatus = await MusicAuthorization.request()
        }
        return authorizationStatus == .authorized
    }

    /// Undetermined still counts: tapping the button is what brings the prompt up.
    var canUseMusic: Bool {
        #if DEBUG
        // The samples are for screenshots, where a greyed-out Add and Change
        // Song look broken; the simulator has no Apple Music to allow.
        if sampleDuration != nil { return true }
        #endif
        return authorizationStatus != .denied && authorizationStatus != .restricted
    }

    // MARK: - Playback

    /// Queues the song at its saved speed without starting it — the user hits
    /// play once the guitar is in their hands.
    func select(song: Song) async {
        selectedSong = song
        LastLoadedSong.remember(song)
        loadSavedSettings(songID: song.id.rawValue)
        errorMessage = nil
        rateWarning = nil
        playbackTime = 0
        // The loop button survives a change of song, like repeat in any
        // player; its range can't, since it belonged to the last track.
        setLoop(loop == nil ? nil : .wholeSong)
        hasPlayed = false
        pendingStart = nil
        do {
            player.queue = [song]
            // Drilling eight bars two hundred times shouldn't shape
            // recommendations (iOS 26.4+).
            player.queue.affectsListeningHistory = false
            try await playerBox.prepareToPlay()
            // A fresh queue doesn't carry the old one's repeat mode over.
            applyRepeatMode()
        } catch {
            errorMessage = "Couldn't load that track: \(error.localizedDescription)"
        }
    }

    /// Throws rather than setting `errorMessage`: a failed lookup leaves the
    /// player untouched, so the message belongs to the screen that asked,
    /// not to a song banner that would outlive it.
    func select(saved: SavedSong) async throws {
        guard let song = try await SongLookup.song(
            libraryID: saved.songID,
            catalogID: saved.catalogID
        ) else { throw SongGoneError() }
        await select(song: song)
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            refreshIsPlaying()
        } else {
            play()
        }
    }

    private func play() {
        Task {
            do {
                try await playerBox.play()
                refreshIsPlaying()
                errorMessage = nil
                hasPlayed = true
                markPracticed()
                await applyPendingStart()
                try? await Task.sleep(for: .milliseconds(300))
                applyRateIfPossible()
                verifyRateStuck()
            } catch {
                errorMessage = "Couldn't resume: \(error.localizedDescription)"
            }
        }
    }

    /// `play()` returning isn't the same as the queue entry being ready: for a
    /// moment after it the player still drops a `playbackTime` written to it.
    /// So the write is repeated until the player reads back near the target,
    /// and given up on after a second rather than fighting the user's transport.
    private func applyPendingStart() async {
        guard let target = pendingStart else { return }
        for _ in 0..<10 {
            player.playbackTime = target
            try? await Task.sleep(for: .milliseconds(100))
            if player.playbackTime >= target - 0.5 { break }
        }
        pendingStart = nil
        playbackTime = target
        lastSeek = .now
    }

    // MARK: - Markers

    /// Pauses so the song doesn't run on while the user names the marker, and
    /// returns the playhead for the editor to open at.
    func pauseForMarking() -> TimeInterval {
        if isPlaying {
            player.pause()
            refreshIsPlaying()
        }
        return playbackTime
    }

    func playFrom(_ time: TimeInterval) {
        userSeek(to: time)
        play()
    }

    /// Doesn't start or stop playback, and leaves the loop alone: jumping out
    /// of a running loop is a look around, and the loop picks the playhead
    /// up again when it plays back into the range.
    func jump(to marker: SongMarker) {
        userSeek(to: marker.startTime)
    }

    /// The whole song's range counts as the whole-song loop, so tapping a
    /// song's only section turns it off again.
    func isLooping(start: TimeInterval, end: TimeInterval) -> Bool {
        if loop == .wholeSong { return isWholeSong(start: start, end: end) }
        return loop?.matches(start: start, end: end) ?? false
    }

    private func isWholeSong(start: TimeInterval, end: TimeInterval) -> Bool {
        guard let duration else { return false }
        return start < MarkerPlacement.sameTime && end > duration - MarkerPlacement.sameTime
    }

    /// Tapping a section block: loops the range, or stops looping when it's
    /// the range already looping. Never starts playback.
    func toggleLoopRange(start: TimeInterval, end: TimeInterval) {
        if isLooping(start: start, end: end) {
            stopLooping()
        } else {
            loopRange(start: start, end: end)
        }
    }

    func stopLooping() {
        setLoop(nil)
    }

    /// Turns looping on for the range, whatever was looping before. Arming a
    /// range from outside it moves the playhead in, so the loop starts now
    /// rather than once the rest of the song has played through. Doesn't
    /// start playback.
    func loopRange(start: TimeInterval, end: TimeInterval) {
        guard end > start else { return }
        // The player's own repeat wraps the whole song seamlessly; the
        // ticker would wrap it up to a poll late.
        if isWholeSong(start: start, end: end) {
            setLoop(.wholeSong)
            return
        }
        setLoop(.range(start: start, end: end))
        if !(start..<end).contains(playbackTime) {
            seek(to: start)
        }
        // The seek's settling window can outlast a short range, and a nudge
        // can leave the playhead just short of the new end; either way the
        // first reading past the end must wrap, not read as a user jump.
        wasInsideLoop = true
    }

    /// The one way the loop changes, so the player's repeat mode can't drift.
    /// Any new loop, or none, supersedes a pending A.
    private func setLoop(_ new: Loop?) {
        loop = new
        pendingA = nil
        wasInsideLoop = false
        applyRepeatMode()
    }

    /// A range needs repeat off: the ticker drives it, and a track
    /// repeating underneath would fight it.
    private func applyRepeatMode() {
        player.state.repeatMode = loop == .wholeSong ? .one : MusicPlayer.RepeatMode.none
    }

    private func applyRateIfPossible() {
        player.state.playbackRate = Float(playbackRate)
    }

    /// Apple has toggled third-party rate control for DRM content on and off
    /// across releases, so surface a silent reset rather than pretending the
    /// slowdown worked.
    private func verifyRateStuck() {
        guard isPlaying else { return }
        let actual = Double(player.state.playbackRate)
        if abs(actual - playbackRate) > 0.01 {
            rateWarning = "This track is playing at \(Int(actual * 100))% — Apple Music didn't accept the slower speed."
        } else {
            rateWarning = nil
        }
    }

    // MARK: - A·B

    /// The playhead when A was tapped, waiting for B. Here rather than in
    /// the screen so a relayout keeps it.
    private(set) var pendingA: TimeInterval?

    var abPhase: ABLoop.Phase {
        ABLoop.phase(pendingA: pendingA, isLooping: loop != nil)
    }

    /// What's looping as a range, the whole song as all of it.
    var loopBounds: ClosedRange<TimeInterval>? {
        switch loop {
        case nil: nil
        case .wholeSong: duration.map { 0...$0 }
        case .range(let start, let end): start...end
        }
    }

    /// A batch of markers just made by Add marker, A·B or Split, so the
    /// screen can offer to name them. Replaced by the next batch.
    struct CreatedMarkers: Identifiable {
        let id = UUID()
        let markers: [SongMarker]
    }

    private(set) var createdMarkers: CreatedMarkers?

    func dismissCreatedMarkers() {
        createdMarkers = nil
    }

    private func announce(_ markers: [SongMarker]) {
        guard !markers.isEmpty else { return }
        createdMarkers = CreatedMarkers(markers: markers)
    }

    /// Never starts or stops playback. From idle it sets A, and switches to
    /// Loop mode so the blocks can show it; with A set it closes the loop at
    /// the playhead; while anything loops it stops it.
    func tapAB(saved: SavedSong?) {
        switch abPhase {
        case .idle:
            guard duration != nil else { return }
            pendingA = playbackTime
            mode = .loop
        case .aSet(let tapped):
            closeLoop(a: tapped, saved: saved)
        case .looping:
            stopLooping()
        }
    }

    func cancelA() {
        pendingA = nil
    }

    /// Ends without a marker within the snap threshold get one, which saves
    /// an unsaved song as marking it does.
    private func closeLoop(a: TimeInterval, saved: SavedSong?) {
        guard let duration else { return }
        let song = saved ?? saveCurrentSong()
        guard let closed = ABLoop.close(
            a: a, b: playbackTime, duration: duration,
            song: song, in: song?.modelContext ?? modelContext
        ) else { return }
        loopRange(start: closed.loop.lowerBound, end: closed.loop.upperBound)
        announce(closed.created)
    }

    /// A marker at the playhead, less pre-roll, unless one is already within
    /// the snap threshold. Doesn't pause: naming it can wait.
    func addMarker(saved: SavedSong?) {
        guard duration != nil, let song = saved ?? saveCurrentSong(),
              let context = song.modelContext ?? modelContext
        else { return }
        let added = SongMarker.addSnapping(
            to: song,
            at: MarkerPlacement.compensatedStart(playbackTime),
            in: context
        )
        if added.created { announce([added.marker]) }
    }

    /// Nudging an end on a marker moves the marker, and with it the next
    /// or previous section; the loop follows. See `ABLoop.nudge`.
    func nudgeLoop(_ end: ABLoop.End, by offset: TimeInterval, saved: SavedSong?) {
        guard let duration, let bounds = loopBounds,
              let nudged = ABLoop.nudge(
                  end, of: bounds, by: offset, duration: duration,
                  song: saved, in: saved?.modelContext ?? modelContext
              )
        else { return }
        loopRange(start: nudged.lowerBound, end: nudged.upperBound)
    }

    /// "Split here" on B: gives B a marker of its own, so nudging it leaves
    /// the next section's start where it is. See `ABLoop.splitTime`.
    func splitLoopEnd(saved: SavedSong?) {
        guard let duration, let bounds = loopBounds,
              let song = saved ?? saveCurrentSong(),
              let context = song.modelContext ?? modelContext,
              let split = ABLoop.split(bounds, duration: duration, song: song, in: context)
        else { return }
        loopRange(start: split.loop.lowerBound, end: split.loop.upperBound)
        if let created = split.created { announce([created]) }
    }

    // MARK: - Persistence

    /// Every song opens in Play, at the speed it was saved with or full speed.
    func loadSavedSettings(songID: String) {
        isLoadingSavedSpeed = true
        defer { isLoadingSavedSpeed = false }

        let saved = modelContext.flatMap { SavedSong.find(songID: songID, in: $0) }
        playbackRate = saved?.speed ?? 1.0
        mode = .play
    }

    /// Only saved songs keep a practice date; playing an unsaved one leaves
    /// nothing behind.
    private func markPracticed() {
        guard let modelContext, let song = selectedSong,
              let saved = SavedSong.find(songID: song.id.rawValue, in: modelContext)
        else { return }
        SavedSong.markPracticed(saved, in: modelContext)
    }

    /// Deliberately not called from `playbackRate`'s `didSet`: speeds persist
    /// only on an explicit save, so the list stays curated.
    @discardableResult
    func saveCurrentSong() -> SavedSong? {
        guard let modelContext, let song = selectedSong else { return nil }
        return SavedSong.save(song: song, speed: playbackRate, in: modelContext)
    }
}
