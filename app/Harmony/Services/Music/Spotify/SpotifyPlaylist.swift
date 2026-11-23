import Foundation

/// The private "Harmony" playlist that holds the queue being played (TODO 3.11, PROJECT.md §9).
/// Spotify's own queue cannot be cleared through any API: every queue added to it stayed in front
/// of the next ones. Each queue gets a new playlist instead, and App Remote plays it; the previous
/// one leaves the library. A playlist whose songs were replaced was sometimes played with its
/// former songs (test of 23 Nov.), while the Spotify app has to load a playlist it has never seen.
/// Scopes `playlist-modify-private`, `user-library-modify`.
struct SpotifyPlaylist {
    /// `UserDefaults` key of the current playlist's ID.
    static let idKey = "spotifyPlaylistId"
    static let name = "Harmony"
    static let description = "Played by Harmony. Its songs change with each queue."

    let api: SpotifyAPI
    var defaults: UserDefaults = .standard

    /// Makes a new playlist holding `spotifyIds`, in this order, and takes the previous one out of
    /// the library; returns the new playlist's ID.
    func fill(with spotifyIds: [String]) async throws -> String {
        let previous = defaults.string(forKey: Self.idKey)
        let id = try await create()
        try await replace(id, with: spotifyIds.map(SpotifyRemote.uri))
        defaults.set(id, forKey: Self.idKey)
        if let previous {
            do {
                let uri = SpotifyRemote.playlistURI(previous)
                try await api.delete("me/library?uris=\(uri.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? uri)")
            } catch {
                print("Previous Harmony playlist not removed: \(error)")
            }
        }
        return id
    }

    /// `DELETE /playlists/{id}/items`.
    func remove(_ spotifyId: String) async throws {
        guard let id = defaults.string(forKey: Self.idKey) else { return }
        try await api.send("DELETE", "playlists/\(id)/items", json: Removal(items: [.init(uri: SpotifyRemote.uri(spotifyId))]))
    }

    /// `POST /me/playlists`, private.
    private func create() async throws -> String {
        let body = try await api.send("POST", "me/playlists",
                                      json: NewPlaylist(name: Self.name, public: false, description: Self.description))
        return try JSONDecoder().decode(Created.self, from: body).id
    }

    /// `PUT /playlists/{id}/items` with `uris`: sets all its songs (100 at most).
    private func replace(_ id: String, with uris: [String]) async throws {
        try await api.send("PUT", "playlists/\(id)/items", json: ["uris": uris])
    }

    private struct NewPlaylist: Encodable {
        let name: String
        let `public`: Bool
        let description: String
    }

    private struct Created: Decodable {
        let id: String
    }

    private struct Removal: Encodable {
        struct Item: Encodable {
            let uri: String
        }
        let items: [Item]
    }
}
