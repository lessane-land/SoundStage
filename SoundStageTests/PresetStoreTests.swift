import XCTest
@testable import SoundStage

@MainActor
final class PresetStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testShipsSixPresets() {
        let store = PresetStore(defaults: defaults)
        XCTAssertEqual(store.presets.count, 6)
    }

    func testPresetIDsAreUnique() {
        let store = PresetStore(defaults: defaults)
        let ids = Set(store.presets.map(\.id))
        XCTAssertEqual(ids.count, store.presets.count)
    }

    func testDefaultsToFirstPreset() {
        let store = PresetStore(defaults: defaults)
        XCTAssertEqual(store.selectedPresetID, store.presets[0].id)
        XCTAssertEqual(store.selectedPreset.id, store.presets[0].id)
    }

    func testSelectionPersistsAcrossInstances() {
        let store = PresetStore(defaults: defaults)
        let target = store.presets[3]

        store.select(target)
        XCTAssertEqual(store.selectedPresetID, target.id)

        let reloaded = PresetStore(defaults: defaults)
        XCTAssertEqual(reloaded.selectedPresetID, target.id)
        XCTAssertEqual(reloaded.selectedPreset.id, target.id)
    }

    func testInvalidPersistedSelectionFallsBackToFirst() {
        defaults.set("does-not-exist", forKey: "soundstage.selectedPresetID")
        let store = PresetStore(defaults: defaults)
        XCTAssertEqual(store.selectedPresetID, store.presets[0].id)
    }
}
