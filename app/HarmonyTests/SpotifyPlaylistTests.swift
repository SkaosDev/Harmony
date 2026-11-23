import Foundation
import Testing
@testable import Harmony

/// TODO 3.11: each queue is played as a new private "Harmony" playlist; the older ones leave
/// the library (Spotify's own queue cannot be cleared, and a refilled playlist could play its
/// former songs).
@MainActor
struct SpotifyPlaylistTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let store = makeTestStore()
    private let server = StubHTTP()
    private let defaults: UserDefaults
    private let suite = "SpotifyPlaylistTests-\(UUID().uuidString)"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    private func makePlaylist() throws -> SpotifyPlaylist {
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        return SpotifyPlaylist(api: SpotifyAPI(auth: auth, send: server.send), defaults: defaults)
    }

    private func json(_ request: URLRequest?) throws -> [String: Any] {
        let body = try #require(request?.httpBody)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    /// A playlist of `GET /me/playlists`; by default one the app made.
    private func listed(_ id: String, name: String = SpotifyPlaylist.name,
                        description: String? = SpotifyPlaylist.description) -> String {
        let text = description.map { #""\#($0)""# } ?? "null"
        return #"{"id":"\#(id)","name":"\#(name)","description":\#(text)}"#
    }

    private func calls() -> [String] {
        server.requests.filter { $0.url?.path.hasPrefix("/v1/") == true }.map { "\($0.httpMethod ?? "") \($0.url!.path)" }
    }

    @Test func firstQueueCreatesAPrivatePlaylistThenFillsItInOrder() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        server.on("/v1/me/playlists", status: 201, body: #"{"id":"pl1"}"#)
        server.on("/v1/playlists/pl1/items", status: 200, body: #"{"snapshot_id":"s"}"#)

        let id = try await makePlaylist().fill(with: ["a", "b"])

        #expect(id == "pl1")
        #expect(calls() == ["POST /v1/me/playlists", "PUT /v1/playlists/pl1/items"])
        let create = try json(server.requests.first { $0.url?.path == "/v1/me/playlists" })
        #expect(create["name"] as? String == "Harmony" && create["public"] as? Bool == false)
        let fill = try json(server.requests.last)
        #expect(fill["uris"] as? [String] == ["spotify:track:a", "spotify:track:b"])
        #expect(defaults.string(forKey: SpotifyPlaylist.idKey) == "pl1")
    }

    @Test func nextQueueOnlyMakesANewPlaylist() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        defaults.set("pl1", forKey: SpotifyPlaylist.idKey)
        server.on("/v1/me/playlists", status: 201, body: #"{"id":"pl2"}"#)
        server.on("/v1/playlists/pl2/items", body: #"{"snapshot_id":"s"}"#)

        let id = try await makePlaylist().fill(with: ["c"])

        #expect(id == "pl2" && defaults.string(forKey: SpotifyPlaylist.idKey) == "pl2")
        #expect(calls() == ["POST /v1/me/playlists", "PUT /v1/playlists/pl2/items"])
    }

    /// Every older playlist of the app leaves, the ones left by the 403 of 23 Nov. too; the user's
    /// own playlists stay, even one named "Harmony".
    @Test func oldHarmonyPlaylistsLeaveTheLibraryButNotTheCurrentOneNorTheUsersOwn() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        defaults.set("pl3", forKey: SpotifyPlaylist.idKey)
        server.on("/v1/me/playlists", body: pageJSON(
            [listed("pl3"), listed("mine", description: "My songs"), listed("run", name: "Running"), "null"],
            next: "https://api.spotify.com/v1/me/playlists?offset=50&limit=50"))
        server.on("/v1/me/playlists", body: pageJSON([listed("pl1"), listed("pl2"), listed("blank", description: nil)]))
        server.on("/v1/me/library", body: "")

        try await makePlaylist().removeOthers()

        #expect(calls() == ["GET /v1/me/playlists", "GET /v1/me/playlists", "DELETE /v1/me/library"])
        #expect(server.requests.first?.url?.query == "limit=50")
        #expect(server.requests.last?.url?.query == "uris=spotify%3Aplaylist%3Apl1,spotify%3Aplaylist%3Apl2")
    }

    @Test func oldPlaylistsLeaveFortyAtATime() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        server.on("/v1/me/playlists", body: pageJSON((1...45).map { listed("pl\($0)") }))
        server.on("/v1/me/library", body: "")
        server.on("/v1/me/library", body: "")

        try await makePlaylist().removeOthers()

        let removals = server.requests.filter { $0.httpMethod == "DELETE" }
        #expect(removals.map { StubHTTP.query($0.url!)["uris"]?.split(separator: ",").count } == [40, 5])
    }

    /// A token without `playlist-read-private` (signed in before 23 Nov.): nothing leaves, no error.
    @Test func oldPlaylistsStayIfSpotifyRefusesTheList() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        server.on("/v1/me/playlists", status: 403)

        try await makePlaylist().removeOthers()

        #expect(calls() == ["GET /v1/me/playlists"])
    }

    /// Spotify's reference: `DELETE /me/library` needs `playlist-modify-public` for a playlist
    /// (without it Spotify answered 403 and every old playlist stayed, 23 Nov.), and
    /// `GET /me/playlists` needs `playlist-read-private` to list private ones.
    @Test func signInAsksForTheScopesThatListAndDropOldPlaylists() {
        #expect(SpotifyAuth.scopes.contains("playlist-modify-public"))
        #expect(SpotifyAuth.scopes.contains("playlist-read-private"))
    }

    @Test func removeTakesTheSongOutOfThePlaylist() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        defaults.set("pl1", forKey: SpotifyPlaylist.idKey)
        server.on("/v1/playlists/pl1/items", body: #"{"snapshot_id":"s"}"#)

        try await makePlaylist().remove("b")

        #expect(calls() == ["DELETE /v1/playlists/pl1/items"])
        let body = try json(server.requests.last)
        #expect((body["items"] as? [[String: String]])?.first?["uri"] == "spotify:track:b")
    }
}
