import MediaPlayer
import UIKit

/// Loads and caches album artwork for tracks.
///
/// `MPMediaItemArtwork` only lives on a live `MPMediaItem`, so on first request
/// we index the library once by persistent id, then resolve artwork from that
/// index and cache rendered `UIImage`s by id. `@MainActor` because MediaPlayer
/// is main-thread oriented; `UIKit` is used only because artwork is delivered
/// as `UIImage`.
@MainActor
@Observable
final class ArtworkLoader {

    @ObservationIgnored private var itemsByID: [UInt64: MPMediaItem] = [:]
    @ObservationIgnored private var indexed = false
    @ObservationIgnored private let cache = NSCache<NSNumber, UIImage>()

    /// Returns artwork for a track at (approximately) the requested size, or
    /// `nil` if the track has none.
    func image(for track: Track, size: CGSize) async -> UIImage? {
        guard let id = track.artworkID else { return nil }

        let key = NSNumber(value: id)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        indexIfNeeded()
        guard let artwork = itemsByID[id]?.artwork,
              let image = artwork.image(at: size) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private func indexIfNeeded() {
        guard !indexed else { return }
        indexed = true
        let query = MPMediaQuery.songs()
        for item in query.items ?? [] {
            itemsByID[item.persistentID] = item
        }
    }
}
