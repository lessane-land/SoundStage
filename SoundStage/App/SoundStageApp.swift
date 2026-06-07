import SwiftUI

/// App entry point.
///
/// Owns the shared `PresetStore` and the player view model, injects the store
/// into the environment and locks the UI to the dark, spatial look.
@main
struct SoundStageApp: App {
    @State private var presetStore: PresetStore
    @State private var nowPlaying: NowPlayingViewModel
    @State private var appleMusic: AppleMusicService
    @State private var artworkLoader = ArtworkLoader()

    init() {
        let store = PresetStore()
        let music = AppleMusicService()
        _presetStore = State(initialValue: store)
        _appleMusic = State(initialValue: music)
        _nowPlaying = State(initialValue: NowPlayingViewModel(presetStore: store, appleMusic: music))
    }

    var body: some Scene {
        WindowGroup {
            NowPlayingView(viewModel: nowPlaying)
                .environment(presetStore)
                .environment(appleMusic)
                .environment(artworkLoader)
                .preferredColorScheme(.dark)
        }
    }
}
