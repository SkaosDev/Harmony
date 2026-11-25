import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 3.4
@MainActor
struct QueueHistoryTests {
    private let now = Date(timeIntervalSince1970: 1_790_050_000)
    private let day: TimeInterval = 24 * 3600

    /// Inserts a queue `daysAgo` days before now and returns its ID.
    @discardableResult
    private func addQueue(_ context: ModelContext, daysAgo: Double, situation: Situation,
                          songs: [String], suggestions: [String] = []) -> UUID {
        let items = (songs.map { ($0, false) } + suggestions.map { ($0, true) }).enumerated().map {
            QueueItem(position: $0.offset, spotifyId: $0.element.0, targetEnergy: 0.5, isSuggestion: $0.element.1)
        }
        let queue = QueueRecord(createdAt: now - daysAgo * day, situation: situation, startEnergy: 0.5,
                                reason: "", items: items)
        context.insert(queue)
        return queue.id
    }

    private func skip(_ context: ModelContext, _ spotifyId: String, in queueId: UUID) {
        context.insert(FeedbackEvent(queueId: queueId, spotifyId: spotifyId, event: .skip, seconds: 10, time: now))
    }

    @Test func songsOfAQueueFromTheLastThreeDaysAreLeftOut() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        addQueue(context, daysAgo: 2.9, situation: .wakeUp, songs: ["recent"])
        addQueue(context, daysAgo: 3.1, situation: .wakeUp, songs: ["old"])
        try context.save()

        let exclusions = try QueueHistory.exclusions(for: .windDown, now: now, in: context)
        #expect(exclusions.songs == ["recent"])
        #expect(exclusions.suggestions == ["recent"])
    }

    @Test func songSkippedTwiceInTheSituationIsLeftOutOfThatSituationOnly() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let first = addQueue(context, daysAgo: 10, situation: .windDown, songs: ["twice", "once"])
        let second = addQueue(context, daysAgo: 8, situation: .windDown, songs: ["twice"])
        let other = addQueue(context, daysAgo: 6, situation: .wakeUp, songs: ["once"])
        skip(context, "twice", in: first)
        skip(context, "twice", in: second)
        skip(context, "once", in: first)
        skip(context, "once", in: other) // another situation: does not count for Wind-down
        context.insert(FeedbackEvent(queueId: first, spotifyId: "once", event: .like, seconds: nil, time: now))
        try context.save()

        #expect(try QueueHistory.exclusions(for: .windDown, now: now, in: context).songs == ["twice"])
        #expect(try QueueHistory.exclusions(for: .wakeUp, now: now, in: context).songs.isEmpty)
    }

    @Test func suggestionSkippedOnceIsNeverSuggestedAgain() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let queue = addQueue(context, daysAgo: 20, situation: .stress, songs: ["library"], suggestions: ["new"])
        skip(context, "new", in: queue)
        skip(context, "library", in: queue)
        try context.save()

        let exclusions = try QueueHistory.exclusions(for: .lowEnergy, now: now, in: context)
        #expect(exclusions.songs.isEmpty)
        #expect(exclusions.suggestions == ["new"])
    }

    @Test func emptyHistoryExcludesNothing() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        #expect(try QueueHistory.exclusions(for: .stress, now: now, in: context) == QueueExclusions())
    }
}
