import SwiftUI

/// App entry point. SoundStage now opens on the binaural-beats generator —
/// pure synthesis, so it works with no DRM, files, or network.
@main
struct SoundStageApp: App {
    @State private var binaural = BinauralViewModel()

    var body: some Scene {
        WindowGroup {
            BinauralView(viewModel: binaural)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Home Screen widget → soundstage://play
                    if url.host == "play" { binaural.setPlaying(true) }
                }
        }
    }
}
