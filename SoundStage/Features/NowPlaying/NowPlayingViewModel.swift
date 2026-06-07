import Foundation
import Observation

/// Drives the main player screen.
///
/// Holds the current track, transport state and the active preset, delegating
/// audio work to the (non-MainActor) `AudioEngine`. `@MainActor` so it can back
/// SwiftUI state directly; engine calls are safe because `AudioEngine` is
/// `Sendable` and internally serialized.
@MainActor
@Observable
final class NowPlayingViewModel {

    private(set) var currentTrack: Track
    private(set) var activePreset: Preset
    private(set) var isPlaying = false

    private let presetStore: PresetStore
    private let engine: AudioEngine

    init(presetStore: PresetStore, engine: AudioEngine = .shared) {
        self.presetStore = presetStore
        self.engine = engine
        self.currentTrack = .placeholder
        self.activePreset = presetStore.selectedPreset
    }

    /// Wires up the engine and applies the persisted preset. Call once on appear.
    func prepare() {
        engine.prepare()
        engine.apply(activePreset)
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
        try? engine.load(track: track)
        if autoPlay {
            togglePlayback()
        }
    }

    func apply(_ preset: Preset) {
        activePreset = preset
        engine.apply(preset)
    }
}
