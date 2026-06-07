import Foundation
import Observation

/// Drives the main player screen, routing playback by track origin:
/// `.local` tracks stream through `AudioEngine` (spatial presets apply);
/// `.appleMusic` tracks play via `SystemMusicPlayer` / `MPMusicPlayerController`
/// (Apple's DRM means the presets are a visual theme only).
@MainActor
@Observable
final class NowPlayingViewModel {

    private(set) var currentTrack: Track
    private(set) var activePreset: Preset
    private(set) var isPlaying = false
    private(set) var isLoading = false
    var loadError: String?

    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isSeeking = false

    private(set) var queue: [Track] = []
    private(set) var queueIndex = 0

    private let presetStore: PresetStore
    private let engine: AudioEngine
    private let systemPlayer: SystemMusicPlayer?
    private var ticker: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    init(presetStore: PresetStore, engine: AudioEngine = .shared, systemPlayer: SystemMusicPlayer? = nil) {
        self.presetStore = presetStore
        self.engine = engine
        self.systemPlayer = systemPlayer
        self.currentTrack = .placeholder
        self.activePreset = presetStore.selectedPreset
    }

    var progress: Double { duration > 0 ? min(1, elapsed / duration) : 0 }
    var hasTrack: Bool { currentTrack.isPlayable }
    var isAppleMusic: Bool { currentTrack.origin == .appleMusic }
    /// Whether the spatial presets actually process the current track's audio.
    var effectsAvailable: Bool { !isAppleMusic }

    var canGoNext: Bool { isAppleMusic ? !queue.isEmpty : queueIndex + 1 < queue.count }
    var canGoPrevious: Bool { !queue.isEmpty }

    func prepare() {
        engine.prepare()
        engine.apply(activePreset)
        startTicker()
    }

    func togglePlayback() {
        guard hasTrack, !isLoading else { return }
        if isAppleMusic {
            systemPlayer?.togglePlayback()
            isPlaying = systemPlayer?.isPlaying ?? false
        } else {
            isPlaying.toggle()
            if isPlaying { engine.play() } else { engine.pause() }
        }
    }

    func play(_ track: Track, in tracks: [Track]) {
        queue = tracks
        queueIndex = tracks.firstIndex(of: track) ?? 0
        if track.origin == .appleMusic {
            playAppleMusic(track, in: tracks)
        } else {
            load(track)
        }
    }

    // MARK: - Local playback (effects engine)

    func load(_ track: Track, autoPlay: Bool = true) {
        systemPlayer?.pause()
        currentTrack = track
        isPlaying = false
        elapsed = 0
        duration = 0
        loadTask?.cancel()

        guard track.assetURL != nil else {
            loadError = "This track isn't available locally and can't be played through SoundStage."
            return
        }

        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.engine.load(track: track)
                if Task.isCancelled { return }
                self.duration = self.engine.duration
                self.isLoading = false
                if autoPlay {
                    self.isPlaying = true
                    self.engine.play()
                }
            } catch is CancellationError {
            } catch {
                self.isLoading = false
                self.loadError = "This track can't be played through SoundStage. It may be DRM-protected or stored only in the cloud."
            }
        }
    }

    // MARK: - System playback (Apple Music / cloud / protected)

    private func playAppleMusic(_ track: Track, in tracks: [Track]) {
        guard let systemPlayer, let playbackID = track.playbackID else {
            loadError = "This track can't be played on this device."
            return
        }
        engine.pause()
        loadTask?.cancel()
        currentTrack = track
        isLoading = false
        elapsed = 0
        duration = track.duration
        systemPlayer.play(playbackID: playbackID, queueIDs: tracks.compactMap(\.playbackID))
        isPlaying = true
    }

    // MARK: - Transport

    func next() {
        if isAppleMusic {
            systemPlayer?.next()
            syncSystemNowPlaying()
            return
        }
        guard canGoNext else { return }
        queueIndex += 1
        load(queue[queueIndex])
    }

    func previous() {
        if isAppleMusic {
            systemPlayer?.previous()
            syncSystemNowPlaying()
            return
        }
        guard !queue.isEmpty else { return }
        if elapsed > 3 || queueIndex == 0 {
            elapsed = 0
            engine.seek(to: 0)
        } else {
            queueIndex -= 1
            load(queue[queueIndex])
        }
    }

    func apply(_ preset: Preset) {
        activePreset = preset
        engine.apply(preset)
    }

    /// Live-applies a preset's reverb/EQ while the user drags the detail sliders,
    /// without committing it as the active preset.
    func previewPreset(_ preset: Preset) {
        engine.applyEffects(preset)
    }

    /// Reverts a live preview back to the committed preset.
    func cancelPreview() {
        engine.applyEffects(activePreset)
    }

    // MARK: - Scrubbing

    func beginSeeking() {
        guard hasTrack else { return }
        isSeeking = true
    }

    func scrub(toFraction fraction: Double) {
        guard duration > 0 else { return }
        elapsed = max(0, min(1, fraction)) * duration
    }

    func endSeeking() {
        guard isSeeking else { return }
        if isAppleMusic {
            systemPlayer?.seek(to: elapsed)
        } else {
            engine.seek(to: elapsed)
        }
        isSeeking = false
    }

    // MARK: - Ticker

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard !isSeeking else { return }

        if isAppleMusic {
            guard let systemPlayer else { return }
            systemPlayer.refreshState()
            isPlaying = systemPlayer.isPlaying
            if systemPlayer.duration > 0 { duration = systemPlayer.duration }
            if isPlaying { elapsed = systemPlayer.elapsed }
            syncSystemNowPlaying()
            return
        }

        duration = engine.duration
        if isPlaying {
            elapsed = engine.currentTime
            if duration > 0, elapsed >= duration - 0.05 {
                if canGoNext {
                    next()
                } else {
                    elapsed = duration
                    isPlaying = false
                    engine.pause()
                }
            }
        }
    }

    /// Tracks the system player advancing to a new queue item.
    private func syncSystemNowPlaying() {
        guard let systemPlayer, let id = systemPlayer.nowPlayingID else { return }
        guard String(id) != currentTrack.id,
              let track = queue.first(where: { $0.playbackID == id }) else { return }
        currentTrack = track
        queueIndex = queue.firstIndex(where: { $0.playbackID == id }) ?? queueIndex
        if systemPlayer.duration > 0 { duration = systemPlayer.duration }
    }
}
