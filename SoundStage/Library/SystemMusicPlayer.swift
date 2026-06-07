import Foundation
import MediaPlayer

/// Plays library items that the effects engine can't decode — Apple Music,
/// protected, and cloud songs — through Apple's system player
/// (`MPMusicPlayerController.applicationMusicPlayer`). This is the same player
/// the Music app uses, so it handles the user's full library/subscription. The
/// audio bypasses `AudioEngine`, so the spatial presets don't process it.
@MainActor
@Observable
final class SystemMusicPlayer {

    @ObservationIgnored private let player = MPMusicPlayerController.applicationMusicPlayer

    private(set) var isPlaying = false

    var elapsed: TimeInterval { player.currentPlaybackTime }
    var duration: TimeInterval { player.nowPlayingItem?.playbackDuration ?? 0 }
    var nowPlayingID: UInt64? { player.nowPlayingItem?.persistentID }

    /// Plays `playbackID` within a queue of library items.
    func play(playbackID: UInt64, queueIDs: [UInt64]) {
        let items = Self.items(for: queueIDs)
        guard !items.isEmpty else { return }

        player.setQueue(with: MPMediaItemCollection(items: items))
        if let start = items.first(where: { $0.persistentID == playbackID }) {
            player.nowPlayingItem = start
        }
        player.prepareToPlay()
        player.play()
        isPlaying = true
    }

    /// Plays an Apple Music catalog song (by store id) within a queue.
    func playCatalog(storeID: String, queueStoreIDs: [String]) {
        let ids = queueStoreIDs.isEmpty ? [storeID] : queueStoreIDs
        let descriptor = MPMusicPlayerStoreQueueDescriptor(storeIDs: ids)
        descriptor.startItemID = storeID
        player.setQueue(with: descriptor)
        player.prepareToPlay()
        player.play()
        isPlaying = true
    }

    func togglePlayback() {
        if player.playbackState == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func next() {
        player.skipToNextItem()
    }

    func previous() {
        if player.currentPlaybackTime > 3 {
            player.skipToBeginning()
        } else {
            player.skipToPreviousItem()
        }
    }

    func seek(to time: TimeInterval) {
        player.currentPlaybackTime = max(0, time)
    }

    /// Refreshes `isPlaying` from the system player (called by the ticker).
    func refreshState() {
        isPlaying = player.playbackState == .playing
    }

    /// Resolves persistent ids to `MPMediaItem`s from the songs library.
    private static func items(for ids: [UInt64]) -> [MPMediaItem] {
        let all = MPMediaQuery.songs().items ?? []
        let byID = Dictionary(all.map { ($0.persistentID, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }
}
