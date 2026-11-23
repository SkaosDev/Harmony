import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 2.34: MuSe → Worker → neutral, cached in `SongScore`; a song is never sent twice.
@MainActor
struct SongScorerTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let store = makeTestStore()
    private let server = StubHTTP()
    private let container = try! HarmonyStore.container(inMemory: true)
    private var context: ModelContext { container.mainContext }
    private let muse = try! MuseCatalog(url: makeMuseFile([
        MuseRow(spotifyId: "id-bohemian", title: "Bohemian Rhapsody", artists: "Queen", energy: 0.81, positivity: 0.42, matchKey: "bohemian rhapsody\tqueen"),
        MuseRow(title: "Song For Nobody", artists: "Some Band", energy: 0.30, positivity: 0.60, matchKey: "song for nobody\tsome band"),
    ]))

    private func makeScorer(withWorker: Bool = true) throws -> SongScorer {
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        let worker = WorkerClient(baseURL: URL(string: "https://worker.example.dev")!, auth: auth, send: server.send)
        return SongScorer(muse: muse, worker: withWorker ? worker : nil)
    }

    private func track(_ id: String, _ title: String = "Unknown Song", artists: [String] = ["Unknown Artist"]) -> Track {
        Track(spotifyId: id, title: title, artists: artists, coverURL: nil, source: .saved, addedAt: now)
    }

    private func unknownTracks(_ count: Int) -> [Track] {
        (1...count).map { track("id-\($0)", "Song \($0)") }
    }

    /// A Worker answer with `count` scores: the same pair, or nulls.
    private func answer(_ count: Int, pair: String? = #"{"energy":0.7,"positivity":0.2}"#) -> String {
        #"{"scores":[\#(Array(repeating: pair ?? "null", count: count).joined(separator: ","))]}"#
    }

    /// Titles of the songs sent in each request to the Worker.
    private func sentTitles() throws -> [[String]] {
        try server.requests.filter { $0.url?.path() == "/score" }.map { request in
            let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as! [String: [[String: Any]]]
            return body["songs"]!.map { $0["title"] as! String }
        }
    }

    private func scores() throws -> [String: SongScore] {
        Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SongScore>()).map { ($0.spotifyId, $0) })
    }

    @Test func museFirstThenWorker() async throws {
        defer { try? store.delete() }
        server.on("/score", body: answer(1))
        let tracks = [
            track("id-bohemian", "Anything"),
            track("id-nobody", "Song For Nobody - Remastered 2009", artists: ["Some Band"]),
            track("id-new", "New Song"),
        ]

        let summary = try await makeScorer().score(tracks, in: context)

        #expect(try sentTitles() == [["New Song"]])
        #expect((summary.museBySpotifyId, summary.museByTitle, summary.llm, summary.neutral, summary.unscored) == (1, 1, 1, 0, 0))
        let stored = try scores()
        #expect(stored["id-bohemian"].map { ($0.origin, $0.energy, $0.positivity) } ?? (.neutral, 0, 0) == (.muse, 0.81, 0.42))
        #expect(stored["id-nobody"]?.origin == .muse)
        #expect(stored["id-new"].map { ($0.origin, $0.energy, $0.positivity) } ?? (.neutral, 0, 0) == (.llm, 0.7, 0.2))
    }

    @Test func sendsBatchesOfFifty() async throws {
        defer { try? store.delete() }
        [50, 50, 20].forEach { server.on("/score", body: answer($0)) }

        let summary = try await makeScorer().score(unknownTracks(120), in: context)

        #expect(try sentTitles().map(\.count) == [50, 50, 20])
        #expect(summary.llm == 120)
        #expect(try context.fetchCount(FetchDescriptor<SongScore>()) == 120)
    }

    /// The ✔ of TODO 2.34.
    @Test func songIsNeverSentTwice() async throws {
        defer { try? store.delete() }
        server.on("/score", body: answer(3))
        let tracks = unknownTracks(3) + [track("id-bohemian"), track("id-1", "Song 1")]
        let scorer = try makeScorer()

        _ = try await scorer.score(tracks, in: context)
        let again = try await scorer.score(tracks, in: context)

        #expect(try sentTitles() == [["Song 1", "Song 2", "Song 3"]])
        #expect(again.alreadyScored == 4)
        #expect((again.museBySpotifyId, again.llm, again.neutral, again.unscored) == (0, 0, 0, 0))
    }

    @Test func nullPairIsCachedAsNeutral() async throws {
        defer { try? store.delete() }
        server.on("/score", body: answer(1, pair: nil))
        let scorer = try makeScorer()

        let summary = try await scorer.score([track("id-1")], in: context)
        _ = try await scorer.score([track("id-1")], in: context)

        #expect(summary.neutral == 1)
        #expect(try scores()["id-1"].map { ($0.origin, $0.energy, $0.positivity) } ?? (.llm, 0, 0) == (.neutral, 0.5, 0.5))
        #expect(try sentTitles().count == 1)
    }

    @Test func songWithoutArtistIsNeutralWithoutBeingSent() async throws {
        defer { try? store.delete() }
        let summary = try await makeScorer().score([track("id-1", artists: [])], in: context)
        #expect(summary.neutral == 1)
        #expect(server.requests.isEmpty)
    }

    @Test func refusedBatchIsNeutral() async throws {
        defer { try? store.delete() }
        server.on("/score", status: 400)
        let summary = try await makeScorer().score(unknownTracks(2), in: context)
        #expect(summary.neutral == 2)
        #expect(summary.workerError == nil)
        #expect(try scores().values.allSatisfy { $0.origin == .neutral })
    }

    /// A failed request keeps what was scored; the rest goes next time, and only the rest.
    @Test func failedBatchIsSentAgainNextTime() async throws {
        defer { try? store.delete() }
        server.on("/score", body: answer(50))
        server.on("/score", status: 502)
        let scorer = try makeScorer()

        let first = try await scorer.score(unknownTracks(70), in: context)
        #expect((first.llm, first.unscored) == (50, 20))
        #expect(first.workerError as? WorkerError == .http(502))
        #expect(try context.fetchCount(FetchDescriptor<SongScore>()) == 50)

        server.on("/score", body: answer(20))
        let second = try await scorer.score(unknownTracks(70), in: context)
        #expect((second.alreadyScored, second.llm, second.unscored) == (50, 20, 0))
        #expect(try sentTitles().last == (51...70).map { "Song \($0)" })
    }

    @Test func withoutWorkerSongsWait() async throws {
        defer { try? store.delete() }
        let summary = try await makeScorer(withWorker: false).score(unknownTracks(3) + [track("id-bohemian")], in: context)
        #expect((summary.museBySpotifyId, summary.unscored) == (1, 3))
        #expect(try context.fetchCount(FetchDescriptor<SongScore>()) == 1)
        #expect(server.requests.isEmpty)
    }
}
