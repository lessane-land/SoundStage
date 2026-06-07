import Foundation
import Observation

/// Drives the library browser.
///
/// Owns authorization + fetch via `LibraryService` and exposes a small state
/// machine the view renders directly. Search filtering happens in-memory over
/// the loaded tracks. `@MainActor` because it backs SwiftUI state.
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

    /// The currently visible, playable tracks — used to seed the play queue so
    /// prev/next never lands on a protected/cloud item.
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

    /// Requests access if needed, then loads songs. Safe to call on every appear;
    /// it no-ops once tracks are already loaded.
    func loadIfNeeded() async {
        guard state == .idle || state == .accessDenied else { return }

        switch service.authorizationStatus {
        case .authorized:
            await load()
        case .denied, .restricted:
            state = .accessDenied
        case .notDetermined:
            state = .requestingAccess
            let result = await service.requestAuthorization()
            if result == .authorized {
                await load()
            } else {
                state = .accessDenied
            }
        }
    }

    /// Forces a reload (e.g. pull-to-refresh).
    func reload() async {
        guard service.authorizationStatus == .authorized else {
            await loadIfNeeded()
            return
        }
        await load()
    }

    private func load() async {
        state = .loading
        let fetched = await service.fetchSongs()
        tracks = fetched
        state = fetched.isEmpty ? .empty : .loaded
    }
}
