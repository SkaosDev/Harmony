import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 1.16: the demo providers return the synthetic files of `Resources/demo/` (TODO 1.15).
@MainActor
struct DemoMusicProviderTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func importsTheFiftyDemoSongs() async throws {
        let tracks = try await DemoMusicProvider(now: now).importLibrary()
        #expect(tracks.count == 50)
        #expect(Set(tracks.map(\.spotifyId)).count == 50)
        #expect(Set(tracks.map(\.source)) == [.saved, .top, .recent])
        #expect(tracks.allSatisfy { !$0.title.isEmpty && !$0.artists.isEmpty && $0.addedAt <= now })
    }

    @Test func everyDemoSongHasAScoreBetweenZeroAndOne() async throws {
        let provider = try DemoMusicProvider(now: now)
        let tracks = try await provider.importLibrary()
        let scores = provider.scores()
        #expect(scores.count == 50)
        #expect(Set(scores.map(\.spotifyId)) == Set(tracks.map(\.spotifyId)))
        #expect(scores.allSatisfy { (0...1).contains($0.energy) && (0...1).contains($0.positivity) })
        #expect(Set(scores.map(\.origin)) == [.muse, .llm, .neutral])
    }

    @Test func lookUpFindsDemoSongsOnly() async throws {
        let provider = try DemoMusicProvider(now: now)
        let track = try #require(try await provider.importLibrary().first)
        let info = try await provider.lookUp(spotifyId: track.spotifyId)
        #expect(info == TrackInfo(spotifyId: track.spotifyId, title: track.title, artists: track.artists, coverURL: nil))
        #expect(try await provider.lookUp(spotifyId: "not-a-demo-song") == nil)
    }
}

/// TODO 1.17: demo mode runs on its own in-memory store, never on the user's real data.
@MainActor
struct DemoModeTests {
    @Test func demoStoreHoldsTheDemoLibraryInMemory() throws {
        let container = try DemoMode.container()
        #expect(container.configurations.allSatisfy { $0.isStoredInMemoryOnly })

        let tracks = try container.mainContext.fetch(FetchDescriptor<Track>())
        let scores = try container.mainContext.fetch(FetchDescriptor<SongScore>())
        #expect(tracks.count == 50)
        #expect(scores.count == 50)
        #expect(Set(scores.map(\.spotifyId)) == Set(tracks.map(\.spotifyId)))
    }
}

@MainActor
struct DemoHealthProviderTests {
    /// Fixed time zone, so the tests do not depend on the machine.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    /// 15:00 on the last demo day; the first demo day is 13 days before.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15))! }
    private var firstDay: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))! }

    private func makeProvider() throws -> DemoHealthProvider {
        try DemoHealthProvider(now: now, calendar: calendar)
    }

    @Test(arguments: [HealthSignal.heartRate, .steps, .hrv, .sleep])
    func samplesStartOnTheFirstDayAndStopAtNow(signal: HealthSignal) async throws {
        let samples = try await makeProvider().samples(signal, since: .distantPast)
        let first = try #require(samples.first)
        #expect(calendar.isDate(first.start, inSameDayAs: firstDay))
        #expect(samples.allSatisfy { $0.start <= $0.end && $0.end <= now })
        #expect(samples.map(\.start) == samples.map(\.start).sorted())
    }

    @Test func sinceDropsOlderSamples() async throws {
        let since = now.addingTimeInterval(-3600)
        let samples = try await makeProvider().samples(.heartRate, since: since)
        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { $0.start >= since })
        // A heart rate in the last 30 min, so demo mode can estimate the current state (TODO 2.21).
        #expect(try #require(samples.last).start >= now.addingTimeInterval(-30 * 60))
    }

    /// Unknown is not zero: exactly one demo night has no sleep at all (watch not worn).
    @Test func oneDemoNightIsUnknown() async throws {
        let sleep = try await makeProvider().samples(.sleep, since: .distantPast)
        let nightsWithoutSleep = (1...13).filter { day in
            // Night window: 21:00 the day before → 12:00 on the wake-up day (PROJECT.md §10).
            let end = calendar.date(byAdding: DateComponents(day: day, hour: 12), to: firstDay)!
            let start = end.addingTimeInterval(-15 * 3600)
            return !sleep.contains { $0.end > start && $0.start < end }
        }
        #expect(nightsWithoutSleep.count == 1)
    }
}
