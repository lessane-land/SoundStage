import Foundation
import Observation

/// Drives the preset picker screen.
///
/// Reads the catalog from `PresetStore`, tracks the highlighted selection and
/// writes the choice back through the store (which persists it). Applying the
/// preset to the audio graph is the player's responsibility, surfaced here via
/// the `onApply` callback so this view model stays UI-only.
@MainActor
@Observable
final class PresetSelectorViewModel {

    let presets: [Preset]
    private(set) var selectedID: Preset.ID

    private let store: PresetStore

    /// Invoked when the user commits a preset, so the owner can apply it to audio.
    var onApply: ((Preset) -> Void)?

    init(store: PresetStore, onApply: ((Preset) -> Void)? = nil) {
        self.store = store
        self.presets = store.presets
        self.selectedID = store.selectedPresetID
        self.onApply = onApply
    }

    func isSelected(_ preset: Preset) -> Bool {
        preset.id == selectedID
    }

    func select(_ preset: Preset) {
        selectedID = preset.id
        store.select(preset)
        onApply?(preset)
    }
}
