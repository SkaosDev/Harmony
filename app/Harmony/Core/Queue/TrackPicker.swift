import Foundation

/// A song the queue builder can pick: a library song with its score, or a MuSe suggestion.
nonisolated struct QueueCandidate: Equatable, Sendable {
    let spotifyId: String
    let title: String
    /// The first one is the main artist.
    let artists: [String]
    let energy: Double
    let positivity: Double
    let origin: ScoreOrigin
    /// A MuSe song outside the library, shown as "New".
    var isSuggestion = false

    /// The main artist, normalized as in MuSe (`SongKey.artist`).
    var artistKey: String { SongKey.artist(artists.first ?? "") }
}

/// Picks the song closest to a target energy, with penalties (TODO 3.3, PROJECT.md §8).
nonisolated enum TrackPicker {
    /// Stress and Low energy, song with positivity below 0.5.
    static let negativePenalty = 0.2
    /// Main artist already in the queue.
    static let sameArtistPenalty = 0.3

    /// No penalty for an LLM score (decision of 23 Nov 2026): any fixed one left only MuSe songs in
    /// the queues, a MuSe song being almost always within 0.01 of the target.
    static func cost(_ song: QueueCandidate, target: Double, situation: Situation,
                     artistsInQueue: Set<String>) -> Double {
        var cost = abs(song.energy - target)
        if situation.prefersPositive && song.positivity < 0.5 { cost += negativePenalty }
        if artistsInQueue.contains(song.artistKey) { cost += sameArtistPenalty }
        return cost
    }

    /// The candidate with the lowest cost, leaving out `usedIds`. Songs scored by MuSe or the LLM
    /// come first; a neutral score (0.5 / 0.5, no information) is used only when none is left
    /// (PROJECT.md §7). Ties go to the smaller Spotify ID, so the result does not depend on order.
    static func pick(target: Double, situation: Situation, from candidates: [QueueCandidate],
                     usedIds: Set<String>, artistsInQueue: Set<String>) -> QueueCandidate? {
        let free = candidates.filter { !usedIds.contains($0.spotifyId) }
        let scored = free.filter { $0.origin != .neutral }
        let pool = scored.isEmpty ? free : scored
        return pool.min { a, b in
            let costA = cost(a, target: target, situation: situation, artistsInQueue: artistsInQueue)
            let costB = cost(b, target: target, situation: situation, artistsInQueue: artistsInQueue)
            return costA != costB ? costA < costB : a.spotifyId < b.spotifyId
        }
    }
}
