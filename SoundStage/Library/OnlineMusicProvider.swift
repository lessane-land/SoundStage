import Foundation

/// A searchable online source of DRM-free audio that the spatial engine can
/// process (it decodes the remote MP3 like a local file).
enum MusicSource: String, CaseIterable, Identifiable, Sendable {
    case internetArchive = "Archive"
    case jamendo = "Jamendo"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .internetArchive: return "Internet Archive"
        case .jamendo: return "Jamendo"
        }
    }
}

protocol OnlineMusicProvider: Sendable {
    /// Searches the source, returning tracks (asset URL may be unresolved).
    func search(_ query: String) async throws -> [Track]
    /// Resolves the streamable MP3 URL for a result (no-op if already set).
    func resolveStreamURL(for track: Track) async throws -> URL?
}

// MARK: - Internet Archive (no API key)

struct InternetArchiveProvider: OnlineMusicProvider {

    func search(_ query: String) async throws -> [Track] {
        var components = URLComponents(string: "https://archive.org/advancedsearch.php")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "(\(query)) AND mediatype:(audio)"),
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
        // Prefer a plain MP3 file.
        guard let file = meta.files.first(where: { ($0.name ?? "").lowercased().hasSuffix(".mp3") }),
              let name = file.name,
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
