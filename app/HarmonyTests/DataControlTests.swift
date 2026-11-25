import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 3.19, FR13: what is stored, its export, and "Delete everything".
@MainActor
struct DataControlTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let defaults: UserDefaults
    private let suite = "DataControlTests-\(UUID().uuidString)"
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try HarmonyStore.container(inMemory: true)
        context = container.mainContext
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    /// One row in each of the 8 tables, and every key the app writes.
    private func fill() throws {
        context.insert(Track(spotifyId: "a", title: "Song", artists: ["Artist"], coverURL: nil, source: .saved, addedAt: now))
        context.insert(SongScore(spotifyId: "a", energy: 0.4, positivity: 0.6, origin: .muse))
        context.insert(HourSummary(hourStart: now, meanHR: 70, hrCount: 12, sdnnHRV: 40, steps: 300))
        context.insert(NightSummary(date: now, sleepMinutes: 420, sleepEnd: now, wornFraction: 1))
        let queue = QueueRecord(createdAt: now, situation: .wakeUp, startEnergy: 0.3, stateMode: .timeOnly,
                                reason: "Morning.",
                                items: [QueueItem(position: 0, spotifyId: "a", targetEnergy: 0.3, isSuggestion: false)])
        context.insert(queue)
        context.insert(FeedbackEvent(queueId: queue.id, spotifyId: "a", event: .like, seconds: nil, time: now))
        context.insert(Consent(source: .heartRate, granted: true, time: now))
        try context.save()
        DataControl.storedKeys.forEach { defaults.set("x", forKey: $0) }
    }

    @Test func countsWhatIsStored() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try fill()

        #expect(try DataControl.counts(in: context)
            == DataControl.Counts(songs: 1, scores: 1, healthSummaries: 2, queues: 1, feedback: 1))
    }

    @Test func exportHoldsEveryTable() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try fill()

        let json = try #require(JSONSerialization.jsonObject(with: DataControl.exportJSON(from: context, at: now)) as? [String: Any])

        for table in ["tracks", "songScores", "hourSummaries", "nightSummaries", "queues", "feedback", "consents"] {
            #expect((json[table] as? [Any])?.count == 1, "\(table)")
        }
        let queue = try #require((json["queues"] as? [[String: Any]])?.first)
        #expect((queue["items"] as? [Any])?.count == 1)
        #expect(queue["kind"] == nil && queue["stateMode"] as? String == "timeOnly")
        #expect(json["exportedAt"] as? String == "2026-09-21T14:13:20Z")
    }

    /// FR13: after deletion, every table is empty, the tokens and the stored keys are gone.
    @Test func deleteAllEmptiesEveryTableAndKey() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try fill()
        var signedOut = false

        try DataControl.deleteAll(in: context, defaults: defaults) { signedOut = true }

        #expect(try context.fetchCount(FetchDescriptor<Track>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SongScore>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HourSummary>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<NightSummary>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<QueueRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<QueueItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FeedbackEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Consent>()) == 0)
        #expect(signedOut)
        #expect(DataControl.storedKeys.allSatisfy { defaults.object(forKey: $0) == nil })
        #expect(DataControl.storedKeys.contains("healthAnchor.heartRate"))
    }
}
