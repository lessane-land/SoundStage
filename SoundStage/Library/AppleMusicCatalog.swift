import Foundation
import MusicKit

/// Searches the Apple Music **catalog** (full songs). Results play through the
/// system player; Apple's DRM means the spatial effects don't apply to them.
@MainActor
@Observable
final class AppleMusicCatalog {

    enum Authorization {
        case authorized
        case denied
        case restricted
        case notDetermined
    }

    var authorizationStatus: Authorization {
        Self.map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> Authorization {
        Self.map(await MusicAuthorization.request())
    }

    func search(_ query: String) async throws -> [Track] {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 25
        let response = try await request.response()
        return response.songs.map { song in
            Track(
                id: "applemusic:\(song.id.rawValue)",
                title: song.title,
                artist: song.artistName,
                albumTitle: song.albumTitle ?? "",
                duration: song.duration ?? 0,
                assetURL: nil,
                artworkID: nil,
                isPlayable: true,
                origin: .appleMusic,
                catalogID: song.id.rawValue,
                artworkURL: song.artwork?.url(width: 200, height: 200)
            )
        }
    }

    private static func map(_ status: MusicAuthorization.Status) -> Authorization {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}
