import Foundation
import MediaPlayer

/// Bridges the binaural player to the system: lock-screen / Control Center
/// transport controls and Now Playing metadata, so the user can pause without
/// unlocking (essential for a sleep app).
@MainActor
final class NowPlayingController {

    var onToggle: (@MainActor () -> Void)?
    var onPlay: (@MainActor () -> Void)?
    var onPause: (@MainActor () -> Void)?

    init() { configureCommands() }

    private func configureCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onToggle?() }
            return .success
        }
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }
        // Continuous ambience has no track list or timeline.
        [center.nextTrackCommand, center.previousTrackCommand,
         center.seekForwardCommand, center.seekBackwardCommand,
         center.skipForwardCommand, center.skipBackwardCommand,
         center.changePlaybackPositionCommand].forEach { $0.isEnabled = false }
    }

    /// Publishes the current state to the lock screen / Control Center.
    func update(title: String, subtitle: String, isPlaying: Bool) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
