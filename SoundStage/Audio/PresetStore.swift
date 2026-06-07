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
                description: "Tight low end and a close, energetic room.",
                reverbPreset: .largeRoom,
                reverbBlend: 0.32,
                eqBands: [
                    EQBand(frequency: 60, gain: 4.5, bandwidth: 1.2, filterType: .lowShelf),
                    EQBand(frequency: 250, gain: -2.0, bandwidth: 1.0),
                    EQBand(frequency: 2_000, gain: 1.5, bandwidth: 1.0),
                    EQBand(frequency: 8_000, gain: 3.0, bandwidth: 1.2, filterType: .highShelf)
                ],
                roomSize: 0.7
            ),
            Preset(
                id: "warehouse-berlin",
                label: "Warehouse Berlin",
                description: "Cavernous concrete with a long, dark tail.",
                reverbPreset: .largeHall2,
                reverbBlend: 0.5,
                eqBands: [
                    EQBand(frequency: 50, gain: 5.0, bandwidth: 1.4, filterType: .lowShelf),
                    EQBand(frequency: 400, gain: -3.5, bandwidth: 1.1),
                    EQBand(frequency: 3_500, gain: -1.5, bandwidth: 1.0),
                    EQBand(frequency: 10_000, gain: -2.0, bandwidth: 1.2, filterType: .highShelf)
                ],
                roomSize: 0.92
            ),
            Preset(
                id: "festival-outdoor",
                label: "Festival Outdoor",
                description: "Wide open air with a distant main-stage spread.",
                reverbPreset: .largeChamber,
                reverbBlend: 0.4,
                eqBands: [
                    EQBand(frequency: 70, gain: 3.0, bandwidth: 1.2, filterType: .lowShelf),
                    EQBand(frequency: 1_000, gain: -1.0, bandwidth: 1.0),
                    EQBand(frequency: 5_000, gain: 2.0, bandwidth: 1.0),
                    EQBand(frequency: 12_000, gain: 2.5, bandwidth: 1.2, filterType: .highShelf)
                ],
                roomSize: 1.0
            ),
            Preset(
                id: "headphone-journey",
                label: "Headphone Journey",
                description: "Smooth, wide and intimate for late-night listening.",
                reverbPreset: .plate,
                reverbBlend: 0.24,
                eqBands: [
                    EQBand(frequency: 80, gain: 2.0, bandwidth: 1.0, filterType: .lowShelf),
                    EQBand(frequency: 500, gain: -1.0, bandwidth: 1.0),
                    EQBand(frequency: 4_000, gain: 1.0, bandwidth: 1.0),
                    EQBand(frequency: 11_000, gain: 1.5, bandwidth: 1.1, filterType: .highShelf)
                ],
                roomSize: 0.4
            ),
            Preset(
                id: "focus",
                label: "Focus",
                description: "Dry and neutral. Stays out of the way.",
                reverbPreset: .smallRoom,
                reverbBlend: 0.08,
                eqBands: [
                    EQBand(frequency: 120, gain: -1.0, bandwidth: 1.0, filterType: .lowShelf),
                    EQBand(frequency: 1_500, gain: 1.0, bandwidth: 1.2),
                    EQBand(frequency: 6_000, gain: 0.5, bandwidth: 1.0, filterType: .highShelf)
                ],
                roomSize: 0.2
            ),
            Preset(
                id: "running",
                label: "Running",
                description: "Punchy and forward to push the pace.",
                reverbPreset: .mediumRoom,
                reverbBlend: 0.14,
                eqBands: [
                    EQBand(frequency: 65, gain: 3.5, bandwidth: 1.1, filterType: .lowShelf),
                    EQBand(frequency: 900, gain: 1.5, bandwidth: 1.0),
                    EQBand(frequency: 3_000, gain: 2.5, bandwidth: 1.0),
                    EQBand(frequency: 9_000, gain: 2.0, bandwidth: 1.1, filterType: .highShelf)
                ],
                roomSize: 0.3
            )
        ]
    }
}
