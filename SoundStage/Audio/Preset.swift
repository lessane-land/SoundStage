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

/// The geometric identity drawn for each preset (see `PresetGlyph`).
enum PresetShape: Equatable, Sendable {
    case arcs       // Club — concentric arcs radiating
    case angular    // Warehouse — hard angular concrete lines
    case layers     // Festival — horizontal stacked layers
    case curves     // Headphone Journey — flowing intertwined curves
    case grid       // Focus — precise controlled grid
    case pulse      // Running — punchy forward chevrons
}

/// An acoustic environment the user can apply to playback.
///
/// A preset is pure data: it describes the reverb character, EQ shape, a
/// perceptual "room size" and stereo width, plus a visual identity (a gradient
/// and a geometric shape) that the whole UI re-themes to. `AudioEngine`
/// translates the audio fields into live node state. `id` is a stable string
/// slug so the user's selection survives relaunch.
struct Preset: Identifiable, Equatable, Sendable {
    let id: String
    var label: String
    var description: String

    // Audio
    /// Factory reverb voicing.
    var reverbPreset: AVAudioUnitReverbPreset
    /// Wet/dry mix expressed 0.0...1.0 (mapped to 0...100 on the reverb node).
    var reverbBlend: Float
    /// Parametric EQ shape.
    var eqBands: [EQBand]
    /// Perceptual room size 0.0...1.0, surfaced as a control in the detail editor.
    var roomSize: Float
    /// Stereo spread 0.0...1.0, surfaced as a control in the detail editor.
    var stereoWidth: Float

    // Visual identity
    /// Gradient start color (0xRRGGBB).
    var gradientFromHex: UInt32
    /// Gradient end color (0xRRGGBB).
    var gradientToHex: UInt32
    /// Geometric glyph drawn on cards and the detail header.
    var shape: PresetShape
}
