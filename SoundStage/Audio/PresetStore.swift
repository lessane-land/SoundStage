import Foundation
import Observation

/// Defines the built-in presets and persists which one is selected.
///
/// Phase 1 ships a fixed catalog of six presets (see CLAUDE.md). The selection
/// is persisted by stable `Preset.id` via `UserDefaults` so it survives
/// relaunch. Observable + `@MainActor` because it backs SwiftUI view state.
@MainActor
@Observable
final class PresetStore {

    /// The full catalog, in display order.
    let presets: [Preset]

    /// Currently selected preset id. Mutating this persists the choice.
    private(set) var selectedPresetID: Preset.ID {
        didSet { defaults.set(selectedPresetID, forKey: Self.selectionKey) }
    }

    private let defaults: UserDefaults
    private static let selectionKey = "soundstage.selectedPresetID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let catalog = Self.makeCatalog()
        self.presets = catalog

        if let saved = defaults.string(forKey: Self.selectionKey),
           catalog.contains(where: { $0.id == saved }) {
            self.selectedPresetID = saved
        } else {
            self.selectedPresetID = catalog[0].id
        }
    }

    /// The resolved selected preset, falling back to the first entry.
    var selectedPreset: Preset {
        presets.first { $0.id == selectedPresetID } ?? presets[0]
    }

    func select(_ preset: Preset) {
        guard preset.id != selectedPresetID else { return }
        selectedPresetID = preset.id
    }

    // MARK: - Catalog

    private static func makeCatalog() -> [Preset] {
        [
            Preset(
                id: "club",
                label: "Club",
                description: "Intimate basement, 400 capacity",
                reverbPreset: .largeRoom,
                reverbBlend: 0.32,
                eqBands: [
                    EQBand(frequency: 60, gain: 4.5, bandwidth: 1.2, filterType: .lowShelf),
                    EQBand(frequency: 250, gain: -2.0, bandwidth: 1.0),
                    EQBand(frequency: 2_000, gain: 1.5, bandwidth: 1.0),
                    EQBand(frequency: 8_000, gain: 3.0, bandwidth: 1.2, filterType: .highShelf)
                ],
                roomSize: 0.62,
                stereoWidth: 0.6,
                gradientFromHex: 0x00D2FF,
                gradientToHex: 0x0066FF,
                shape: .arcs
            ),
            Preset(
                id: "warehouse-berlin",
                label: "Warehouse Berlin",
                description: "Industrial concrete, 3000 cap.",
                reverbPreset: .largeHall2,
                reverbBlend: 0.5,
                eqBands: [
                    EQBand(frequency: 50, gain: 5.0, bandwidth: 1.4, filterType: .lowShelf),
                    EQBand(frequency: 400, gain: -3.5, bandwidth: 1.1),
                    EQBand(frequency: 3_500, gain: -1.5, bandwidth: 1.0),
                    EQBand(frequency: 10_000, gain: -2.0, bandwidth: 1.2, filterType: .highShelf)
                ],
                roomSize: 0.92,
                stereoWidth: 0.8,
                gradientFromHex: 0x00E676,
                gradientToHex: 0xA8FF3E,
                shape: .angular
            ),
            Preset(
                id: "festival-outdoor",
                label: "Festival Outdoor",
                description: "Open-air mainstage, 50k crowd",
                reverbPreset: .largeChamber,
                reverbBlend: 0.4,
                eqBands: [
                    EQBand(frequency: 70, gain: 3.0, bandwidth: 1.2, filterType: .lowShelf),
                    EQBand(frequency: 1_000, gain: -1.0, bandwidth: 1.0),
                    EQBand(frequency: 5_000, gain: 2.0, bandwidth: 1.0),
                    EQBand(frequency: 12_000, gain: 2.5, bandwidth: 1.2, filterType: .highShelf)
                ],
                roomSize: 1.0,
                stereoWidth: 0.9,
                gradientFromHex: 0xFF2D55,
                gradientToHex: 0xFF5E3A,
                shape: .layers
            ),
            Preset(
                id: "headphone-journey",
                label: "Headphone Journey",
                description: "Binaural close-field intimacy",
                reverbPreset: .plate,
                reverbBlend: 0.24,
                eqBands: [
                    EQBand(frequency: 80, gain: 2.0, bandwidth: 1.0, filterType: .lowShelf),
                    EQBand(frequency: 500, gain: -1.0, bandwidth: 1.0),
                    EQBand(frequency: 4_000, gain: 1.0, bandwidth: 1.0),
                    EQBand(frequency: 11_000, gain: 1.5, bandwidth: 1.1, filterType: .highShelf)
                ],
                roomSize: 0.4,
                stereoWidth: 1.0,
                gradientFromHex: 0x13C57A,
                gradientToHex: 0x7BFF5E,
                shape: .curves
            ),
            Preset(
                id: "focus",
                label: "Focus",
                description: "Dry, controlled, zero distraction",
                reverbPreset: .smallRoom,
                reverbBlend: 0.08,
                eqBands: [
                    EQBand(frequency: 120, gain: -1.0, bandwidth: 1.0, filterType: .lowShelf),
                    EQBand(frequency: 1_500, gain: 1.0, bandwidth: 1.2),
                    EQBand(frequency: 6_000, gain: 0.5, bandwidth: 1.0, filterType: .highShelf)
                ],
                roomSize: 0.2,
                stereoWidth: 0.35,
                gradientFromHex: 0x3D8BFF,
                gradientToHex: 0x7A8EFF,
                shape: .grid
            ),
            Preset(
                id: "running",
                label: "Running",
                description: "Punchy, forward, high energy",
                reverbPreset: .mediumRoom,
                reverbBlend: 0.14,
                eqBands: [
                    EQBand(frequency: 65, gain: 3.5, bandwidth: 1.1, filterType: .lowShelf),
                    EQBand(frequency: 900, gain: 1.5, bandwidth: 1.0),
                    EQBand(frequency: 3_000, gain: 2.5, bandwidth: 1.0),
                    EQBand(frequency: 9_000, gain: 2.0, bandwidth: 1.1, filterType: .highShelf)
                ],
                roomSize: 0.3,
                stereoWidth: 0.55,
                gradientFromHex: 0xFF1F3D,
                gradientToHex: 0xFF7A45,
                shape: .pulse
            )
        ]
    }
}
