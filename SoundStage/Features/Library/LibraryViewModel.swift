import Foundation
import Observation

/// Drives the library browser. Loads songs from the local media library; each
/// track is tagged `.local` (effects engine) or `.appleMusic` (system player),
/// and all are playable. Owns the authorization/fetch state machine and
/// in-memory search filtering.
@MainActor
@Observable
final class LibraryViewModel {

    enum State: Equatable {
        case idle
        case requestingAccess
        case accessDenied
        case loading
        case loaded
        case empty
    }

    private(set) var state: State = .idle
    private(set) var tracks: [Track] = []
    var searchText = ""

    private let service: LibraryProviding

    init(service: LibraryProviding = LibraryService()) {
        self.service = service
    }

    /// The currently visible, playable tracks — used to seed the play queue.
    var playableTracks: [Track] {
        visibleTracks.filter(\.isPlayable)
    }

    /// Tracks filtered by the current search text (title or artist).
    var visibleTracks: [Track] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    func loadIfNeeded() async {
        guard state == .idle || state == .accessDenied else { return }
        switch service.authorizationStatus {
        case .authorized:
            await load()
        case .denied, .restricted:
            // Still surface the bundled demo so the engine can be tried.
            tracks = demoTracks
            state = tracks.isEmpty ? .accessDenied : .loaded
        case .notDetermined:
            state = .requestingAccess
            if await service.requestAuthorization() == .authorized {
                await load()
            } else {
                tracks = demoTracks
                state = tracks.isEmpty ? .accessDenied : .loaded
            }
        }
    }

    func reload() async {
        state = .idle
        tracks = []
        await loadIfNeeded()
    }

    private func load() async {
        state = .loading
        let fetched = await service.fetchSongs()
        tracks = demoTracks + fetched
        state = tracks.isEmpty ? .empty : .loaded
    }

    /// The bundled demo, pinned to the top when present.
    private var demoTracks: [Track] {
        Track.demo.map { [$0] } ?? []
    }
}
