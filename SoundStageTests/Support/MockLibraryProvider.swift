import Foundation
@testable import SoundStage

/// In-memory `LibraryProviding` for tests. `requestAuthorization()` flips the
/// reported status to `requestResult`, mirroring a user responding to the prompt.
@MainActor
final class MockLibraryProvider: LibraryProviding {

    var status: LibraryAuthorization
    var songs: [Track]
    var requestResult: LibraryAuthorization

    init(
        status: LibraryAuthorization,
        songs: [Track],
        requestResult: LibraryAuthorization = .authorized
    ) {
        self.status = status
        self.songs = songs
        self.requestResult = requestResult
    }

    var authorizationStatus: LibraryAuthorization { status }

    func requestAuthorization() async -> LibraryAuthorization {
        status = requestResult
        return requestResult
    }

    func fetchSongs() async -> [Track] { songs }
}

extension Track {
    static func stub(
        id: String,
        title: String = "Title",
        artist: String = "Artist"
    ) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            albumTitle: "Album",
            duration: 180,
            assetURL: nil,
            artworkID: nil
        )
    }
}
