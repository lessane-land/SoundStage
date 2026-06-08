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
    /// `fromHex`/`toHex` are the current state's gradient so the artwork orb
    /// is tinted to match the in-app player and Live Activity.
    func update(title: String, subtitle: String, fromHex: UInt32, toHex: UInt32, isPlaying: Bool) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPMediaItemPropertyArtwork: artwork(fromHex: fromHex, toHex: toHex),
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Artwork

    /// Gradient orbs are static per state, so cache one per color pair.
    private var artworkCache: [UInt64: MPMediaItemArtwork] = [:]

    private func artwork(fromHex: UInt32, toHex: UInt32) -> MPMediaItemArtwork {
        let key = UInt64(fromHex) << 32 | UInt64(toHex)
        if let cached = artworkCache[key] { return cached }
        let size = CGSize(width: 512, height: 512)
        let image = Self.renderOrb(size: size, fromHex: fromHex, toHex: toHex)
        let art = MPMediaItemArtwork(boundsSize: size) { _ in image }
        artworkCache[key] = art
        return art
    }

    /// The stage-colored gradient ball on near-black, with a top-left highlight
    /// and a soft glow — the lock-screen twin of the in-app orb.
    private static func renderOrb(size: CGSize, fromHex: UInt32, toHex: UInt32) -> UIImage {
        let bg = uiColor(0x0A0A0F)
        let fromC = uiColor(fromHex), toC = uiColor(toHex)
        let r = size.width * 0.34
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
        let space = CGColorSpaceCreateDeviceRGB()
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            bg.setFill()
            c.fill(CGRect(origin: .zero, size: size))

            // Soft glow behind the orb, in the end color.
            c.saveGState()
            c.setShadow(offset: .zero, blur: size.width * 0.11, color: toC.withAlphaComponent(0.75).cgColor)
            toC.setFill()
            c.fillEllipse(in: rect)
            c.restoreGState()

            // Diagonal body gradient (top-leading -> bottom-trailing).
            c.saveGState()
            c.addEllipse(in: rect); c.clip()
            if let grad = CGGradient(colorsSpace: space, colors: [fromC.cgColor, toC.cgColor] as CFArray, locations: [0, 1]) {
                c.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.minY),
                                     end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
            }
            // Top-left specular highlight.
            let hc = CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.30)
            if let hl = CGGradient(colorsSpace: space,
                                   colors: [UIColor.white.withAlphaComponent(0.55).cgColor, UIColor.clear.cgColor] as CFArray,
                                   locations: [0, 1]) {
                c.drawRadialGradient(hl, startCenter: hc, startRadius: 0, endCenter: hc, endRadius: r * 1.1, options: [])
            }
            c.restoreGState()
        }
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
