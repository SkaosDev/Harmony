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
