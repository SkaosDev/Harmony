import Foundation

/// The private "Harmony" playlist that holds the queue being played (TODO 3.11, PROJECT.md §9).
/// Spotify's own queue cannot be cleared through any API: every queue added to it stayed in front
/// of the next ones. Each queue replaces the playlist's songs instead, and App Remote plays it.
/// Scope `playlist-modify-private`.
struct SpotifyPlaylist {
    /// `UserDefaults` key of the playlist's ID, once created.
    static let idKey = "spotifyPlaylistId"
    static let name = "Harmony"
    static let description = "Played by Harmony. Its songs change with each queue."

    let api: SpotifyAPI
    var defaults: UserDefaults = .standard

    /// Puts `spotifyIds` in the playlist, in this order, creating it the first time (or again if
    /// it no longer exists); returns its ID.
    func fill(with spotifyIds: [String]) async throws -> String {
        let uris = spotifyIds.map(SpotifyRemote.uri)
        if let id = defaults.string(forKey: Self.idKey) {
            do {
                try await replace(id, with: uris)
                return id
            } catch SpotifyError.http(404) {
                // Deleted on Spotify's side: a new one is made below.
            }
        }
        let id = try await create()
        defaults.set(id, forKey: Self.idKey)
        try await replace(id, with: uris)
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

    /// `PUT /playlists/{id}/items` with `uris`: replaces all its songs (100 at most).
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
