import Foundation

/// A playable item from the user's local music library.
///
/// A plain `Sendable` value derived from `MPMediaItem`. `assetURL` is the
/// local asset the audio engine reads; it can be `nil` for items with no
/// local asset (e.g. cloud-only tracks not downloaded), which the engine
/// treats as unplayable.
struct Track: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let albumTitle: String
    let duration: TimeInterval
    let assetURL: URL?

    /// Library persistent id used to look up artwork on demand. Stored as a
    /// plain `UInt64` so `Track` stays free of MediaPlayer types and `Sendable`.
    let artworkID: UInt64?

    /// `mm:ss` formatted duration for display.
    var formattedDuration: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension Track {
    /// Placeholder shown before a library track is loaded.
    static let placeholder = Track(
        id: "placeholder",
        title: "Nothing playing",
        artist: "Pick a track from your library",
        albumTitle: "",
        duration: 0,
        assetURL: nil,
        artworkID: nil
    )
}
