import SwiftUI

/// A binaural "state": a target mental state defined by its brainwave band
/// (the beat frequency) and a carrier tone, with a gradient identity.
struct BinauralState: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let band: String
    let detail: String
    /// Beat frequency in Hz (the perceived pulse / brainwave band).
    let beatHz: Double
    /// Carrier tone in Hz.
    let carrierHz: Double
    let fromHex: UInt32
    let toHex: UInt32

    var fromColor: Color { Color(hex: fromHex) }
    var toColor: Color { Color(hex: toHex) }
    var gradient: LinearGradient {
        LinearGradient(colors: [fromColor, toColor], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// An ambient soundscape layered over the binaural beat (all synthesized).
enum Ambience: String, CaseIterable, Identifiable {
    case rain = "Rain"
    case ocean = "Ocean"
    case forest = "Forest"
    case wind = "Wind"
    case noise = "Noise"
    case thunder = "Thunder"
    case fire = "Fire"
    case cafe = "Café"
    case stream = "Stream"

    var id: String { rawValue }

    var label: String { self == .noise ? "White Noise" : rawValue }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .forest: return "tree.fill"
        case .wind: return "wind"
        case .noise: return "waveform"
        case .thunder: return "cloud.bolt.rain.fill"
        case .fire: return "flame.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .stream: return "drop.fill"
        }
    }

    /// Code the audio engine uses.
    var code: Int {
        switch self {
        case .rain: return 1
        case .ocean: return 2
        case .forest: return 3
        case .wind: return 4
        case .noise: return 5
        case .thunder: return 6
        case .fire: return 7
        case .cafe: return 8
        case .stream: return 9
        }
    }
}

enum BinauralCatalog {
    static let all: [BinauralState] = [
        BinauralState(id: "sleep", name: "Deep Sleep", band: "Delta",
                      detail: "Drift into deep, dreamless rest", beatHz: 2.5, carrierHz: 90,
                      fromHex: 0x3D8BFF, toHex: 0x7A8EFF),
        BinauralState(id: "relax", name: "Relax", band: "Theta",
                      detail: "Let the day melt away", beatHz: 4, carrierHz: 100,
                      fromHex: 0x00D2FF, toHex: 0x0066FF),
        BinauralState(id: "meditate", name: "Meditate", band: "Theta",
                      detail: "Settle into calm awareness", beatHz: 6, carrierHz: 105,
                      fromHex: 0x13C57A, toHex: 0x7BFF5E),
        BinauralState(id: "focus", name: "Focus", band: "Alpha",
                      detail: "Clear, sustained concentration", beatHz: 10, carrierHz: 110,
                      fromHex: 0x6C5CE7, toHex: 0xC56BFF),
        BinauralState(id: "flow", name: "Flow", band: "Beta",
                      detail: "Effortless creative momentum", beatHz: 16, carrierHz: 120,
                      fromHex: 0xFF7A45, toHex: 0xFFC83D),
        BinauralState(id: "energy", name: "Energy", band: "Beta",
                      detail: "Bright, awake, ready to move", beatHz: 22, carrierHz: 130,
                      fromHex: 0xFF1F3D, toHex: 0xFF7A45),
        BinauralState(id: "sharp", name: "Sharp", band: "Gamma",
                      detail: "Peak alertness and recall", beatHz: 38, carrierHz: 140,
                      fromHex: 0xFFC83D, toHex: 0xFF7A45)
    ]

    static let `default` = all[3] // Focus
}
