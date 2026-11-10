import Foundation
import SwiftData
import Testing
@testable import Harmony

/// A health provider whose anchor is a count: each `newSamples` returns what was appended since
/// the last call, like HealthKit's anchored query. Appending an old sample is a late watch sync.
@MainActor
private final class AnchoredFakeProvider: HealthProvider {
    var data: [HealthSignal: [HealthSample]] = [:]
    var now: Date
    private var delivered: [HealthSignal: Int] = [:]

    init(now: Date) { self.now = now }

    func requestConsent(_ signals: Set<HealthSignal>) async throws {}

    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        data[signal, default: []].filter { $0.end >= since && $0.end <= now }.sorted { $0.start < $1.start }
    }

    func newSamples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        let all = data[signal, default: []]
        let new = all.dropFirst(delivered[signal, default: 0])
        delivered[signal] = all.count
        return new.filter { $0.start >= since }.sorted { $0.start < $1.start }
    }
}

/// TODO 1.29, 1.32: the summaries follow what the watch adds at each opening.
@MainActor
struct SummaryStoreTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// Heart rate every 5 min over the night of 10 → 11 Nov, asleep 23:00 → 07:00, 10 a.m. steps.
    private func makeProvider() -> AnchoredFakeProvider {
        let provider = AnchoredFakeProvider(now: at(11, 10, 30))
        provider.data[.heartRate] = stride(from: at(10, 21), to: at(11, 10, 30), by: 300).map {
            HealthSample(start: $0, end: $0, value: 60)
        }
        provider.data[.sleep] = [HealthSample(start: at(10, 23), end: at(11, 7), value: 1)]
        provider.data[.steps] = [HealthSample(start: at(11, 10), end: at(11, 10, 10), value: 500)]
        return provider
    }

    private func update(_ provider: AnchoredFakeProvider, _ context: ModelContext) async throws -> SummaryStore.Report {
        try #require(try await SummaryStore.update(provider: provider, context: context, now: provider.now, calendar: calendar))
    }

    @Test func firstOpeningFillsHoursAndLastNight() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let report = try await update(makeProvider(), context)

        let hours = try context.fetch(FetchDescriptor<HourSummary>(sortBy: [SortDescriptor(\.hourStart)]))
        #expect(hours.count == 14)  // 21:00 → 10:00
        #expect(hours.first?.hourStart == at(10, 21))
        #expect(hours.last?.steps == 500)
        let night = try #require(try context.fetch(FetchDescriptor<NightSummary>()).only)
        #expect(night.date == at(11, 0))
        #expect(night.sleepMinutes == 480)
        #expect(night.sleepEnd == at(11, 7))
        #expect(report.newSamples[.sleep] == 1)
    }

    @Test func openingWithNothingNewChangesNothing() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let provider = makeProvider()
        _ = try await update(provider, context)
        provider.now = at(11, 11)
        let report = try await update(provider, context)

        #expect(report.newSamples.values.allSatisfy { $0 == 0 })
        #expect(report.hours == 0 && report.nights == 0)
        #expect(try context.fetchCount(FetchDescriptor<HourSummary>()) == 14)
    }

    /// The watch syncs an old reading later: its hour is recomputed, still one row per hour.
    @Test func lateSampleUpdatesItsHour() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let provider = makeProvider()
        _ = try await update(provider, context)
        provider.data[.heartRate, default: []].append(HealthSample(start: at(11, 2, 1), end: at(11, 2, 1), value: 120))
        provider.now = at(11, 11)
        _ = try await update(provider, context)

        let twoAM = at(11, 2)
        let hour = try #require(try context.fetch(FetchDescriptor<HourSummary>(predicate: #Predicate { $0.hourStart == twoAM })).only)
        #expect(hour.hrCount == 13)
        #expect(hour.meanHR == Double(12 * 60 + 120) / 13)
        #expect(try context.fetchCount(FetchDescriptor<HourSummary>()) == 14)
        #expect(try context.fetchCount(FetchDescriptor<NightSummary>()) == 1)
    }

    /// Demo mode (FR12) gets the same summaries: 14 nights, the one without watch data unknown.
    @Test func demoModeGivesTwoWeeksOfSummaries() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let now = at(10, 15)
        let provider = try DemoHealthProvider(now: now, calendar: calendar)
        _ = try #require(try await SummaryStore.update(provider: provider, context: context, now: now, calendar: calendar))

        let nights = try context.fetch(FetchDescriptor<NightSummary>(sortBy: [SortDescriptor(\.date)]))
        // Wake-up days 28 Oct (first demo day) → 10 Nov; tonight's window has not started at 15:00.
        let firstDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
        #expect(nights.map(\.date) == (0..<14).map { calendar.date(byAdding: .day, value: $0, to: firstDay)! })
        #expect(nights.count { $0.sleepMinutes == nil } == 1)
        #expect(try context.fetchCount(FetchDescriptor<HourSummary>()) > 13 * 24 / 2)
    }

    /// TODO 1.32: only summaries are stored; the store has no table for raw samples.
    @Test func noRawSampleIsStored() {
        let tables = Set(HarmonyStore.schema.entities.map(\.name))
        #expect(tables == ["Track", "SongScore", "HourSummary", "NightSummary", "QueueRecord", "QueueItem", "FeedbackEvent", "Consent"])
    }
}

private extension Array {
    /// The single element, or nil if there are none or several.
    var only: Element? { count == 1 ? first : nil }
}
