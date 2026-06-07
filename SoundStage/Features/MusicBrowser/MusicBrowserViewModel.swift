import Foundation
import Observation

/// Drives the online music search/browse sheet across DRM-free sources whose
/// audio the spatial engine can process.
@MainActor
@Observable
final class MusicBrowserViewModel {

    enum State: Equatable {
        case idle
        case searching
        case results
        case empty
        case error(String)
    }

    /// Paste a free Jamendo client id (https://devportal.jamendo.com) to enable
    /// the Jamendo source. Internet Archive needs no key.
    static let jamendoClientID = "YOUR_JAMENDO_CLIENT_ID"

    var source: MusicSource = .deezer {
        didSet { if oldValue != source { onSourceChanged() } }
    }
    var query: String = ""
    private(set) var state: State = .idle
    private(set) var results: [Track] = []

    /// Hands the chosen (URL-resolved) track plus queue back to the player.
    var onPlay: ((Track, [Track]) -> Void)?

    private let deezer = DeezerProvider()
    private let archive = InternetArchiveProvider()
    private let jamendo = JamendoProvider(clientID: MusicBrowserViewModel.jamendoClientID)
    private var searchTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?

    var jamendoAvailable: Bool { jamendo.isConfigured }

    private var provider: OnlineMusicProvider {
        switch source {
        case .deezer: return deezer
        case .internetArchive: return archive
        case .jamendo: return jamendo
        }
    }

    /// Runs a (debounced) search for the current query.
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard !trimmed.isEmpty else {
            results = []
            state = .idle
            return
        }
        if source == .jamendo, !jamendo.isConfigured {
            results = []
            state = .error("Add a free Jamendo client id in MusicBrowserViewModel to use this source.")
            return
        }

        state = .searching
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            do {
                let found = try await self.provider.search(trimmed)
                if Task.isCancelled { return }
                self.results = found
                self.state = found.isEmpty ? .empty : .results
            } catch {
                if Task.isCancelled { return }
                self.state = .error("Couldn't reach \(self.source.title). Check your connection.")
            }
        }
    }

    /// Resolves the stream URL (if needed) and starts playback.
    func play(_ track: Track) {
        playTask?.cancel()
        playTask = Task { [weak self] in
            guard let self else { return }
            if track.assetURL != nil {
                self.onPlay?(track, self.results)
                return
            }
            let url = try? await self.provider.resolveStreamURL(for: track)
            guard let url, !Task.isCancelled else { return }
            let resolved = track.resolving(assetURL: url)
            self.onPlay?(resolved, [resolved])
        }
    }

    private func onSourceChanged() {
        results = []
        state = .idle
        search()
    }
}
