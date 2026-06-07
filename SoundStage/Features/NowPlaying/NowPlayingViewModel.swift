import Foundation
import Observation

/// Drives the main player screen.
///
/// Holds the current track, transport state, the active preset and live
/// playback progress, delegating audio work to the (non-MainActor)
/// `AudioEngine`. `@MainActor` so it can back SwiftUI state directly; engine
/// calls are safe because `AudioEngine` is `Sendable` and internally serialized.
@MainActor
@Observable
final class NowPlayingViewModel {

    private(set) var currentTrack: Track
    private(set) var activePreset: Preset
    private(set) var isPlaying = false

    /// Elapsed / total playback time in seconds, refreshed by the ticker.
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// True while the user is dragging the scrubber, which pauses ticker updates.
    private(set) var isSeeking = false

    /// The current play queue and the index of the playing track within it.
    private(set) var queue: [Track] = []
    private(set) var queueIndex = 0

    private let presetStore: PresetStore
    private let engine: AudioEngine
    private var ticker: Task<Void, Never>?

    init(presetStore: PresetStore, engine: AudioEngine = .shared) {
        self.presetStore = presetStore
        self.engine = engine
        self.currentTrack = .placeholder
        self.activePreset = presetStore.selectedPreset
    }

    /// Progress as a 0...1 fraction for the scrubber.
    var progress: Double {
        duration > 0 ? min(1, elapsed / duration) : 0
    }

    var canGoNext: Bool { queueIndex + 1 < queue.count }
    var canGoPrevious: Bool { !queue.isEmpty }

    /// Wires up the engine, applies the persisted preset and starts the ticker.
    func prepare() {
        engine.prepare()
        engine.apply(activePreset)
        startTicker()
    }

    func togglePlayback() {
        guard currentTrack.assetURL != nil else { return }
        isPlaying.toggle()
        if isPlaying {
            engine.play()
        } else {
            engine.pause()
        }
    }

    /// Starts playing `track` within the context of `tracks` so prev/next can
    /// move through the surrounding list.
    func play(_ track: Track, in tracks: [Track]) {
        queue = tracks
        queueIndex = tracks.firstIndex(of: track) ?? 0
        load(track)
    }

    func load(_ track: Track, autoPlay: Bool = true) {
        currentTrack = track
        isPlaying = false
        elapsed = 0
        try? engine.load(track: track)
        duration = engine.duration
        if autoPlay {
            togglePlayback()
        }
    }

    func next() {
        guard canGoNext else { return }
        queueIndex += 1
        load(queue[queueIndex])
    }

    /// Restarts the current track if we're past the first few seconds,
    /// otherwise steps to the previous track.
    func previous() {
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
        isSeeking = true
    }

    /// Updates the displayed position while dragging (no audio seek yet).
    func scrub(toFraction fraction: Double) {
        guard duration > 0 else { return }
        elapsed = max(0, min(1, fraction)) * duration
    }

    /// Commits the scrub: seeks the engine and resumes ticker updates.
    func endSeeking() {
        engine.seek(to: elapsed)
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
        duration = engine.duration
        if isPlaying {
            elapsed = engine.currentTime
            // At the end of the track, advance to the next one or stop.
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
}
