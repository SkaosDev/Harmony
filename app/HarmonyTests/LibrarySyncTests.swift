import Foundation
import SwiftData
import Testing
@testable import Harmony

/// A library read in two steps, as Spotify reads its pages.
private struct PagedProvider: MusicProvider {
    var fails = false
    func signIn() async throws {}
    func importLibrary() async throws -> [Track] { try await importLibrary { _, _ in } }
    func importLibrary(progress: @escaping (Int, Int) -> Void) async throws -> [Track] {
        if fails { throw URLError(.notConnectedToInternet) }
        progress(1, 2)
        progress(2, 2)
        return ["a", "b"].map {
            Track(spotifyId: $0, title: "Song \($0)", artists: ["Artist"], coverURL: nil, source: .saved, addedAt: .now)
        }
    }
    func lookUp(spotifyId: String) async throws -> TrackInfo? { nil }
    func play(spotifyIds: [String]) async throws {}
    func save(spotifyId: String) async throws {}
}

/// TODO 3.16: import with progress, then scores in the background.
@MainActor
struct LibrarySyncTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let defaults: UserDefaults
    private let suite = "LibrarySyncTests-\(UUID().uuidString)"

    init() throws {
        container = try HarmonyStore.container(inMemory: true)
        context = container.mainContext
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    @Test func importStoresTheSongsAndTheDate() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let sync = LibrarySync(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(sync.importedAt == nil)

        await sync.run(music: PagedProvider(), scorer: nil, context: context, now: now)

        #expect(try context.fetch(FetchDescriptor<Track>()).count == 2)
        #expect(sync.done == 2 && sync.total == 2 && sync.fraction == 1)
        #expect(sync.importedAt == now)
        #expect(LibrarySync(defaults: defaults).importedAt == now)
        #expect(sync.problem == nil && !sync.isImporting)
    }

    @Test func failedImportKeepsNoDate() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let sync = LibrarySync(defaults: defaults)

        await sync.run(music: PagedProvider(fails: true), scorer: nil, context: context)

        #expect(sync.importedAt == nil)
        #expect(sync.problem != nil)
        #expect(try context.fetch(FetchDescriptor<Track>()).isEmpty)
    }

    @Test func scoringGivesEverySongAScoreOrLeavesItForLater() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let sync = LibrarySync(defaults: defaults)
        await sync.run(music: PagedProvider(), scorer: nil, context: context)

        // No Worker: songs missing from MuSe wait (TODO 2.34).
        await sync.score(with: SongScorer(muse: try MuseCatalog.bundled(), worker: nil), context: context)

        #expect(!sync.isScoring)
        #expect(try context.fetch(FetchDescriptor<SongScore>()).count <= 2)
    }
}
