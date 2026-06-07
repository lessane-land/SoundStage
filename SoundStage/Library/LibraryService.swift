import Foundation
import MediaPlayer

/// Reads tracks and metadata from the user's local music library.
///
/// Phase 1 backs onto `MPMediaLibrary` / `MPMediaQuery`. Authorization and
/// fetching are exposed as `async` APIs. `@MainActor` because `MPMediaQuery`
/// and authorization callbacks are main-thread oriented and results feed view
/// state directly.
@MainActor
final class LibraryService {

    enum Authorization {
        case authorized
        case denied
        case restricted
        case notDetermined
    }

    /// Current authorization state without prompting.
    var authorizationStatus: Authorization {
        Self.map(MPMediaLibrary.authorizationStatus())
    }

    /// Prompts for library access if not yet determined.
    func requestAuthorization() async -> Authorization {
        let raw = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return Self.map(raw)
    }

    /// Fetches all songs in the library, mapped to `Track` values.
    func fetchSongs() async -> [Track] {
        let query = MPMediaQuery.songs()
        guard let items = query.items else { return [] }
        return items.map(Self.track(from:))
    }

    // MARK: - Mapping

    private static func track(from item: MPMediaItem) -> Track {
        Track(
            id: String(item.persistentID),
            title: item.title ?? "Unknown Title",
            artist: item.artist ?? "Unknown Artist",
            albumTitle: item.albumTitle ?? "",
            duration: item.playbackDuration,
            assetURL: item.assetURL
        )
    }

    private static func map(_ status: MPMediaLibraryAuthorizationStatus) -> Authorization {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}
