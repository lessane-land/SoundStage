import Foundation
import Observation

/// Drives the music search sheet across three sources:
/// Apple Music (full songs, no 16D), Jamendo and Internet Archive (full
/// DRM-free tracks the 16D engine can process).
@MainActor
@Observable
final class MusicBrowserViewModel {

    enum Source: String, CaseIterable, Identifiable {
        case appleMusic = "Apple Music"
        case archive = "Archive"
        var id: String { rawValue }
    }

    enum State: Equatable {
        case idle
        case searching
        case results
        case empty
        case error(String)
    }

    private enum SearchError: Error { case unauthorized }

    var source: Source = .appleMusic {
        didSet { if oldValue != source { onSourceChanged() } }
    }
    var query: String = ""
    private(set) var state: State = .idle
    private(set) var results: [Track] = []

    var onPlay: ((Track, [Track]) -> Void)?

    private let appleMusic = AppleMusicCatalog()
    private let archive = InternetArchiveProvider()
    private var searchTask: Task<Void, Never>?

    var sourceNote: String {
        switch source {
        case .appleMusic: return "Full songs — plays, but no 16D (Apple DRM)."
        case .archive: return "Music, full length — 16D works on these."
        }
    }

    func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            state = .idle
            return
        }

        state = .searching
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            do {
                let found = try await self.runSearch(trimmed)
                if Task.isCancelled { return }
                self.results = found
                self.state = found.isEmpty ? .empty : .results
            } catch is SearchError {
                self.state = .error("Allow Apple Music access in Settings to search the catalog.")
            } catch {
                self.state = .error(self.source == .appleMusic
                    ? "Apple Music: \(error.localizedDescription)"
                    : "Couldn't reach \(self.source.rawValue). Check your connection.")
            }
        }
    }

    private func runSearch(_ query: String) async throws -> [Track] {
        switch source {
        case .appleMusic:
            if appleMusic.authorizationStatus != .authorized {
                guard await appleMusic.requestAuthorization() == .authorized else {
                    throw SearchError.unauthorized
                }
            }
            return try await appleMusic.search(query)
        case .archive:
            return try await archive.search(query)
        }
    }

    func play(_ track: Track) {
        onPlay?(track, results)
    }

    private func onSourceChanged() {
        results = []
        state = .idle
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            search()
        }
    }
}
