import Foundation
import Observation

/// Drives the preset picker.
///
/// Reads the catalog from `PresetStore`, tracks the active selection and
/// commits a chosen (possibly tweaked) preset back through the store, which
/// persists it. Applying to the audio graph is surfaced via `onApply` so this
/// view model stays UI-only.
@MainActor
@Observable
final class PresetSelectorViewModel {

    let presets: [Preset]
    private(set) var selectedID: Preset.ID

    private let store: PresetStore

    /// Invoked when the user enters a space, so the owner can apply it to audio.
    var onApply: ((Preset) -> Void)?
    /// Live preview while dragging the detail sliders (reverb/EQ only).
    var onPreview: ((Preset) -> Void)?
    /// Revert a live preview (detail closed without entering).
    var onCancelPreview: (() -> Void)?

    init(
        store: PresetStore,
        onApply: ((Preset) -> Void)? = nil,
        onPreview: ((Preset) -> Void)? = nil,
        onCancelPreview: (() -> Void)? = nil
    ) {
        self.store = store
        self.presets = store.presets
        self.selectedID = store.selectedPresetID
        self.onApply = onApply
        self.onPreview = onPreview
        self.onCancelPreview = onCancelPreview
    }

    func isSelected(_ preset: Preset) -> Bool {
        preset.id == selectedID
    }

    /// Commits a preset (with any detail-sheet tweaks) as the active space.
    func activate(_ preset: Preset) {
        selectedID = preset.id
        store.select(preset)
        onApply?(preset)
    }
}
