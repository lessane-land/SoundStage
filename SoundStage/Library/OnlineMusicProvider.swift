import Foundation

/// A searchable online source of DRM-free audio that the spatial engine can
/// process (it decodes the remote MP3 like a local file).
enum MusicSource: String, CaseIterable, Identifiable, Sendable {
    case deezer = "Deezer"
    case internetArchive = "Archive"
    case jamendo = "Jamendo"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .deezer: return "Deezer"
        case .internetArchive: return "Internet Archive"
        case .jamendo: return "Jamendo"
        }
    }

    /// Deezer returns 30-second previews; the others stream full tracks.
    var notice: String? {
        switch self {
        case .deezer: return "30-second previews \u{2014} effects apply"
        case .internetArchive: return nil
        case .jamendo: return nil
        }
    }
}

protocol OnlineMusicProvider: Sendable {
    /// Searches the source, returning tracks (asset URL may be unresolved).
    func search(_ query: String) async throws -> [Track]
    /// Resolves the streamable MP3 URL for a result (no-op if already set).
    func resolveStreamURL(for track: Track) async throws -> URL?
}

// MARK: - Deezer (public search, no key; 30s preview clips)

struct DeezerProvider: OnlineMusicProvider {

    func search(_ query: String) async throws -> [Track] {
        var components = URLComponents(string: "https://api.deezer.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return try await tracks(from: components.url)
    }

    /// Popular tracks, shown as a browse list before the user searches.
    func chart() async throws -> [Track] {
        try await tracks(from: URL(string: "https://api.deezer.com/chart/0/tracks?limit=40"))
    }

    func resolveStreamURL(for track: Track) async throws -> URL? { track.assetURL }

    private func tracks(from url: URL?) async throws -> [Track] {
        guard let url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DeezerResponse.self, from: data)
        return response.data.compactMap(Self.track(from:))
    }

    private static func track(from item: Item) -> Track? {
        guard !item.preview.isEmpty, let preview = URL(string: item.preview) else { return nil }
        return Track(
            id: "deezer:\(item.id)",
            title: item.title,
            artist: item.artist.name,
            albumTitle: item.album.title,
            duration: 30,
            assetURL: preview,
            artworkID: nil,
            isPlayable: true,
            origin: .local,
            artworkURL: item.album.cover_medium.flatMap(URL.init(string:))
        )
    }

    private struct DeezerResponse: Decodable { let data: [Item] }
    private struct Item: Decodable {
        let id: Int
        let title: String
        let preview: String
        let artist: Artist
        let album: Album
    }
    private struct Artist: Decodable { let name: String }
    private struct Album: Decodable { let title: String; let cover_medium: String? }
}

// MARK: - Internet Archive (no API key)

struct InternetArchiveProvider: OnlineMusicProvider {

    func search(_ query: String) async throws -> [Track] {
        var components = URLComponents(string: "https://archive.org/advancedsearch.php")!
        // Restrict to music collections so results are songs, not talks/sermons.
        let musicFilter = "collection:(audio_music OR etree OR netlabels OR opensource_audio)"
        components.queryItems = [
            URLQueryItem(name: "q", value: "(\(query)) AND mediatype:(audio) AND \(musicFilter)"),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "creator"),
            URLQueryItem(name: "rows", value: "30"),
            URLQueryItem(name: "output", value: "json")
        ]
        guard let url = components.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(IASearchResponse.self, from: data)
        return response.response.docs.map { doc in
            Track(
                id: "ia:\(doc.identifier)",
                title: doc.title?.value ?? doc.identifier,
                artist: doc.creator?.value ?? "Internet Archive",
                albumTitle: "",
                duration: 0,
                assetURL: nil,
                artworkID: nil,
                isPlayable: true,
                origin: .local
            )
        }
    }

    func resolveStreamURL(for track: Track) async throws -> URL? {
        let identifier = track.id.replacingOccurrences(of: "ia:", with: "")
        guard let metaURL = URL(string: "https://archive.org/metadata/\(identifier)") else { return nil }
        let (data, _) = try await URLSession.shared.data(from: metaURL)
        let meta = try JSONDecoder().decode(IAMetadata.self, from: data)
        // Archive serves an MP3 derivative even for FLAC/OGG/SHN originals; match
        // by format ("VBR MP3"/"MP3") or a .mp3 name.
        let file = meta.files.first { f in
            let name = (f.name ?? "").lowercased()
            let format = (f.format ?? "").lowercased()
            return name.hasSuffix(".mp3") || format.contains("mp3")
        }
        guard let name = file?.name,
              let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "https://archive.org/download/\(identifier)/\(encoded)")
    }

    // Decoding
    private struct IASearchResponse: Decodable { let response: Docs }
    private struct Docs: Decodable { let docs: [Doc] }
    private struct Doc: Decodable {
        let identifier: String
        let title: FlexibleString?
        let creator: FlexibleString?
    }
    private struct IAMetadata: Decodable { let files: [File] }
    private struct File: Decodable { let name: String?; let format: String? }
}

/// Archive fields can be a string or an array of strings.
struct FlexibleString: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            value = single
        } else if let array = try? container.decode([String].self) {
            value = array.first ?? ""
        } else {
            value = ""
        }
    }
}

// MARK: - Jamendo (free API key)

struct JamendoProvider: OnlineMusicProvider {
    /// Register a free client id at https://devportal.jamendo.com and paste it.
    let clientID: String

    var isConfigured: Bool { !clientID.isEmpty && clientID != "YOUR_JAMENDO_CLIENT_ID" }

    func search(_ query: String) async throws -> [Track] {
        guard isConfigured else { return [] }
        var components = URLComponents(string: "https://api.jamendo.com/v3.0/tracks/")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "audioformat", value: "mp32"),
            URLQueryItem(name: "search", value: query)
        ]
        guard let url = components.url else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(JamendoResponse.self, from: data)
        return response.results.compactMap { item in
            guard let audio = URL(string: item.audio) else { return nil }
            return Track(
                id: "jamendo:\(item.id)",
                title: item.name,
                artist: item.artist_name,
                albumTitle: item.album_name ?? "",
                duration: TimeInterval(item.duration),
                assetURL: audio,
                artworkID: nil,
                isPlayable: true,
                origin: .local,
                artworkURL: item.album_image.flatMap(URL.init(string:))
            )
        }
    }

    func resolveStreamURL(for track: Track) async throws -> URL? {
        track.assetURL
    }

    private struct JamendoResponse: Decodable { let results: [Item] }
    private struct Item: Decodable {
        let id: String
        let name: String
        let artist_name: String
        let album_name: String?
        let duration: Int
        let audio: String
        let album_image: String?
    }
}
