import Foundation
import SwiftData

/// Energy and positivity of each library song (TODO 2.34, PROJECT.md §7): MuSe first, then the
/// LLM through the Worker, then the neutral 0.5 / 0.5. Results are kept in `SongScore`; a song
/// that has one is never looked up or sent again.
struct SongScorer {
    struct Summary {
        /// Songs that already had a score: skipped.
        var alreadyScored = 0
        var museBySpotifyId = 0
        var museByTitle = 0
        var llm = 0
        /// No valid LLM pair, a blank title, no artist, or a batch the Worker refused (400).
        var neutral = 0
        /// Left without a score: no Worker (demo mode, no URL) or a failed request. Sent next time.
        var unscored = 0
        /// Why the Worker step stopped early (403, 429, 502, network…), if it did.
        var workerError: (any Error)?
    }

    let muse: MuseCatalog
    /// Nil in demo mode or without a Worker URL: songs missing from MuSe then wait.
    let worker: WorkerClient?

    /// Scores the songs that have none yet. The store is saved after MuSe and after each Worker
    /// batch, so a failed request loses nothing already scored.
    func score(_ tracks: [Track], in context: ModelContext) async throws -> Summary {
        var summary = Summary()
        let scored = Set(try context.fetch(FetchDescriptor<SongScore>()).map(\.spotifyId))
        var seen = Set<String>()
        var toSend: [(spotifyId: String, song: WorkerSong)] = []
        for track in tracks where seen.insert(track.spotifyId).inserted {
            if scored.contains(track.spotifyId) {
                summary.alreadyScored += 1
            } else if let match = muse.lookUp(spotifyId: track.spotifyId, title: track.title, artists: track.artists) {
                context.insert(SongScore(spotifyId: track.spotifyId, energy: match.energy, positivity: match.positivity, origin: .muse))
                if match.foundBy == .spotifyId { summary.museBySpotifyId += 1 } else { summary.museByTitle += 1 }
            } else if let song = WorkerSong(title: track.title, artists: track.artists) {
                toSend.append((track.spotifyId, song))
            } else {
                context.insert(Self.neutral(track.spotifyId))
                summary.neutral += 1
            }
        }
        try context.save()

        guard let worker else {
            summary.unscored = toSend.count
            return summary
        }
        for start in stride(from: 0, to: toSend.count, by: WorkerClient.batchSize) {
            let batch = toSend[start..<min(start + WorkerClient.batchSize, toSend.count)]
            let pairs: [SongPair?]
            do {
                pairs = try await worker.score(batch.map(\.song))
            } catch WorkerError.rejected {
                pairs = Array(repeating: nil, count: batch.count)
            } catch {
                summary.unscored = toSend.count - start
                summary.workerError = error
                return summary
            }
            for (item, pair) in zip(batch, pairs) {
                if let pair {
                    context.insert(SongScore(spotifyId: item.spotifyId, energy: pair.energy, positivity: pair.positivity, origin: .llm))
                    summary.llm += 1
                } else {
                    context.insert(Self.neutral(item.spotifyId))
                    summary.neutral += 1
                }
            }
            try context.save()
        }
        return summary
    }

    private static func neutral(_ spotifyId: String) -> SongScore {
        SongScore(spotifyId: spotifyId, energy: 0.5, positivity: 0.5, origin: .neutral)
    }
}
