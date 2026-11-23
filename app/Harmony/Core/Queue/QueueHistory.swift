import Foundation
import SwiftData

/// Spotify IDs a new queue must leave out.
nonisolated struct QueueExclusions: Equatable, Sendable {
    /// Left out of the queue, from the library or from MuSe.
    var songs: Set<String> = []
    /// Left out of the MuSe suggestions only: `songs` plus every suggestion skipped once.
    var suggestions: Set<String> = []
}

/// What earlier queues rule out (TODO 3.4, PROJECT.md §8): songs of a queue started in the last
/// 3 days, songs skipped twice in queues of the same situation, and suggestions skipped once
/// (report, "a skipped suggestion is never proposed again"). A skip is a `FeedbackEvent.skip`,
/// that is a song passed before 30 s.
enum QueueHistory {
    static let recentSeconds: TimeInterval = 3 * 24 * 3600
    static let skipsInSituation = 2

    static func exclusions(for situation: Situation, now: Date, in context: ModelContext) throws -> QueueExclusions {
        let queues = try context.fetch(FetchDescriptor<QueueRecord>())
        let skips = try context.fetch(FetchDescriptor<FeedbackEvent>()).filter { $0.event == .skip }

        var exclusions = QueueExclusions()
        for queue in queues where queue.createdAt > now - recentSeconds && queue.createdAt <= now {
            exclusions.songs.formUnion(queue.items.map(\.spotifyId))
        }

        let byId = Dictionary(queues.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var skipCounts: [String: Int] = [:]
        var skippedSuggestions = Set<String>()
        for skip in skips {
            guard let spotifyId = skip.spotifyId, let queue = byId[skip.queueId] else { continue }
            if queue.situation == situation { skipCounts[spotifyId, default: 0] += 1 }
            if queue.items.contains(where: { $0.spotifyId == spotifyId && $0.isSuggestion }) {
                skippedSuggestions.insert(spotifyId)
            }
        }
        exclusions.songs.formUnion(skipCounts.filter { $0.value >= skipsInSituation }.keys)
        exclusions.suggestions = exclusions.songs.union(skippedSuggestions)
        return exclusions
    }
}
