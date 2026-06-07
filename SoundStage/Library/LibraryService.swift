import Foundation
import MediaPlayer

/// Library authorization state, decoupled from MediaPlayer's enum.
enum LibraryAuthorization {
    case authorized
    case denied
    case restricted
    case notDetermined
}

/// Abstraction over the music library so view models can be tested against a
/// mock. `@MainActor` because the concrete backing (`MPMediaQuery`) is
/// main-thread oriented.
@MainActor
protocol LibraryProviding {
    var authorizationStatus: LibraryAuthorization { get }
    func requestAuthorization() async -> LibraryAuthorization
    func fetchSongs() async -> [Track]
}

/// Reads tracks and metadata from the user's local music library.
///
/// Phase 1 backs onto `MPMediaLibrary` / `MPMediaQuery`. Authorization and
/// fetching are exposed as `async` APIs.
@MainActor
final class LibraryService: LibraryProviding {

    /// Current authorization state without prompting.
    var authorizationStatus: LibraryAuthorization {
        Self.map(MPMediaLibrary.authorizationStatus())
    }

    /// Prompts for library access if not yet determined.
    func requestAuthorization() async -> LibraryAuthorization {
        let raw = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return Self.map(raw)
    }

    /// Fetches songs that have a local asset (so they can be decoded and played
    /// through the engine), mapped to `Track` values. Cloud-only items without
    /// an `assetURL` are skipped.
    func fetchSongs() async -> [Track] {
        let query = MPMediaQuery.songs()
        guard let items = query.items else { return [] }
        return items.compactMap { item in
            guard item.assetURL != nil else { return nil }
            return Self.track(from: item)
        }
    }

    // MARK: - Mapping

    private static func track(from item: MPMediaItem) -> Track {
        Track(
            id: String(item.persistentID),
            title: item.title ?? "Unknown Title",
            artist: item.artist ?? "Unknown Artist",
            albumTitle: item.albumTitle ?? "",
            duration: item.playbackDuration,
            assetURL: item.assetURL,
            artworkID: item.artwork != nil ? item.persistentID : nil
        )
    }

    private static func map(_ status: MPMediaLibraryAuthorizationStatus) -> LibraryAuthorization {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}
