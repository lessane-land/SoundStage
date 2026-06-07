import AVFoundation

/// A single parametric EQ band.
///
/// Mirrors the parameters of `AVAudioUnitEQFilterParameters` but as a plain,
/// `Sendable` value type so presets can be defined as data and freely passed
/// between isolation domains. `AudioEngine` copies these onto the live
/// `AVAudioUnitEQ.bands` when a preset is applied.
struct EQBand: Equatable, Sendable {
    var frequency: Float          // center frequency in Hz
    var gain: Float               // gain in dB (negative cuts, positive boosts)
    var bandwidth: Float          // bandwidth in octaves
    var filterType: AVAudioUnitEQFilterType

    init(
        frequency: Float,
        gain: Float,
        bandwidth: Float = 1.0,
        filterType: AVAudioUnitEQFilterType = .parametric
    ) {
        self.frequency = frequency
        self.gain = gain
        self.bandwidth = bandwidth
        self.filterType = filterType
    }
}

/// An acoustic environment the user can apply to playback.
///
/// A preset is pure data: it describes the reverb character, EQ shape and a
/// perceptual "room size". `AudioEngine` translates it into live node state.
/// `id` is a stable string slug so the user's selection survives relaunch.
struct Preset: Identifiable, Equatable, Sendable {
    let id: String
    var label: String
    var description: String

    /// Factory reverb voicing.
    var reverbPreset: AVAudioUnitReverbPreset
    /// Wet/dry mix expressed 0.0...1.0 (mapped to 0...100 on the reverb node).
    var reverbBlend: Float
    /// Parametric EQ shape.
    var eqBands: [EQBand]
    /// Perceptual room size 0.0...1.0, drives the environment node's reverb.
    var roomSize: Float
}
