import Foundation
import Observation

/// Drives the binaural generator screen.
@MainActor
@Observable
final class BinauralViewModel {

    let states = BinauralCatalog.all
    private(set) var current: BinauralState
    private(set) var isPlaying = false

    /// Live, adjustable tone parameters.
    private(set) var carrierHz: Double
    private(set) var beatHz: Double

    /// Active ambient soundscapes (multi-select) sharing one master level.
    private(set) var activeAmbiences: Set<Ambience> = []
    private(set) var ambienceLevel: Double = 0.5
    private(set) var spatialAmount: Double = 0.4

    /// Master output.
    private(set) var volume: Double = 0.85
    private(set) var muted = false

    private let engine: BinauralEngine
    private let tracker = HeadTracker()

    init(engine: BinauralEngine = .shared) {
        self.engine = engine
        let start = BinauralCatalog.default
        self.current = start
        self.carrierHz = start.carrierHz
        self.beatHz = start.beatHz
        // Head tracking is always on (no UI). No-op without supported AirPods.
        tracker.start(onYaw: { engine.setHeadYaw($0) })
    }

    /// Toggles a soundscape layer on/off.
    func toggleAmbience(_ value: Ambience) {
        if activeAmbiences.contains(value) {
            activeAmbiences.remove(value)
            engine.setAmbientLevel(type: value.code, level: 0)
        } else {
            activeAmbiences.insert(value)
            engine.setAmbientLevel(type: value.code, level: ambienceLevel)
        }
    }

    func isActive(_ value: Ambience) -> Bool { activeAmbiences.contains(value) }

    /// Sets the shared level for every active soundscape.
    func setAmbienceLevel(_ value: Double) {
        ambienceLevel = value
        for item in activeAmbiences {
            engine.setAmbientLevel(type: item.code, level: value)
        }
    }

    func setSpatial(_ value: Double) {
        spatialAmount = value
        engine.setSpatial(amount: value)
    }

    func setVolume(_ value: Double) {
        volume = value
        muted = value <= 0.001
        engine.setMasterVolume(value)
    }

    func toggleMute() {
        muted.toggle()
        engine.setMasterVolume(muted ? 0 : volume)
    }

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            engine.setTone(carrier: carrierHz, beat: beatHz)
            syncAmbiences()
            engine.setSpatial(amount: spatialAmount)
            engine.setMasterVolume(muted ? 0 : volume)
            engine.play()
        } else {
            engine.pause()
        }
    }

    func setPlaying(_ on: Bool) {
        if on != isPlaying { togglePlay() }
    }

    func select(_ state: BinauralState) {
        current = state
        carrierHz = state.carrierHz
        beatHz = state.beatHz
        engine.setTone(carrier: carrierHz, beat: beatHz)
    }

    func setCarrier(_ value: Double) {
        carrierHz = value
        engine.setTone(carrier: carrierHz, beat: beatHz)
    }

    func setBeat(_ value: Double) {
        beatHz = value
        engine.setTone(carrier: carrierHz, beat: beatHz)
    }

    /// Pushes the full active-soundscape set to the engine (used on play).
    private func syncAmbiences() {
        for type in 1..<BinauralEngine.typeCount {
            let on = activeAmbiences.contains { $0.code == type }
            engine.setAmbientLevel(type: type, level: on ? ambienceLevel : 0)
        }
    }
}
