import Foundation

/// One song of a built queue.
struct QueueEntry: Equatable {
    let song: QueueCandidate
    /// Energy aimed at for this place, 0…1.
    let target: Double
    /// What the music service says about a MuSe suggestion, checked before playing (TODO 3.6);
    /// nil for a library song.
    let info: TrackInfo?
}

/// Where MuSe suggestions come from.
protocol SuggestionSource {
    /// Songs near `target`, the closest first, none of them in `excluded`.
    func candidates(near target: Double, excluding excluded: Set<String>) -> [QueueCandidate]
}

/// MuSe songs with a Spotify ID by an artist of the library, or else in a genre of the library
/// (the MuSe genres of its songs found in MuSe) (TODO 3.5, PROJECT.md §8).
struct MuseSuggestions: SuggestionSource {
    let catalog: MuseCatalog
    /// Main artists of the library, normalized with `SongKey.artist`.
    let artistKeys: Set<String>
    let genres: Set<String>
    /// Any MuSe song, for a queue without a usable library ("Use suggested tracks").
    var anySong = false
    /// MuSe rows read per target, before leaving out the excluded ones.
    static let rowsPerTarget = 50

    func candidates(near target: Double, excluding excluded: Set<String>) -> [QueueCandidate] {
        func usable(_ songs: [MuseCatalog.Song]) -> [QueueCandidate] {
            songs.filter { !excluded.contains($0.spotifyId) }.map {
                QueueCandidate(spotifyId: $0.spotifyId, title: $0.title, artists: [$0.artists], energy: $0.energy,
                               positivity: $0.positivity, origin: .muse, isSuggestion: true)
            }
        }
        if anySong { return usable(catalog.songs(near: target, limit: Self.rowsPerTarget)) }
        let byArtist = usable(catalog.songs(byArtists: artistKeys, near: target, limit: Self.rowsPerTarget))
        return byArtist.isEmpty ? usable(catalog.songs(inGenres: genres, near: target, limit: Self.rowsPerTarget)) : byArtist
    }
}

/// Builds a queue (TODO 3.2–3.5, PROJECT.md §8): for each target, the library song with the
/// lowest cost (`TrackPicker`). When no library song is within 0.15 of the target, a MuSe song
/// with a lower cost is suggested instead, at most two per queue, each one checked first.
enum QueueBuilder {
    /// A library song this close to the target needs no suggestion.
    static let closeEnough = 0.15
    static let maxSuggestions = 2
    /// Suggestions tried (checked) per place before keeping the library song.
    static let triesPerPlace = 3

    /// - Parameters:
    ///   - library: the user's songs with their scores.
    ///   - suggestions: nil = no MuSe fallback.
    ///   - maxSuggestions: 2, except for the MuSe-only queue.
    ///   - v0: pleasantness from the answers (active mode); nil = the fixed positivity penalty.
    ///   - strategy: how the targets reach the goal (S1 but in active mode, TODO 6.12b).
    ///   - check: the music service's view of a suggestion, nil if it must be left out (TODO 3.6).
    static func build(situation: Situation, e0: Double, v0: Double? = nil, strategy: QueueStrategy = .s1, library: [QueueCandidate], exclusions: QueueExclusions,
                      suggestions: SuggestionSource?, maxSuggestions: Int = maxSuggestions,
                      check: (QueueCandidate) async -> TrackInfo?) async -> [QueueEntry] {
        let libraryIds = Set(library.map(\.spotifyId))
        let eligible = library.filter { !exclusions.songs.contains($0.spotifyId) }
        var entries: [QueueEntry] = []
        var used = Set<String>()
        var artists = Set<String>()
        var suggested = 0

        let targets = QueueTargets.targets(e0: e0, situation: situation, strategy: strategy)
        let positivity = v0.map { QueueTargets.positivityTargets(v0: $0, count: targets.count) }
        var positivityTarget: Double?

        func cost(_ song: QueueCandidate, _ target: Double) -> Double {
            TrackPicker.cost(song, target: target, situation: situation, artistsInQueue: artists,
                             positivityTarget: positivityTarget)
        }

        for (position, target) in targets.enumerated() {
            positivityTarget = positivity?[position]
            let best = TrackPicker.pick(target: target, situation: situation, from: eligible,
                                        usedIds: used, artistsInQueue: artists, positivityTarget: positivityTarget)
            var chosen = best.map { QueueEntry(song: $0, target: target, info: nil) }

            let closeSongLeft = eligible.contains {
                !used.contains($0.spotifyId) && $0.origin != .neutral && abs($0.energy - target) < closeEnough
            }
            if !closeSongLeft, suggested < maxSuggestions, let suggestions {
                let excluded = exclusions.suggestions.union(libraryIds).union(used)
                let bestCost = best.map { cost($0, target) } ?? .infinity
                let costs: [(song: QueueCandidate, cost: Double)] = suggestions
                    .candidates(near: target, excluding: excluded)
                    .map { song in (song, cost(song, target)) }
                let better = costs.filter { $0.cost < bestCost }.sorted { a, b in
                    a.cost != b.cost ? a.cost < b.cost : a.song.spotifyId < b.song.spotifyId
                }
                for candidate in better.prefix(triesPerPlace) {
                    if let info = await check(candidate.song) {
                        chosen = QueueEntry(song: candidate.song, target: target, info: info)
                        suggested += 1
                        break
                    }
                }
            }

            guard let chosen else { break }
            entries.append(chosen)
            used.insert(chosen.song.spotifyId)
            artists.insert(chosen.song.artistKey)
        }
        return entries
    }
}
