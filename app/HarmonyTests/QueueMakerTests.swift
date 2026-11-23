import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 3.2–3.8 put together on a stored library.
@MainActor
struct QueueMakerTests {
    private let now = Date(timeIntervalSince1970: 1_790_050_000)

    private func state(_ e0: Double, mode: StateEstimate.Mode = .body) -> CurrentState {
        CurrentState(date: now, features: ["z_sleep_min": -1.5, "z_hr_30": nil], estimate: StateEstimate(value: e0, mode: mode))
    }

    /// `count` library songs with energies spread over 0…1, each by its own artist.
    private func addLibrary(_ context: ModelContext, count: Int) throws {
        for index in 0..<count {
            let id = "lib\(index)"
            context.insert(Track(spotifyId: id, title: "Song \(index)", artists: ["Artist \(index)"],
                                 coverURL: URL(string: "https://example.com/\(id).jpg"), source: .saved, addedAt: now))
            context.insert(SongScore(spotifyId: id, energy: Double(index) / Double(max(count - 1, 1)),
                                     positivity: 0.7, origin: index % 3 == 0 ? .llm : .muse))
        }
        try context.save()
    }

    @Test func preparesAndRecordsALibraryQueue() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        try addLibrary(context, count: 40)
        // A track without score is never picked.
        context.insert(Track(spotifyId: "unscored", title: "X", artists: ["Y"], coverURL: nil, source: .top, addedAt: now))
        let maker = QueueMaker(context: context, catalog: nil, music: LookUpOnlyProvider())

        let queue = try await maker.prepare(.windDown, state: state(0.8))
        #expect(queue.entries.count == 5)
        #expect(queue.songs.map(\.spotifyId) == queue.entries.map(\.song.spotifyId))
        #expect(queue.songs.allSatisfy { $0.coverURL != nil })
        #expect(!queue.entries.contains { $0.song.spotifyId == "unscored" })
        #expect(queue.reason.hasPrefix("Short night"))
        #expect(queue.e0 == 0.8)

        let record = try maker.record(queue, at: now)
        let items = record.items.sorted { $0.position < $1.position }
        #expect(items.map(\.spotifyId) == queue.entries.map(\.song.spotifyId))
        #expect(items.map(\.targetEnergy) == QueueTargets.targets(e0: 0.8, situation: .windDown))
        #expect(record.kind == .body && record.reason == queue.reason && record.startEnergy == 0.8)
        #expect(record.stateMode == .body)

        // Songs of the queue just played are left out of the next one.
        let next = try await maker.prepare(.windDown, state: state(0.8))
        #expect(Set(next.entries.map(\.song.spotifyId)).isDisjoint(with: items.map(\.spotifyId)))
    }

    /// TODO 4.4: the queue keeps the kind drawn for the day and the estimate it really used.
    @Test func recordsThePilotKindAndTheEstimateUsed() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        try addLibrary(context, count: 40)
        let maker = QueueMaker(context: context, catalog: nil, music: LookUpOnlyProvider())

        // A body day without recent heart rate: drawn body, started from the time of day.
        let fallback = try await maker.prepare(.wakeUp, state: state(0.3, mode: .timeOnly))
        let fallbackRecord = try maker.record(fallback, at: now)
        #expect(fallbackRecord.kind == .body && fallbackRecord.stateMode == .timeOnly)

        let timeOnly = try await maker.prepare(.lowEnergy, state: state(0.3, mode: .timeOnly), kind: .timeOnly)
        #expect(timeOnly.kind == .timeOnly && timeOnly.stateMode == .timeOnly)
        let timeOnlyRecord = try maker.record(timeOnly, at: now)
        #expect(timeOnlyRecord.kind == .timeOnly && timeOnlyRecord.stateMode == .timeOnly)
    }

    @Test func museOnlyQueueUsesCheckedSuggestions() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let rows = (0..<10).map { index in
            MuseRow(spotifyId: "m\(index)", title: "Muse \(index)", artists: "Band \(index)", genre: "pop",
                    energy: Double(index) / 10, positivity: 0.8,
                    matchKey: SongKey.match(title: "Muse \(index)", artist: "Band \(index)"))
        }
        let catalog = try MuseCatalog(url: makeMuseFile(rows))
        let known = Dictionary(uniqueKeysWithValues: rows.map {
            ($0.spotifyId, TrackInfo(spotifyId: $0.spotifyId, title: $0.title, artists: [$0.artists], coverURL: nil))
        })
        let maker = QueueMaker(context: container.mainContext, catalog: catalog, music: LookUpOnlyProvider(songs: known))

        let queue = try await maker.prepareMuseOnly(.wakeUp, state: state(0.1))
        #expect(queue.entries.count == 5)
        #expect(queue.entries.allSatisfy { $0.song.isSuggestion })
        #expect(queue.songs.map(\.title).allSatisfy { $0.hasPrefix("Muse") })
    }

    @Test func twoThousandSongsQueueIsQuick() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        try addLibrary(context, count: 2000)
        let maker = QueueMaker(context: context, catalog: try? MuseCatalog.bundled(), music: LookUpOnlyProvider())

        let start = Date()
        let queue = try await maker.prepare(.lowEnergy, state: state(0.3))
        let seconds = Date().timeIntervalSince(start)
        print("Queue of \(queue.entries.count) songs from 2,000 built in \(String(format: "%.3f", seconds)) s")
        #expect(queue.entries.count == 5)
        #expect(seconds < 2)
    }
}
