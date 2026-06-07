import Foundation
import MusicKit

/// Apple Music integration: authorization, browsing the user's library, and
/// playback via `ApplicationMusicPlayer`.
///
/// Apple's DRM means the audio is played by the system player and **cannot** be
/// routed through `AudioEngine`, so the spatial presets don't process Apple
/// Music tracks — they're a visual theme only. `@MainActor` because MusicKit is
/// main-actor friendly and this backs SwiftUI state.
@MainActor
@Observable
final class AppleMusicService {

    enum Authorization {
        case authorized
        case denied
        case restricted
        case notDetermined
    }

    @ObservationIgnored private let player = ApplicationMusicPlayer.shared
    /// Cache of fetched songs by id, so playback can build a queue from ids.
    @ObservationIgnored private var songsByID: [String: Song] = [:]

    /// Reflected playback state for the player UI.
    private(set) var isPlaying = false
    private(set) var nowPlayingID: String?
    private(set) var duration: TimeInterval = 0

    /// Live playback position (polled by the player's ticker).
    var elapsed: TimeInterval { player.playbackTime }

    // MARK: - Authorization

    var authorizationStatus: Authorization {
        Self.map(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> Authorization {
        Self.map(await MusicAuthorization.request())
    }

    // MARK: - Library

    /// Loads the user's Apple Music library songs.
    func libraryTracks() async throws -> [Track] {
        let request = MusicLibraryRequest<Song>()
        let response = try await request.response()
        songsByID = Dictionary(
            response.items.map { ($0.id.rawValue, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return response.items.map(Self.track(from:))
    }

    // MARK: - Playback

    /// Plays `trackID` within the queue described by `queueIDs`.
    func play(trackID: String, queueIDs: [String]) async {
        let songs = queueIDs.compactMap { songsByID[$0] }
        guard let start = songsByID[trackID], !songs.isEmpty else { return }

        player.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: start)
        nowPlayingID = trackID
        duration = start.duration ?? 0
        do {
            try await player.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func togglePlayback() async {
        if player.state.playbackStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            do {
                try await player.play()
                isPlaying = true
            } catch {
                isPlaying = false
            }
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func next() async {
        try? await player.skipToNextEntry()
        syncCurrentEntry()
    }

    func previous() async {
        if player.playbackTime > 3 {
            player.playbackTime = 0
        } else {
            try? await player.skipToPreviousEntry()
            syncCurrentEntry()
        }
    }

    func seek(to time: TimeInterval) {
        player.playbackTime = max(0, time)
    }

    /// Refreshes `isPlaying` from the system player (called by the ticker).
    func refreshState() {
        isPlaying = player.state.playbackStatus == .playing
    }

    /// Updates `nowPlayingID`/`duration` from the current queue entry.
    private func syncCurrentEntry() {
        guard let id = player.queue.currentEntry?.item?.id.rawValue else { return }
        nowPlayingID = id
        if let song = songsByID[id] {
            duration = song.duration ?? 0
        }
    }

    // MARK: - Mapping

    private static func track(from song: Song) -> Track {
        Track(
            id: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            albumTitle: song.albumTitle ?? "",
            duration: song.duration ?? 0,
            assetURL: nil,
            artworkID: nil,
            isPlayable: true,
            origin: .appleMusic,
            appleMusicID: song.id.rawValue,
            artworkURL: song.artwork?.url(width: 600, height: 600)
        )
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
