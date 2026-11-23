import Testing
@testable import Harmony

/// A queue candidate with test values; only what a test cares about is a parameter.
func candidate(_ id: String, energy: Double, positivity: Double = 0.8, artist: String? = nil,
               origin: ScoreOrigin = .muse, isSuggestion: Bool = false) -> QueueCandidate {
    QueueCandidate(spotifyId: id, title: "Song \(id)", artists: [artist ?? "Artist \(id)"],
                   energy: energy, positivity: positivity, origin: origin, isSuggestion: isSuggestion)
}

/// TODO 3.3
@MainActor
struct TrackPickerTests {
    private func pick(_ target: Double, _ songs: [QueueCandidate], situation: Situation = .wakeUp,
                      used: Set<String> = [], artists: Set<String> = []) -> String? {
        TrackPicker.pick(target: target, situation: situation, from: songs, usedIds: used, artistsInQueue: artists)?.spotifyId
    }

    @Test func picksTheClosestEnergy() {
        let library = [candidate("a", energy: 0.1), candidate("b", energy: 0.45), candidate("c", energy: 0.9)]
        #expect(pick(0.5, library) == "b")
        #expect(pick(0.0, library) == "a")
        #expect(pick(1.0, library) == "c")
    }

    @Test func negativeSongsArePenalizedOnlyForStressAndLowEnergy() {
        // Target 0.3: "a" is exact but negative (cost 0.2), "b" is 0.15 away and positive.
        let library = [candidate("a", energy: 0.3, positivity: 0.4), candidate("b", energy: 0.45, positivity: 0.8)]
        #expect(pick(0.3, library, situation: .stress) == "b")
        #expect(pick(0.3, library, situation: .lowEnergy) == "b")
        #expect(pick(0.3, library, situation: .windDown) == "a")
        #expect(pick(0.3, library, situation: .wakeUp) == "a")
    }

    @Test func anArtistAlreadyInTheQueueIsPenalized() {
        // "a" is exact but its artist is in the queue (cost 0.3); "b" is 0.2 away.
        let library = [candidate("a", energy: 0.5, artist: "Daft Punk"), candidate("b", energy: 0.7, artist: "Air")]
        #expect(pick(0.5, library, artists: [SongKey.artist("Daft Punk")]) == "b")
        #expect(pick(0.5, library) == "a")
    }

    @Test func llmScoresAreNotPenalized() {
        // "a" is exact and scored by the LLM; "b" is 0.05 away, from MuSe.
        #expect(pick(0.5, [candidate("a", energy: 0.5, origin: .llm), candidate("b", energy: 0.55)]) == "a")
        // Same energy: the origin does not count, the smaller ID wins.
        #expect(pick(0.5, [candidate("a", energy: 0.5, origin: .llm), candidate("b", energy: 0.5)]) == "a")
        #expect(pick(0.5, [candidate("a", energy: 0.5), candidate("b", energy: 0.5, origin: .llm)]) == "a")
    }

    @Test func neutralScoresAreUsedLast() {
        let library = [candidate("n", energy: 0.5, positivity: 0.5, origin: .neutral), candidate("m", energy: 0.95)]
        #expect(pick(0.5, library) == "m")
        #expect(pick(0.5, library, used: ["m"]) == "n")
    }

    @Test func usedSongsAreLeftOut() {
        let library = [candidate("a", energy: 0.5), candidate("b", energy: 0.6)]
        #expect(pick(0.5, library, used: ["a"]) == "b")
        #expect(pick(0.5, library, used: ["a", "b"]) == nil)
    }

    @Test func tiesGoToTheSmallerId() {
        let library = [candidate("b", energy: 0.4), candidate("a", energy: 0.6)]
        #expect(pick(0.5, library) == "a")
        #expect(pick(0.5, Array(library.reversed())) == "a")
    }
}
