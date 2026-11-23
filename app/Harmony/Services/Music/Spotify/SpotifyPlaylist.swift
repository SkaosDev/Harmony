import Foundation

/// The private "Harmony" playlist that holds the queue being played (TODO 3.11, PROJECT.md §9).
/// Spotify's own queue cannot be cleared through any API: every queue added to it stayed in front
/// of the next ones. Each queue gets a new playlist instead, and App Remote plays it; the older
/// ones leave the library. A playlist whose songs were replaced was sometimes played with its
/// former songs (test of 23 Nov.), while the Spotify app has to load a playlist it has never seen.
/// Scopes `playlist-modify-private`, `playlist-modify-public`, `playlist-read-private`.
struct SpotifyPlaylist {
    /// `UserDefaults` key of the current playlist's ID.
    static let idKey = "spotifyPlaylistId"
    static let name = "Harmony"
    static let description = "Played by Harmony. Its songs change with each queue."

    let api: SpotifyAPI
    var defaults: UserDefaults = .standard

    /// Makes a new playlist holding `spotifyIds`, in this order; returns its ID.
    func fill(with spotifyIds: [String]) async throws -> String {
        let id = try await create()
        try await replace(id, with: spotifyIds.map(SpotifyRemote.uri))
        defaults.set(id, forKey: Self.idKey)
        return id
    }

    /// Takes every playlist of the app but the current one out of the library: `GET /me/playlists`,
    /// then `DELETE /me/library`, 40 at a time (Spotify's maximum). Those a failed removal left
    /// behind leave too. A playlist is the app's only if its name and its description are the
    /// app's: the user may have a playlist called "Harmony".
    func removeOthers() async {
        do {
            var ids: [String] = []
            var next: String? = "me/playlists?limit=50"
            while let url = next {
                let page = try await api.get(url, as: SpotifyPage<Listed?>.self)
                ids += page.items.compactMap { $0 }
                    .filter { $0.name == Self.name && $0.description == Self.description }
                    .map(\.id)
                next = page.next
            }
            // Read only now: a newer queue may have started meanwhile.
            let current = defaults.string(forKey: Self.idKey)
            let uris = ids.filter { $0 != current }
                .map { SpotifyRemote.playlistURI($0).addingPercentEncoding(withAllowedCharacters: .alphanumerics)! }
            for start in stride(from: 0, to: uris.count, by: 40) {
                try await api.delete("me/library?uris=\(uris[start..<min(start + 40, uris.count)].joined(separator: ","))")
            }
            print("Old Harmony playlists removed: \(uris.count)")
        } catch {
            print("Old Harmony playlists not removed: \(error)")
        }
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

    /// A playlist of `GET /me/playlists` (Spotify may send null in place of one).
    private struct Listed: Decodable {
        let id: String
        let name: String?
        let description: String?
    }

    private struct Removal: Encodable {
        struct Item: Encodable {
            let uri: String
        }
        let items: [Item]
    }
}
