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
