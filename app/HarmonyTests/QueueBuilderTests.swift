import Foundation
import Testing
@testable import Harmony

/// Suggestions given by hand, the closest to the target first.
private struct FixedSuggestions: SuggestionSource {
    let songs: [QueueCandidate]
    func candidates(near target: Double, excluding excluded: Set<String>) -> [QueueCandidate] {
        songs.filter { !excluded.contains($0.spotifyId) }.sorted { abs($0.energy - target) < abs($1.energy - target) }
    }
}

/// Every suggestion passes the check, with the title and artist it was given.
private func accept(_ song: QueueCandidate) async -> TrackInfo? {
    TrackInfo(spotifyId: song.spotifyId, title: song.title, artists: song.artists, coverURL: nil)
}

/// TODO 3.5
@MainActor
struct QueueBuilderTests {
    /// A library with songs every 0.05 of energy: always one within 0.15 of any target.
    private let fullLibrary = (0...20).map { candidate("lib\($0)", energy: Double($0) / 20) }
    /// Suggestions every 0.02 of energy.
    private let manySuggestions = FixedSuggestions(songs: (0...50).map {
        candidate("muse\($0)", energy: Double($0) / 50, isSuggestion: true)
    })

    private func build(_ situation: Situation, e0: Double, library: [QueueCandidate],
                       exclusions: QueueExclusions = QueueExclusions(), suggestions: SuggestionSource? = nil,
                       maxSuggestions: Int = QueueBuilder.maxSuggestions,
                       check: (QueueCandidate) async -> TrackInfo? = accept) async -> [QueueEntry] {
        await QueueBuilder.build(situation: situation, e0: e0, library: library, exclusions: exclusions,
                                 suggestions: suggestions, maxSuggestions: maxSuggestions, check: check)
    }

    @Test func aCloseLibraryNeedsNoSuggestion() async {
        let queue = await build(.windDown, e0: 0.8, library: fullLibrary, suggestions: manySuggestions)
        #expect(queue.count == 5)
        #expect(queue.allSatisfy { !$0.song.isSuggestion && $0.info == nil })
        #expect(queue.map(\.target) == QueueTargets.targets(e0: 0.8, situation: .windDown))
        #expect(Set(queue.map(\.song.spotifyId)).count == 5)
    }

    @Test func farLibraryGetsAtMostTwoSuggestions() async {
        // Only energetic songs: Wind-down from 0.9 needs calm ones for its last three places.
        let library = (0...9).map { candidate("lib\($0)", energy: 0.9 + Double($0) / 100) }
        let queue = await build(.windDown, e0: 0.9, library: library, suggestions: manySuggestions)
        #expect(queue.count == 5)
        #expect(queue.filter(\.song.isSuggestion).count == 2)
        #expect(queue.filter(\.song.isSuggestion).allSatisfy { $0.info != nil })
    }

    @Test func neverMoreThanTwoSuggestions() async {
        for situation in Situation.allCases {
            for e0 in stride(from: 0.0, through: 1.0, by: 0.1) {
                let sparse = [candidate("lib", energy: 0.5)]
                let queue = await build(situation, e0: e0, library: sparse, suggestions: manySuggestions)
                #expect(queue.filter(\.song.isSuggestion).count <= 2, "\(situation) e0 = \(e0)")
            }
        }
    }

    @Test func suggestionMustBeatTheLibrarySong() async {
        // The only suggestion is farther from the target than the library song.
        let library = [candidate("lib", energy: 0.5)]
        let farther = FixedSuggestions(songs: [candidate("muse", energy: 1.0, isSuggestion: true)])
        let queue = await build(.wakeUp, e0: 0.7, library: library, suggestions: farther)
        // First place: the library song wins. Second place: the library is used up, so the suggestion.
        #expect(queue.map(\.song.spotifyId) == ["lib", "muse"])
    }

    @Test func excludedSongsAreLeftOutEverywhere() async {
        let library = [candidate("keep", energy: 0.7), candidate("skipped", energy: 0.7)]
        let suggestions = FixedSuggestions(songs: [candidate("bad", energy: 0.7, isSuggestion: true),
                                                   candidate("keep", energy: 0.7, isSuggestion: true)])
        let exclusions = QueueExclusions(songs: ["skipped"], suggestions: ["skipped", "bad"])
        let queue = await build(.wakeUp, e0: 0.7, library: library, exclusions: exclusions, suggestions: suggestions)
        // "keep" is in the library: it is never suggested, and it is used only once.
        #expect(queue.map(\.song.spotifyId) == ["keep"])
    }

    @Test func failedCheckTriesTheNextSuggestionThenKeepsTheLibrarySong() async {
        let library = [candidate("lib", energy: 0.0)]
        let suggestions = FixedSuggestions(songs: [candidate("wrong", energy: 0.7, isSuggestion: true),
                                                   candidate("right", energy: 0.65, isSuggestion: true)])
        let queue = await build(.wakeUp, e0: 0.7, library: library, suggestions: suggestions) {
            $0.spotifyId == "wrong" ? nil : await accept($0)
        }
        #expect(queue.first?.song.spotifyId == "right")

        let none = await build(.wakeUp, e0: 0.7, library: library, suggestions: suggestions) { _ in nil }
        #expect(none.map(\.song.spotifyId) == ["lib"])
    }

    @Test func emptyLibraryWithoutSuggestionsGivesAnEmptyQueue() async {
        #expect(await build(.stress, e0: 0.5, library: []).isEmpty)
    }

    @Test func museOnlyQueueIsAllSuggestions() async {
        let queue = await build(.wakeUp, e0: 0.2, library: [], suggestions: manySuggestions, maxSuggestions: .max)
        #expect(queue.count == 5)
        #expect(queue.allSatisfy { $0.song.isSuggestion })
    }

    @Test func museSuggestionsShareAnArtistBeforeAGenre() throws {
        func row(_ id: String, _ artist: String, _ genre: String, _ energy: Double) -> MuseRow {
            MuseRow(spotifyId: id, title: "Song \(id)", artists: artist, genre: genre, energy: energy,
                    positivity: 0.6, matchKey: SongKey.match(title: "Song \(id)", artist: artist))
        }
        let catalog = try MuseCatalog(url: makeMuseFile([
            row("byArtist", "Air", "electronic", 0.1),
            row("byGenre", "Someone Else", "pop", 0.5),
            row("", "Air", "electronic", 0.5),
            row("other", "Nobody", "jazz", 0.5),
        ]))
        let source = MuseSuggestions(catalog: catalog, artistKeys: [SongKey.artist("Air")], genres: ["pop"])

        // The artist's song comes first, even if farther; a song without ID is never suggested.
        #expect(source.candidates(near: 0.5, excluding: []).map(\.spotifyId) == ["byArtist"])
        // Once it is excluded, the genre's song.
        #expect(source.candidates(near: 0.5, excluding: ["byArtist"]).map(\.spotifyId) == ["byGenre"])
        #expect(source.candidates(near: 0.5, excluding: []).allSatisfy { $0.isSuggestion })

        let any = MuseSuggestions(catalog: catalog, artistKeys: [], genres: [], anySong: true)
        #expect(any.candidates(near: 0.5, excluding: []).map(\.spotifyId) == ["byGenre", "other", "byArtist"])
    }

    @Test func museGenreOfALibrarySong() throws {
        let catalog = try MuseCatalog(url: makeMuseFile([
            MuseRow(spotifyId: "id1", title: "Hello", artists: "Adele", genre: "pop", energy: 0.4, positivity: 0.3,
                    matchKey: SongKey.match(title: "Hello", artist: "Adele")),
            MuseRow(title: "Untagged", artists: "Adele", energy: 0.4, positivity: 0.3,
                    matchKey: SongKey.match(title: "Untagged", artist: "Adele")),
        ]))
        #expect(catalog.genre(spotifyId: "id1", title: "", artists: []) == "pop")
        #expect(catalog.genre(spotifyId: "", title: "Hello", artists: ["Adele"]) == "pop")
        #expect(catalog.genre(spotifyId: "", title: "Untagged", artists: ["Adele"]) == nil)
        #expect(catalog.genre(spotifyId: "", title: "Missing", artists: ["Adele"]) == nil)
    }
}
