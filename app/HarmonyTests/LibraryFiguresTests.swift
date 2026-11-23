import Foundation
import Testing
@testable import Harmony

/// TODO 3.19b: the Library tab's MuSe share (same calculation as the Debug screen, 2.35) and search.
@MainActor
struct LibraryFiguresTests {
    private func track(_ id: String) -> Track {
        Track(spotifyId: id, title: id, artists: ["Artist"], coverURL: nil, source: .saved, addedAt: .now)
    }

    private func score(_ id: String, _ origin: ScoreOrigin) -> SongScore {
        SongScore(spotifyId: id, energy: 0.5, positivity: 0.5, origin: origin)
    }

    @Test func coverageCountsOnlyLibrarySongsFoundInMuse() {
        let tracks = ["a", "b", "c", "d"].map(track)
        // "z" is a MuSe suggestion outside the library: it must not count.
        let scores = [score("a", .muse), score("b", .llm), score("c", .neutral), score("z", .muse)]
        #expect(LibraryFigures.museCoverage(tracks: tracks, scores: scores) == 0.25)
    }

    @Test func coverageOfAnEmptyLibraryIsUnknown() {
        #expect(LibraryFigures.museCoverage(tracks: [], scores: [score("a", .muse)]) == nil)
    }

    @Test func searchLooksAtTitleAndEveryArtist() {
        let artists = ["Daft Punk", "Pharrell Williams"]
        #expect(LibraryFigures.matches(title: "Get Lucky", artists: artists, query: "lucky"))
        #expect(LibraryFigures.matches(title: "Get Lucky", artists: artists, query: "PHARRELL"))
        #expect(!LibraryFigures.matches(title: "Get Lucky", artists: artists, query: "queen"))
    }

    @Test func searchIgnoresAccentsAndSurroundingSpaces() {
        #expect(LibraryFigures.matches(title: "Café", artists: ["Zaz"], query: " cafe "))
        #expect(LibraryFigures.matches(title: "Je veux", artists: ["Zaz"], query: ""))
    }
}
