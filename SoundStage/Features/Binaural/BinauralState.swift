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

enum BinauralCatalog {
    static let all: [BinauralState] = [
        BinauralState(id: "sleep", name: "Deep Sleep", band: "Delta",
                      detail: "Drift into deep, dreamless rest", beatHz: 2.5, carrierHz: 120,
                      fromHex: 0x3D8BFF, toHex: 0x7A8EFF),
        BinauralState(id: "meditate", name: "Meditate", band: "Theta",
                      detail: "Calm, dreamlike stillness", beatHz: 6, carrierHz: 150,
                      fromHex: 0x13C57A, toHex: 0x7BFF5E),
        BinauralState(id: "relax", name: "Relax", band: "Theta",
                      detail: "Let the day melt away", beatHz: 4, carrierHz: 160,
                      fromHex: 0x00D2FF, toHex: 0x0066FF),
        BinauralState(id: "focus", name: "Focus", band: "Alpha",
                      detail: "Calm, clear concentration", beatHz: 10, carrierHz: 200,
                      fromHex: 0x6C5CE7, toHex: 0xC56BFF),
        BinauralState(id: "flow", name: "Flow", band: "Beta",
                      detail: "Locked-in productivity", beatHz: 16, carrierHz: 220,
                      fromHex: 0xFF7A45, toHex: 0xFFC83D),
        BinauralState(id: "energy", name: "Energy", band: "Beta",
                      detail: "Wake up and get going", beatHz: 22, carrierHz: 240,
                      fromHex: 0xFF1F3D, toHex: 0xFF7A45)
    ]

    static let `default` = all[3] // Focus
}
