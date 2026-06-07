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
    /// The asset the engine decodes. Local file URL, or a remote DRM-free MP3
    /// (Internet Archive / Jamendo) — `AVAssetReader` streams both. May be
    /// resolved lazily for online results.
    var assetURL: URL?

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

    /// Returns a copy with the asset URL resolved (for online results).
    func resolving(assetURL url: URL?) -> Track {
        var copy = self
        copy.assetURL = url
        return copy
    }

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

    /// A bundled, local demo track so the spatial engine can always be heard,
    /// regardless of what's in (or streaming into) the user's library.
    static var demo: Track? {
        guard let url = Bundle.main.url(forResource: "demo", withExtension: "wav") else { return nil }
        return Track(
            id: "soundstage-demo",
            title: "SoundStage Demo",
            artist: "Spatial test - drag the sliders",
            albumTitle: "",
            duration: 0,
            assetURL: url,
            artworkID: nil,
            isPlayable: true,
            origin: .local
        )
    }
}
