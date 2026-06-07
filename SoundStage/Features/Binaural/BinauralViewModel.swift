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

    private let engine: BinauralEngine

    init(engine: BinauralEngine = .shared) {
        self.engine = engine
        let start = BinauralCatalog.default
        self.current = start
        self.carrierHz = start.carrierHz
        self.beatHz = start.beatHz
    }

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            engine.setTone(carrier: carrierHz, beat: beatHz)
            engine.play()
        } else {
            engine.pause()
        }
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
