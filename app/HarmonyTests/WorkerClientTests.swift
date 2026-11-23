import Foundation
import Testing
@testable import Harmony

/// TODO 2.33: `WorkerClient` against a fake Worker (PROJECT.md §7.1).
@MainActor
struct WorkerClientTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let store = makeTestStore()
    private let server = StubHTTP()
    private let songs = [
        WorkerSong(title: "Bohemian Rhapsody", artists: ["Queen"])!,
        WorkerSong(title: "Under Pressure", artists: ["Queen", "David Bowie"])!,
    ]

    private func makeClient() throws -> WorkerClient {
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        return WorkerClient(baseURL: URL(string: "https://worker.example.dev")!, auth: auth, send: server.send)
    }

    @Test func postsTitlesAndArtistsWithTheSpotifyToken() async throws {
        defer { try? store.delete() }
        server.on("/score", body: #"{"scores":[{"energy":0.8,"positivity":0.4},{"energy":0.7,"positivity":0.5}]}"#)

        let scores = try await makeClient().score(songs)

        #expect(scores == [SongPair(energy: 0.8, positivity: 0.4), SongPair(energy: 0.7, positivity: 0.5)])
        let request = try #require(server.requests.first)
        #expect(request.url?.absoluteString == "https://worker.example.dev/score")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? NSDictionary
        #expect(body == [
            "songs": [
                ["title": "Bohemian Rhapsody", "artists": ["Queen"]],
                ["title": "Under Pressure", "artists": ["Queen", "David Bowie"]],
            ],
        ])
    }

    @Test func nullOrOutOfRangePairIsNil() async throws {
        defer { try? store.delete() }
        let three = songs + [WorkerSong(title: "Song", artists: ["Artist"])!]
        server.on("/score", body: #"{"scores":[null,{"energy":1.5,"positivity":0.5},{"energy":0,"positivity":1}]}"#)

        #expect(try await makeClient().score(three) == [nil, nil, SongPair(energy: 0, positivity: 1)])
    }

    @Test(arguments: [#"{"scores":[null]}"#, #"{"error":"x"}"#, "not json"])
    func bodyWithoutOneScorePerSongIsInvalid(_ body: String) async throws {
        defer { try? store.delete() }
        server.on("/score", body: body)
        await #expect(throws: WorkerError.invalidResponse) { try await makeClient().score(songs) }
    }

    @Test func refusedTokenIsRefreshedOnceAndSentAgain() async throws {
        defer { try? store.delete() }
        server.on("/score", status: 401)
        server.on("/api/token", body: tokenJSON(access: "access-2"))
        server.on("/score", body: #"{"scores":[null,null]}"#)

        #expect(try await makeClient().score(songs) == [nil, nil])
        #expect(server.requests.map { $0.url?.path() } == ["/score", "/api/token", "/score"])
        #expect(server.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer access-2")
    }

    @Test func secondRefusalIsAnError() async throws {
        defer { try? store.delete() }
        server.on("/score", status: 401)
        server.on("/api/token", body: tokenJSON(access: "access-2"))
        server.on("/score", status: 401)
        await #expect(throws: WorkerError.http(401)) { try await makeClient().score(songs) }
    }

    @Test(arguments: [
        (400, [String: String](), WorkerError.rejected),
        (403, [:], WorkerError.notAllowed),
        (429, ["Retry-After": "3600"], WorkerError.dailyLimit(retryAfter: 3600)),
        (502, [:], WorkerError.http(502)),
    ])
    func errorStatuses(_ status: Int, _ headers: [String: String], _ error: WorkerError) async throws {
        defer { try? store.delete() }
        server.on("/score", status: status, headers: headers)
        await #expect(throws: error) { try await makeClient().score(songs) }
        #expect(server.requests.count == 1)
    }

    @Test func songsAreCutToTheWorkerLimits() throws {
        #expect(WorkerSong(title: "  ", artists: ["Artist"]) == nil)
        #expect(WorkerSong(title: "Song", artists: []) == nil)
        #expect(WorkerSong(title: "Song", artists: [" ", ""]) == nil)

        let long = try #require(WorkerSong(title: String(repeating: "a", count: 199) + "😀b", artists: ["x"]))
        #expect(long.title == String(repeating: "a", count: 199))

        let many = try #require(WorkerSong(title: " Song ", artists: (1...12).map { "Artist \($0)" } + [String(repeating: "z", count: 150)]))
        #expect(many.title == "Song")
        #expect(many.artists == (1...10).map { "Artist \($0)" })
        #expect(WorkerSong(title: "Song", artists: [String(repeating: "z", count: 150)])?.artists == [String(repeating: "z", count: 100)])
    }
}
