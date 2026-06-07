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
            // Stop at the end of the track.
            if duration > 0, elapsed >= duration - 0.05 {
                elapsed = duration
                isPlaying = false
                engine.pause()
            }
        }
    }
}
