import Foundation
import Observation

/// Drives the binaural generator screen, the soundscape mixer, favorites and
/// settings — the single source of truth wired to the audio engine.
@MainActor
@Observable
final class BinauralViewModel {

    let states = BinauralCatalog.all
    private(set) var current: BinauralState
    private(set) var isPlaying = false

    /// Live, adjustable tone parameters.
    private(set) var carrierHz: Double
    private(set) var beatHz: Double

    /// Per-layer soundscape mix (presence = active, value = layer volume 0...1).
    private(set) var mix: [Ambience: Double] = [:]
    /// Master ambience level (the AMBIENCE slider) scaling every layer.
    private(set) var ambienceLevel: Double = 0.6
    private(set) var spatialAmount: Double = 0.4
    /// Binaural-tone volume (0 = off). Kept gentle by default.
    private(set) var toneLevel: Double = 0.45

    /// Master output + session options.
    private(set) var volume: Double = 0.85
    private(set) var muted = false
    var chime = true

    /// Favorites.
    private(set) var presets: [BinauralPreset] = BinauralPresetStore.load()

    private let engine: BinauralEngine
    private let tracker = HeadTracker()
    private let nowPlaying = NowPlayingController()

    init(engine: BinauralEngine = .shared) {
        self.engine = engine
        let start = BinauralCatalog.default
        self.current = start
        self.carrierHz = start.carrierHz
        self.beatHz = start.beatHz
        // Head tracking is always on (no UI). No-op without supported AirPods.
        tracker.start(onYaw: { engine.setHeadYaw($0) })
        // Lock-screen / Control Center transport.
        nowPlaying.onToggle = { [weak self] in self?.togglePlay() }
        nowPlaying.onPlay = { [weak self] in self?.setPlaying(true) }
        nowPlaying.onPause = { [weak self] in self?.setPlaying(false) }
    }

    private func publishNowPlaying() {
        nowPlaying.update(title: current.name, subtitle: "Binaural · Spatial", isPlaying: isPlaying)
    }

    // MARK: - Soundscape mix

    var activeCount: Int { mix.count }
    func isActive(_ value: Ambience) -> Bool { mix[value] != nil }
    func layerVolume(_ value: Ambience) -> Double { mix[value] ?? 0.6 }

    /// Toggles a soundscape on (default 60%) / off.
    func toggleAmbience(_ value: Ambience) {
        if mix[value] != nil {
            mix[value] = nil
            engine.setAmbientLevel(type: value.code, level: 0)
        } else {
            mix[value] = 0.6
            pushLayer(value)
        }
    }

    /// Sets one layer's volume (within the mixer).
    func setLayerVolume(_ value: Ambience, _ level: Double) {
        mix[value] = level
        pushLayer(value)
    }

    func clearMix() {
        for key in mix.keys { engine.setAmbientLevel(type: key.code, level: 0) }
        mix.removeAll()
    }

    /// Sets the master ambience level, rescaling every active layer.
    func setAmbienceLevel(_ value: Double) {
        ambienceLevel = value
        for key in mix.keys { pushLayer(key) }
    }

    private func pushLayer(_ value: Ambience) {
        let level = (mix[value] ?? 0) * ambienceLevel
        engine.setAmbientLevel(type: value.code, level: level)
    }

    private func syncAllLayers() {
        for type in 1..<BinauralEngine.typeCount {
            let active = mix.first { $0.key.code == type }
            engine.setAmbientLevel(type: type, level: (active?.value ?? 0) * ambienceLevel)
        }
    }

    // MARK: - Spatial & master

    func setSpatial(_ value: Double) {
        spatialAmount = value
        engine.setSpatial(amount: value)
    }

    func setToneLevel(_ value: Double) {
        toneLevel = value
        engine.setToneLevel(value)
    }

    func setVolume(_ value: Double) {
        volume = value
        muted = value <= 0.001
        engine.setMasterVolume(value)
    }

    func setMuted(_ value: Bool) {
        muted = value
        engine.setMasterVolume(value ? 0 : volume)
    }

    func toggleMute() { setMuted(!muted) }

    // MARK: - Transport

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            engine.setTone(carrier: carrierHz, beat: beatHz)
            engine.setToneLevel(toneLevel)
            syncAllLayers()
            engine.setSpatial(amount: spatialAmount)
            engine.setMasterVolume(muted ? 0 : volume)
            engine.play()
        } else {
            engine.pause()
        }
        publishNowPlaying()
    }

    func setPlaying(_ on: Bool) {
        if on != isPlaying { togglePlay() }
    }

    /// Lowers master volume for a sleep fade (does not touch the saved volume).
    func applyFade(_ factor: Double) {
        engine.setMasterVolume(muted ? 0 : volume * max(0, min(1, factor)))
    }

    func restoreVolume() {
        engine.setMasterVolume(muted ? 0 : volume)
    }

    func ringChime() {
        if chime { engine.playChime() }
    }

    // MARK: - State / tone

    func select(_ state: BinauralState) {
        current = state
        carrierHz = state.carrierHz
        beatHz = state.beatHz
        engine.setTone(carrier: carrierHz, beat: beatHz)
        publishNowPlaying()
    }

    func setCarrier(_ value: Double) {
        carrierHz = value
        engine.setTone(carrier: carrierHz, beat: beatHz)
    }

    func setBeat(_ value: Double) {
        beatHz = value
        engine.setTone(carrier: carrierHz, beat: beatHz)
    }

    // MARK: - Favorites

    func saveCurrentPreset(named name: String) {
        let preset = BinauralPreset(
            id: "u\(Int(Date().timeIntervalSince1970 * 1000))",
            name: name, stateId: current.id, beatHz: beatHz, carrierHz: carrierHz,
            spatial: spatialAmount, ambienceLevel: ambienceLevel,
            mix: Dictionary(uniqueKeysWithValues: mix.map { ($0.key.rawValue, $0.value) })
        )
        presets.append(preset)
        persist()
    }

    func renamePreset(_ preset: BinauralPreset, to name: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        persist()
    }

    func deletePreset(_ preset: BinauralPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func loadPreset(_ preset: BinauralPreset) {
        if let state = states.first(where: { $0.id == preset.stateId }) { current = state }
        carrierHz = preset.carrierHz
        beatHz = preset.beatHz
        spatialAmount = preset.spatial
        ambienceLevel = preset.ambienceLevel
        mix = preset.ambienceMix
        engine.setTone(carrier: carrierHz, beat: beatHz)
        engine.setSpatial(amount: spatialAmount)
        syncAllLayers()
    }

    private func persist() { BinauralPresetStore.save(presets) }
}
