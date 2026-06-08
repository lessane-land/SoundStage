import Foundation
import MediaPlayer
import UIKit

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
            MPMediaItemPropertyArtwork: artwork,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Artwork

    /// Glowing purple orb on the near-black background, matching the in-app
    /// player and Live Activity. Built once and reused.
    private lazy var artwork: MPMediaItemArtwork = {
        let size = CGSize(width: 512, height: 512)
        let image = Self.renderOrb(size: size)
        return MPMediaItemArtwork(boundsSize: size) { _ in image }
    }()

    private static func renderOrb(size: CGSize) -> UIImage {
        let accent = UIColor(red: 0x6C / 255, green: 0x5C / 255, blue: 0xE7 / 255, alpha: 1)
        let bg = UIColor(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0F / 255, alpha: 1)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            bg.setFill()
            c.fill(CGRect(origin: .zero, size: size))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let colors = [accent.withAlphaComponent(0.95).cgColor,
                          accent.withAlphaComponent(0.35).cgColor,
                          accent.withAlphaComponent(0.0).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 0.55, 1]) {
                c.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                     endCenter: center, endRadius: size.width * 0.42,
                                     options: [])
            }
        }
    }
}
