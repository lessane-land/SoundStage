import Foundation

/// A saved configuration: a mental state plus the full mix and live tweaks.
/// Persisted as JSON in UserDefaults so favorites survive relaunches.
struct BinauralPreset: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var stateId: String
    var beatHz: Double
    var carrierHz: Double
    var spatial: Double
    var ambienceLevel: Double
    /// Soundscape rawValue → per-layer volume (0...1).
    var mix: [String: Double]

    /// Active soundscapes, decoded back into the enum (ignoring unknown keys).
    var ambienceMix: [Ambience: Double] {
        var result: [Ambience: Double] = [:]
        for (key, value) in mix {
            if let amb = Ambience(rawValue: key) { result[amb] = value }
        }
        return result
    }

    /// A short one-line summary for the card subtitle.
    var summary: String {
        let st = BinauralCatalog.all.first { $0.id == stateId } ?? BinauralCatalog.default
        let hz = beatHz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(beatHz))" : String(format: "%.1f", beatHz)
        let sounds = ambienceMix.keys.map(\.label)
        let soundsText = sounds.isEmpty ? "No ambience" : sounds.sorted().joined(separator: " + ")
        return "\(st.name) · \(st.band) \(hz)Hz · \(soundsText)"
    }
}

/// Loads and saves favorite presets in UserDefaults.
enum BinauralPresetStore {
    private static let key = "soundstage.presets.v1"

    static let seed: [BinauralPreset] = [
        BinauralPreset(id: "p1", name: "Morning Focus", stateId: "focus", beatHz: 10, carrierHz: 174,
                       spatial: 0.4, ambienceLevel: 0.55, mix: ["Rain": 0.6, "Wind": 0.4]),
        BinauralPreset(id: "p2", name: "Deep Sleep", stateId: "sleep", beatHz: 2.5, carrierHz: 158,
                       spatial: 0.7, ambienceLevel: 0.7, mix: ["Ocean": 0.7, "Rain": 0.4]),
        BinauralPreset(id: "p3", name: "Campfire Calm", stateId: "meditate", beatHz: 6, carrierHz: 168,
                       spatial: 0.5, ambienceLevel: 0.65, mix: ["Fire": 0.7, "Forest": 0.5])
    ]

    static func load() -> [BinauralPreset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let presets = try? JSONDecoder().decode([BinauralPreset].self, from: data) else {
            return seed
        }
        return presets
    }

    static func save(_ presets: [BinauralPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
