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

    /// Ambient soundscape + spatial orbit.
    private(set) var ambience: Ambience?
    private(set) var ambienceLevel: Double = 0.5
    private(set) var spatialAmount: Double = 0.4

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

    func toggleAmbience(_ value: Ambience) {
        ambience = (ambience == value) ? nil : value
        engine.setAmbient(type: ambience?.code ?? 0, level: ambienceLevel)
    }

    func setAmbienceLevel(_ value: Double) {
        ambienceLevel = value
        engine.setAmbient(type: ambience?.code ?? 0, level: value)
    }

    func setSpatial(_ value: Double) {
        spatialAmount = value
        engine.setSpatial(amount: value)
    }

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            engine.setTone(carrier: carrierHz, beat: beatHz)
            engine.setAmbient(type: ambience?.code ?? 0, level: ambienceLevel)
            engine.setSpatial(amount: spatialAmount)
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
}
