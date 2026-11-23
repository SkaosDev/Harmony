import Foundation
import Testing
@testable import Harmony

/// TODO 3.11: each queue is played as a new private "Harmony" playlist; the previous one leaves
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

    @Test func nextQueueMakesANewPlaylistAndDropsThePreviousOne() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        defaults.set("pl1", forKey: SpotifyPlaylist.idKey)
        server.on("/v1/me/playlists", status: 201, body: #"{"id":"pl2"}"#)
        server.on("/v1/playlists/pl2/items", body: #"{"snapshot_id":"s"}"#)
        server.on("/v1/me/library", body: "")

        let id = try await makePlaylist().fill(with: ["c"])

        #expect(id == "pl2" && defaults.string(forKey: SpotifyPlaylist.idKey) == "pl2")
        #expect(calls() == ["POST /v1/me/playlists", "PUT /v1/playlists/pl2/items", "DELETE /v1/me/library"])
        #expect(server.requests.last?.url?.query == "uris=spotify%3Aplaylist%3Apl1")
    }

    @Test func previousPlaylistLeftInTheLibraryDoesNotStopTheQueue() async throws {
        defer { try? store.delete(); defaults.removePersistentDomain(forName: suite) }
        defaults.set("pl1", forKey: SpotifyPlaylist.idKey)
        server.on("/v1/me/playlists", status: 201, body: #"{"id":"pl2"}"#)
        server.on("/v1/playlists/pl2/items", body: #"{"snapshot_id":"s"}"#)
        server.on("/v1/me/library", status: 500)

        #expect(try await makePlaylist().fill(with: ["c"]) == "pl2")
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
