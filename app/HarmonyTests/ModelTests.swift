import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 1.12: each test gets its own in-memory store, so tests leave no data behind.
@MainActor
struct HarmonyStoreTests {
    @Test func testContainerIsInMemory() throws {
        let container = try HarmonyStore.container(inMemory: true)
        #expect(!container.configurations.isEmpty)
        let inMemory = container.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(inMemory)
    }

    @Test func containersDoNotShareData() throws {
        let first = try HarmonyStore.container(inMemory: true)
        first.mainContext.insert(makeTrack(id: "t1"))
        try first.mainContext.save()

        let second = try HarmonyStore.container(inMemory: true)
        #expect(try first.mainContext.fetchCount(FetchDescriptor<Track>()) == 1)
        #expect(try second.mainContext.fetchCount(FetchDescriptor<Track>()) == 0)
    }
}

/// TODO 1.7
@MainActor
struct TrackTests {
    @Test func trackRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let addedAt = Date(timeIntervalSince1970: 1_790_000_000)
        context.insert(Track(
            spotifyId: "t1",
            title: "First Song",
            artists: ["Artist A", "Artist B"],
            coverURL: URL(string: "https://example.com/cover.jpg"),
            source: .top,
            addedAt: addedAt
        ))
        try context.save()

        let tracks = try context.fetch(FetchDescriptor<Track>())
        #expect(tracks.count == 1)
        let track = try #require(tracks.first)
        #expect(track.spotifyId == "t1")
        #expect(track.title == "First Song")
        #expect(track.artists == ["Artist A", "Artist B"])
        #expect(track.coverURL == URL(string: "https://example.com/cover.jpg"))
        #expect(track.source == .top)
        #expect(track.addedAt == addedAt)
    }

    @Test func trackWithoutCoverRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(makeTrack(id: "t1", coverURL: nil))
        try context.save()

        let track = try #require(try context.fetch(FetchDescriptor<Track>()).first)
        #expect(track.coverURL == nil)
    }

    @Test func sameSpotifyIdKeepsOneRow() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(makeTrack(id: "t1", title: "Old title"))
        try context.save()
        context.insert(makeTrack(id: "t1", title: "New title"))
        try context.save()

        let tracks = try context.fetch(FetchDescriptor<Track>())
        #expect(tracks.count == 1)
        #expect(tracks.first?.title == "New title")
    }
}

/// TODO 1.8
@MainActor
struct SongScoreTests {
    @Test func scoreRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(SongScore(spotifyId: "t1", energy: 0.8, positivity: 0.25, origin: .muse))
        context.insert(SongScore(spotifyId: "t2", energy: 0.5, positivity: 0.5, origin: .neutral))
        try context.save()

        let scores = try context.fetch(FetchDescriptor<SongScore>(sortBy: [SortDescriptor(\.spotifyId)]))
        #expect(scores.count == 2)
        #expect(scores[0].spotifyId == "t1")
        #expect(scores[0].energy == 0.8)
        #expect(scores[0].positivity == 0.25)
        #expect(scores[0].origin == .muse)
        #expect(scores[1].origin == .neutral)
    }

    @Test func sameSpotifyIdKeepsOneScore() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(SongScore(spotifyId: "t1", energy: 0.5, positivity: 0.5, origin: .neutral))
        try context.save()
        context.insert(SongScore(spotifyId: "t1", energy: 0.9, positivity: 0.7, origin: .llm))
        try context.save()

        let scores = try context.fetch(FetchDescriptor<SongScore>())
        #expect(scores.count == 1)
        #expect(scores.first?.origin == .llm)
    }
}

/// TODO 1.9
@MainActor
struct HourSummaryTests {
    private let hour = Date(timeIntervalSince1970: 1_790_002_800)

    @Test func hourRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(HourSummary(hourStart: hour, meanHR: 72.5, hrCount: 9, sdnnHRV: 48.0, steps: 1200))
        try context.save()

        let summary = try #require(try context.fetch(FetchDescriptor<HourSummary>()).first)
        #expect(summary.hourStart == hour)
        #expect(summary.meanHR == 72.5)
        #expect(summary.hrCount == 9)
        #expect(summary.sdnnHRV == 48.0)
        #expect(summary.steps == 1200)
    }

    /// Unknown is not zero: an hour without the watch keeps nil, not 0.
    @Test func hourWithoutWatchStaysUnknown() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(HourSummary(hourStart: hour, meanHR: nil, hrCount: 0, sdnnHRV: nil, steps: nil))
        try context.save()

        let summary = try #require(try context.fetch(FetchDescriptor<HourSummary>()).first)
        #expect(summary.meanHR == nil)
        #expect(summary.hrCount == 0)
        #expect(summary.sdnnHRV == nil)
        #expect(summary.steps == nil)
    }

    @Test func sameHourKeepsOneRow() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(HourSummary(hourStart: hour, meanHR: 70, hrCount: 3, sdnnHRV: nil, steps: 100))
        try context.save()
        context.insert(HourSummary(hourStart: hour, meanHR: 71, hrCount: 6, sdnnHRV: nil, steps: 250))
        try context.save()

        let summaries = try context.fetch(FetchDescriptor<HourSummary>())
        #expect(summaries.count == 1)
        #expect(summaries.first?.hrCount == 6)
    }
}

/// TODO 1.10
@MainActor
struct NightSummaryTests {
    private let day = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func nightRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let sleepEnd = day.addingTimeInterval(7 * 3600)
        context.insert(NightSummary(date: day, sleepMinutes: 432, sleepEnd: sleepEnd, wornFraction: 0.92))
        try context.save()

        let night = try #require(try context.fetch(FetchDescriptor<NightSummary>()).first)
        #expect(night.date == day)
        #expect(night.sleepMinutes == 432)
        #expect(night.sleepEnd == sleepEnd)
        #expect(night.wornFraction == 0.92)
    }

    /// Unknown is not zero: a night without enough watch data keeps nil sleep, not 0 minutes.
    @Test func unknownNightStaysUnknown() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(NightSummary(date: day, sleepMinutes: nil, sleepEnd: nil, wornFraction: 0.3))
        try context.save()

        let night = try #require(try context.fetch(FetchDescriptor<NightSummary>()).first)
        #expect(night.sleepMinutes == nil)
        #expect(night.sleepEnd == nil)
        #expect(night.wornFraction == 0.3)
    }

    @Test func sameDateKeepsOneRow() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(NightSummary(date: day, sleepMinutes: nil, sleepEnd: nil, wornFraction: 0.4))
        try context.save()
        context.insert(NightSummary(date: day, sleepMinutes: 400, sleepEnd: day, wornFraction: 0.8))
        try context.save()

        let nights = try context.fetch(FetchDescriptor<NightSummary>())
        #expect(nights.count == 1)
        #expect(nights.first?.sleepMinutes == 400)
    }
}

/// TODO 1.11
@MainActor
struct QueueAndFeedbackTests {
    private let now = Date(timeIntervalSince1970: 1_790_050_000)

    private func makeQueue() -> QueueRecord {
        QueueRecord(
            createdAt: now,
            situation: .windDown,
            startEnergy: 0.6,
            stateMode: .body,
            reason: "Evening: medium songs first, then calmer.",
            items: [
                QueueItem(position: 2, spotifyId: "t3", targetEnergy: 0.2, isSuggestion: true),
                QueueItem(position: 0, spotifyId: "t1", targetEnergy: 0.6, isSuggestion: false),
                QueueItem(position: 1, spotifyId: "t2", targetEnergy: 0.4, isSuggestion: false),
            ]
        )
    }

    @Test func queueRoundTripsWithOrderedItems() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let queue = makeQueue()
        context.insert(queue)
        try context.save()

        let record = try #require(try context.fetch(FetchDescriptor<QueueRecord>()).first)
        #expect(record.id == queue.id)
        #expect(record.createdAt == now)
        #expect(record.situation == .windDown)
        #expect(record.startEnergy == 0.6)
        #expect(record.stateMode == .body)
        #expect(record.reason == "Evening: medium songs first, then calmer.")

        // SwiftData relationships are unordered: the order comes from `position`.
        let items = record.items.sorted { $0.position < $1.position }
        #expect(items.map(\.spotifyId) == ["t1", "t2", "t3"])
        #expect(items.map(\.targetEnergy) == [0.6, 0.4, 0.2])
        #expect(items.map(\.isSuggestion) == [false, false, true])
        #expect(items.allSatisfy { $0.queue?.id == queue.id })
    }

    @Test func deletingQueueDeletesItsItems() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let queue = makeQueue()
        context.insert(queue)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<QueueItem>()) == 3)

        context.delete(queue)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<QueueRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<QueueItem>()) == 0)
    }

    @Test func feedbackRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let queueId = UUID()
        context.insert(FeedbackEvent(queueId: queueId, spotifyId: "t1", event: .skip, seconds: 12, time: now))
        // The "Did it fit?" answer is about the whole queue: no song, no seconds.
        context.insert(FeedbackEvent(queueId: queueId, spotifyId: nil, event: .fitYes, seconds: nil, time: now))
        try context.save()

        let events = try context.fetch(FetchDescriptor<FeedbackEvent>())
        let skip = try #require(events.first { $0.event == .skip })
        #expect(skip.queueId == queueId)
        #expect(skip.spotifyId == "t1")
        #expect(skip.seconds == 12)
        #expect(skip.time == now)
        let fit = try #require(events.first { $0.event == .fitYes })
        #expect(fit.queueId == queueId)
        #expect(fit.spotifyId == nil)
        #expect(fit.seconds == nil)
    }

    @Test func consentRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        context.insert(Consent(source: .heartRate, granted: true, time: now))
        context.insert(Consent(source: .hrv, granted: false, time: now))
        try context.save()

        let consents = try context.fetch(FetchDescriptor<Consent>())
        #expect(consents.count == 2)
        let heartRate = try #require(consents.first { $0.source == .heartRate })
        #expect(heartRate.granted)
        #expect(heartRate.time == now)
        let hrv = try #require(consents.first { $0.source == .hrv })
        #expect(!hrv.granted)
    }
}

/// TODO 6.7: check-ins and the log of check-in notifications.
@MainActor
struct CheckInModelTests {
    private let now = Date(timeIntervalSince1970: 1_790_050_000)

    @Test func checkInRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let answer = CheckIn(answeredAt: now, channel: .notification, promptedAt: now - 120, energy: 2,
                             zEnergy: -0.25, estimateMode: .body, labelEnergy: true, usableForLearning: false,
                             pCommonBefore: 0.44, pPersonalBefore: 0.51, dayOfUse: 3)
        context.insert(answer)
        // Given on the lock screen: everything computed later stays unknown, never 0.
        context.insert(CheckIn(answeredAt: now + 60, channel: .sheet, energy: -3, pleasantness: 1,
                               usableForLearning: true, dayOfUse: 3))
        try context.save()

        let rows = try context.fetch(FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.answeredAt)]))
        #expect(rows.count == 2)
        let first = rows[0]
        #expect(first.id == answer.id && first.channel == .notification && first.promptedAt == now - 120)
        #expect(first.energy == 2 && first.pleasantness == nil)
        #expect(first.zEnergy == -0.25 && first.estimateMode == .body && first.labelEnergy == true)
        #expect(!first.usableForLearning && first.pCommonBefore == 0.44 && first.pPersonalBefore == 0.51)
        #expect(first.dayOfUse == 3)
        let pending = rows[1]
        #expect(pending.pleasantness == 1 && pending.zEnergy == nil && pending.labelEnergy == nil)
        #expect(pending.estimateMode == nil && pending.pCommonBefore == nil)
    }

    @Test func promptLogRoundTrips() throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let checkIn = UUID()
        context.insert(PromptLog(scheduledAt: now, deliveredAt: now + 1, outcome: .answered, checkInId: checkIn))
        context.insert(PromptLog(scheduledAt: now + 7200))
        try context.save()

        let rows = try context.fetch(FetchDescriptor<PromptLog>(sortBy: [SortDescriptor(\.scheduledAt)]))
        #expect(rows.count == 2)
        #expect(rows[0].outcome == .answered && rows[0].checkInId == checkIn && rows[0].deliveredAt == now + 1)
        #expect(rows[1].outcome == nil && rows[1].deliveredAt == nil && rows[1].checkInId == nil)
    }
}

/// A library track with test values; only what a test cares about is a parameter.
@MainActor
private func makeTrack(
    id: String,
    title: String = "Song",
    coverURL: URL? = URL(string: "https://example.com/cover.jpg")
) -> Track {
    Track(
        spotifyId: id,
        title: title,
        artists: ["Artist"],
        coverURL: coverURL,
        source: .saved,
        addedAt: Date(timeIntervalSince1970: 1_790_000_000)
    )
}
