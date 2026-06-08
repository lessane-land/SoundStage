import SwiftUI

/// App entry point. SoundStage opens on the binaural-beats generator — pure
/// synthesis plus bundled soundscapes, so it works with no DRM or network.
@main
struct SoundStageApp: App {
    @State private var binaural = BinauralViewModel.shared

    var body: some Scene {
        WindowGroup {
            BinauralView(viewModel: binaural)
                .preferredColorScheme(.dark)
                .onOpenURL { handle($0) }
        }
    }

    /// Deep links from widgets / Siri: soundstage://play, soundstage://state/<id>.
    private func handle(_ url: URL) {
        switch url.host {
        case "play":
            binaural.setPlaying(true)
        case "state":
            let id = url.lastPathComponent
            if let state = binaural.states.first(where: { $0.id == id }) {
                binaural.select(state)
            }
            binaural.setPlaying(true)
        default:
            break
        }
    }
}
