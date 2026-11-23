import Foundation
import Testing
@testable import Harmony

/// A music service that knows a few songs by ID.
struct LookUpOnlyProvider: MusicProvider {
    var songs: [String: TrackInfo] = [:]
    var fails = false

    func signIn() async throws {}
    func importLibrary() async throws -> [Track] { [] }
    func lookUp(spotifyId: String) async throws -> TrackInfo? {
        if fails { throw URLError(.notConnectedToInternet) }
        return songs[spotifyId]
    }
    func play(spotifyIds: [String]) async throws {}
    func save(spotifyId: String) async throws {}
}

/// TODO 3.6
@MainActor
struct SuggestionCheckTests {
    private let suggestion = QueueCandidate(spotifyId: "id1", title: "Don't Stop Me Now", artists: ["Queen"],
                                            energy: 0.8, positivity: 0.9, origin: .muse, isSuggestion: true)

    private func info(_ title: String, _ artist: String, id: String = "id1") -> TrackInfo {
        TrackInfo(spotifyId: id, title: title, artists: [artist, "Someone"], coverURL: URL(string: "https://example.com/c.jpg"))
    }

    @Test func sameSongIsKeptWithTheServiceInfo() async {
        // Spotify's spelling: curly apostrophe and a version label.
        let spotify = info("Don’t Stop Me Now - Remastered 2011", "Queen")
        let provider = LookUpOnlyProvider(songs: ["id1": spotify])
        #expect(await SuggestionCheck.verify(suggestion, using: provider) == spotify)
    }

    @Test func unknownIdIsLeftOut() async {
        #expect(await SuggestionCheck.verify(suggestion, using: LookUpOnlyProvider()) == nil)
    }

    @Test func anotherSongBehindTheIdIsLeftOut() async {
        let wrongTitle = LookUpOnlyProvider(songs: ["id1": info("Bohemian Rhapsody", "Queen")])
        #expect(await SuggestionCheck.verify(suggestion, using: wrongTitle) == nil)
        let wrongArtist = LookUpOnlyProvider(songs: ["id1": info("Don't Stop Me Now", "McFly")])
        #expect(await SuggestionCheck.verify(suggestion, using: wrongArtist) == nil)
    }

    @Test func noAnswerLeavesTheSuggestionOut() async {
        #expect(await SuggestionCheck.verify(suggestion, using: LookUpOnlyProvider(fails: true)) == nil)
    }

    @Test func wrongIdIsDiscardedFromTheQueue() async {
        // The only suggestion has a wrong ID: the library song stays.
        let source = MuseSuggestionList(songs: [suggestion])
        let provider = LookUpOnlyProvider(songs: ["id1": info("Bohemian Rhapsody", "Queen")])
        let queue = await QueueBuilder.build(
            situation: .wakeUp, e0: 0.8, library: [candidate("lib", energy: 0.1)], exclusions: QueueExclusions(),
            suggestions: source) { await SuggestionCheck.verify($0, using: provider) }
        #expect(queue.map(\.song.spotifyId) == ["lib"])
    }
}

/// Suggestions given by hand, in order.
private struct MuseSuggestionList: SuggestionSource {
    let songs: [QueueCandidate]
    func candidates(near target: Double, excluding excluded: Set<String>) -> [QueueCandidate] {
        songs.filter { !excluded.contains($0.spotifyId) }
    }
}
