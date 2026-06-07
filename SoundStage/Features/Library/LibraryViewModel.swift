import Foundation
import Observation

/// Drives the library browser across two sources: local files (played with
/// spatial presets) and Apple Music (played via the system player). Owns the
/// authorization + fetch state machine and in-memory search filtering.
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

    enum Source: String, CaseIterable, Identifiable {
        case onDevice = "On Device"
        case appleMusic = "Apple Music"
        var id: String { rawValue }
    }

    private(set) var state: State = .idle
    private(set) var tracks: [Track] = []
    var searchText = ""

    var source: Source = .onDevice {
        didSet { if oldValue != source { reloadForSourceChange() } }
    }

    private let localService: LibraryProviding
    private let appleMusic: AppleMusicService?

    init(service: LibraryProviding = LibraryService(), appleMusic: AppleMusicService? = nil) {
        self.localService = service
        self.appleMusic = appleMusic
    }

    /// Whether the Apple Music source is available to switch to.
    var hasAppleMusic: Bool { appleMusic != nil }

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
        switch source {
        case .onDevice: await loadLocal()
        case .appleMusic: await loadAppleMusic()
        }
    }

    func reload() async {
        state = .idle
        tracks = []
        await loadIfNeeded()
    }

    private func reloadForSourceChange() {
        state = .idle
        tracks = []
        searchText = ""
        Task { await loadIfNeeded() }
    }

    // MARK: - Local

    private func loadLocal() async {
        switch localService.authorizationStatus {
        case .authorized:
            await fetchLocal()
        case .denied, .restricted:
            state = .accessDenied
        case .notDetermined:
            state = .requestingAccess
            if await localService.requestAuthorization() == .authorized {
                await fetchLocal()
            } else {
                state = .accessDenied
            }
        }
    }

    private func fetchLocal() async {
        state = .loading
        let fetched = await localService.fetchSongs()
        tracks = fetched
        state = fetched.isEmpty ? .empty : .loaded
    }

    // MARK: - Apple Music

    private func loadAppleMusic() async {
        guard let appleMusic else { state = .accessDenied; return }
        switch appleMusic.authorizationStatus {
        case .authorized:
            await fetchAppleMusic()
        case .denied, .restricted:
            state = .accessDenied
        case .notDetermined:
            state = .requestingAccess
            if await appleMusic.requestAuthorization() == .authorized {
                await fetchAppleMusic()
            } else {
                state = .accessDenied
            }
        }
    }

    private func fetchAppleMusic() async {
        guard let appleMusic else { state = .accessDenied; return }
        state = .loading
        do {
            let fetched = try await appleMusic.libraryTracks()
            tracks = fetched
            state = fetched.isEmpty ? .empty : .loaded
        } catch {
            state = .empty
        }
    }
}
