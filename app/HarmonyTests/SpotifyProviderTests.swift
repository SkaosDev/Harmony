import Foundation
import Testing
@testable import Harmony

/// A song as the Web API sends it.
func trackJSON(id: String?, name: String = "Song", artists: [String] = ["Artist"], cover: String? = "https://i.scdn.co/image/large", isLocal: Bool = false) -> String {
    let idField = id.map { #""\#($0)""# } ?? "null"
    let images = cover.map { #"[{"url":"\#($0)","height":640,"width":640},{"url":"https://i.scdn.co/image/small","height":64,"width":64}]"# } ?? "[]"
    let artistList = artists.map { #"{"name":"\#($0)"}"# }.joined(separator: ",")
    return #"{"id":\#(idField),"name":"\#(name)","artists":[\#(artistList)],"album":{"images":\#(images)},"is_local":\#(isLocal)}"#
}

/// An item of `GET /me/tracks`; `track` is raw JSON (`"null"` for an unavailable song).
func savedItemJSON(_ track: String, addedAt: String = "2026-11-01T10:20:30Z") -> String {
    #"{"added_at":"\#(addedAt)","track":\#(track)}"#
}

func pageJSON(_ items: [String], next: String? = nil) -> String {
    let nextField = next.map { #""\#($0)""# } ?? "null"
    return #"{"items":[\#(items.joined(separator: ","))],"next":\#(nextField),"limit":50}"#
}

@MainActor
struct SpotifyProviderTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let store = makeTestStore()
    private let server = StubHTTP()

    private func makeProvider() throws -> SpotifyProvider {
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        return SpotifyProvider(auth: auth, api: SpotifyAPI(auth: auth, send: server.send))
    }

    /// TODO 1.23: 50 per page, following `next` until the last page.
    @Test func importsEveryLikedSongPageByPage() async throws {
        defer { try? store.delete() }
        func items(_ range: Range<Int>) -> [String] { range.map { savedItemJSON(trackJSON(id: "id\($0)")) } }
        server.on("/v1/me/tracks", body: pageJSON(items(0..<50), next: "https://api.spotify.com/v1/me/tracks?offset=50&limit=50"))
        server.on("/v1/me/tracks", body: pageJSON(items(50..<100), next: "https://api.spotify.com/v1/me/tracks?offset=100&limit=50"))
        server.on("/v1/me/tracks", body: pageJSON(items(100..<107)))

        let tracks = try await makeProvider().savedTracks()

        #expect(tracks.map(\.spotifyId) == (0..<107).map { "id\($0)" })
        #expect(tracks.allSatisfy { $0.source == .saved })
        #expect(server.requests.map { StubHTTP.query($0.url!)["offset"] } == [nil, "50", "100"])
        #expect(server.requests.allSatisfy { StubHTTP.query($0.url!)["limit"] == "50" })
    }

    @Test func readsTheSongFields() async throws {
        defer { try? store.delete() }
        server.on("/v1/me/tracks", body: pageJSON([
            savedItemJSON(trackJSON(id: "id1", name: "First Song", artists: ["Main", "Guest"]), addedAt: "2026-11-01T10:20:30Z"),
        ]))

        let track = try #require(try await makeProvider().savedTracks().first)

        #expect(track.title == "First Song")
        #expect(track.artists == ["Main", "Guest"])
        #expect(track.coverURL == URL(string: "https://i.scdn.co/image/large"))
        #expect(track.addedAt == Date(timeIntervalSince1970: 1_793_528_430))
    }

    @Test func skipsLocalFilesAndUnavailableSongs() async throws {
        defer { try? store.delete() }
        server.on("/v1/me/tracks", body: pageJSON([
            savedItemJSON(trackJSON(id: "id1")),
            savedItemJSON(trackJSON(id: nil, cover: nil, isLocal: true)),
            savedItemJSON("null"),
        ]))

        #expect(try await makeProvider().savedTracks().map(\.spotifyId) == ["id1"])
    }

    @Test func lookUpReadsASong() async throws {
        defer { try? store.delete() }
        server.on("/v1/tracks/id1", body: trackJSON(id: "id1", name: "First Song", artists: ["Main"]))

        let info = try await makeProvider().lookUp(spotifyId: "id1")

        #expect(info == TrackInfo(spotifyId: "id1", title: "First Song", artists: ["Main"], coverURL: URL(string: "https://i.scdn.co/image/large")))
    }

    @Test(arguments: [404, 400])
    func lookUpOfAWrongIDIsNil(status: Int) async throws {
        defer { try? store.delete() }
        server.on("/v1/tracks/wrong", status: status, body: #"{"error":{"status":\#(status),"message":"error"}}"#)
        #expect(try await makeProvider().lookUp(spotifyId: "wrong") == nil)
    }
}
