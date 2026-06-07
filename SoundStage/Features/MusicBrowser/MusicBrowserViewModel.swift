import Foundation
import Observation

/// Drives the music search/browse sheet. One clean source (Deezer): a popular
/// browse list before you type, live search after. Results are 30s DRM-free
/// previews that play through the 16D engine.
@MainActor
@Observable
final class MusicBrowserViewModel {

    enum State: Equatable {
        case loading
        case browse
        case results
        case empty
        case error(String)
    }

    var query: String = ""
    private(set) var state: State = .loading
    private(set) var browse: [Track] = []
    private(set) var results: [Track] = []

    /// Hands the chosen track plus its list back to the player.
    var onPlay: ((Track, [Track]) -> Void)?

    private let deezer = DeezerProvider()
    private var searchTask: Task<Void, Never>?

    /// What the list currently shows.
    var displayed: [Track] {
        isSearching ? results : browse
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Loads the popular browse list (called once on appear).
    func loadBrowseIfNeeded() async {
        guard browse.isEmpty else { return }
        state = .loading
        do {
            browse = try await deezer.chart()
            state = browse.isEmpty ? .empty : .browse
        } catch {
            state = .error("Couldn't reach Deezer. Check your connection.")
        }
    }

    /// Debounced live search on the current query.
    func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            state = browse.isEmpty ? .loading : .browse
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            do {
                let found = try await self.deezer.search(trimmed)
                if Task.isCancelled { return }
                self.results = found
                self.state = found.isEmpty ? .empty : .results
            } catch {
                if Task.isCancelled { return }
                self.state = .error("Couldn't reach Deezer. Check your connection.")
            }
        }
    }

    func play(_ track: Track) {
        onPlay?(track, displayed)
    }
}
