import Foundation
import Observation

/// Drives the main player screen, routing playback by track origin:
/// `.local` tracks stream through `AudioEngine` (spatial presets apply);
/// `.appleMusic` tracks play via `AppleMusicService` / `ApplicationMusicPlayer`
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
    private let appleMusic: AppleMusicService?
    private var ticker: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    init(presetStore: PresetStore, engine: AudioEngine = .shared, appleMusic: AppleMusicService? = nil) {
        self.presetStore = presetStore
        self.engine = engine
        self.appleMusic = appleMusic
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
            guard let appleMusic else { return }
            Task {
                await appleMusic.togglePlayback()
                isPlaying = appleMusic.isPlaying
            }
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

    // MARK: - Local playback

    func load(_ track: Track, autoPlay: Bool = true) {
        appleMusic?.pause()
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

    // MARK: - Apple Music playback

    private func playAppleMusic(_ track: Track, in tracks: [Track]) {
        guard let appleMusic else {
            loadError = "Apple Music isn't set up on this device."
            return
        }
        engine.pause()
        loadTask?.cancel()
        currentTrack = track
        elapsed = 0
        duration = track.duration
        isPlaying = false
        isLoading = true
        Task {
            await appleMusic.play(trackID: track.id, queueIDs: tracks.map(\.id))
            isLoading = false
            isPlaying = appleMusic.isPlaying
            if appleMusic.duration > 0 { duration = appleMusic.duration }
        }
    }

    // MARK: - Transport

    func next() {
        if isAppleMusic {
            guard let appleMusic else { return }
            Task { await appleMusic.next(); syncAppleNowPlaying() }
            return
        }
        guard canGoNext else { return }
        queueIndex += 1
        load(queue[queueIndex])
    }

    func previous() {
        if isAppleMusic {
            guard let appleMusic else { return }
            Task { await appleMusic.previous(); syncAppleNowPlaying() }
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
            appleMusic?.seek(to: elapsed)
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
            guard let appleMusic else { return }
            appleMusic.refreshState()
            isPlaying = appleMusic.isPlaying
            if appleMusic.duration > 0 { duration = appleMusic.duration }
            if isPlaying { elapsed = appleMusic.elapsed }
            syncAppleNowPlaying()
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

    /// Tracks the Apple Music system player advancing to a new queue entry.
    private func syncAppleNowPlaying() {
        guard let appleMusic,
              let id = appleMusic.nowPlayingID,
              id != currentTrack.id,
              let track = queue.first(where: { $0.id == id }) else { return }
        currentTrack = track
        queueIndex = queue.firstIndex(where: { $0.id == id }) ?? queueIndex
        if appleMusic.duration > 0 { duration = appleMusic.duration }
    }
}
