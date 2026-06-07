import Foundation

/// Where a track comes from, which decides how it's played.
enum TrackOrigin: Equatable, Sendable {
    /// Local, non-DRM file streamed through `AudioEngine` (spatial presets apply).
    case local
    /// Protected / Apple Music / cloud library item played by the system player
    /// (`MPMusicPlayerController`); Apple's DRM means the presets can't process it.
    case appleMusic
}

/// A playable item, either a local library asset or an Apple Music song.
///
/// A plain `Sendable` value. For `.local` tracks `assetURL` is the file the
/// audio engine decodes; for `.appleMusic` tracks `playbackID` is the
/// media-library id the system player uses.
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

    /// Whether the track can be played at all (false only for the placeholder /
    /// items with no usable asset on any player).
    let isPlayable: Bool

    /// Where the track comes from / how it's played.
    var origin: TrackOrigin = .local

    /// Media-library persistent id used by the system player (`.appleMusic`).
    var playbackID: UInt64? = nil

    /// Remote artwork URL, loaded by `ArtworkView` when present.
    var artworkURL: URL? = nil

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
        artworkID: nil,
        isPlayable: false
    )
}
