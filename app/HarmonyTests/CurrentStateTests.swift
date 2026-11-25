import Foundation
import Testing
@testable import Harmony

/// A health provider holding fixed samples (`samples` = those ending at or after `since`).
@MainActor
private struct FixedProvider: HealthProvider {
    let data: [HealthSignal: [HealthSample]]

    func requestConsent(_ signals: Set<HealthSignal>) async throws {}

    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        data[signal, default: []].filter { $0.end >= since }
    }

    func newSamples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        data[signal, default: []].filter { $0.start >= since }
    }
}

/// A health provider whose reads fail, as HealthKit can (TODO 3.22).
@MainActor
private struct FailingProvider: HealthProvider {
    func requestConsent(_ signals: Set<HealthSignal>) async throws {}

    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        throw CocoaError(.fileReadUnknown)
    }

    func newSamples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        throw CocoaError(.fileReadUnknown)
    }
}

/// TODO 2.22: the state now, from what a health provider returns (as the Debug screen does).
@MainActor
struct CurrentStateTests {
    /// TODO 3.22: unreadable health data is the same as no watch: time of day only, never a
    /// failed queue.
    @Test func unreadableHealthDataGivesTheTimeOfDayEstimate() async throws {
        let state = try await CurrentState.computeOrTimeOnly(provider: FailingProvider(), estimator: try StateEstimator.bundled())
        #expect(state.estimate.mode == .timeOnly)
        #expect((state.features["z_hr_30"] ?? nil) == nil)
    }

    /// The time-of-day fallback ignores the watch, even when it has recent heart rate.
    @Test func timeOnlyIgnoresTheWatch() async throws {
        let estimator = try StateEstimator.bundled()
        let fixture = try #require(try StateFixtures.load().cases.first { $0.expected("z_hr_30") != nil })
        let state = try await CurrentState.timeOnly(estimator: estimator, now: fixture.answer, calendar: StateFixtures.calendar)
        #expect(state.estimate.mode == .timeOnly)
        #expect((state.features["z_hr_30"] ?? nil) == nil)
        expectClose(state.estimate.value, fixture.timeOnlyProbability, fixture.name)
    }

    @Test func providerSamplesGiveTheGoldenFeaturesAndState() async throws {
        let estimator = try StateEstimator.bundled()
        for fixture in try StateFixtures.load().cases {
            let provider = FixedProvider(data: [
                .heartRate: fixture.heartRate, .steps: fixture.stepSamples, .sleep: fixture.sleepSamples,
            ])
            let state = try await CurrentState.compute(provider: provider, estimator: estimator,
                                                       now: fixture.answer, calendar: StateFixtures.calendar)
            for name in estimator.params.features {
                expectClose(state.features[name] ?? nil, fixture.expected(name), "\(fixture.name) \(name)")
            }
            let body = fixture.expected("raw_hr_30") != nil
            #expect(state.estimate.mode == (body ? .body : .timeOnly), "\(fixture.name)")
            expectClose(state.estimate.value, body ? fixture.probability : fixture.timeOnlyProbability, fixture.name)
            expectClose(state.estimate.valence, body ? fixture.valenceProbability : fixture.valenceTimeOnlyProbability,
                        "\(fixture.name) valence")
        }
    }

    @Test func demoDataGiveAStateOnTheirLastDay() async throws {
        let calendar = StateFixtures.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 16))!
        let provider = try DemoHealthProvider(now: now, calendar: calendar)
        let state = try await CurrentState.compute(provider: provider, estimator: try StateEstimator.bundled(),
                                                   now: now, calendar: calendar)
        #expect(state.features.count == 17)
        #expect(state.estimate.value > 0 && state.estimate.value < 1)
    }

    /// TODO 6.11: `compute` scores the grid of the 14 days before from the same data, and the
    /// rank is the share of those points at or below the current probability.
    @Test func demoDataGiveTheRankAmongTheirOwnFourteenDays() async throws {
        let calendar = StateFixtures.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 16))!
        let provider = try DemoHealthProvider(now: now, calendar: calendar)
        let state = try await CurrentState.compute(provider: provider, estimator: try StateEstimator.bundled(),
                                                   now: now, calendar: calendar)
        let grid = state.gridProbabilities
        #expect(grid.count >= PersonalRank.minimumRows && grid.count <= 14 * 32)
        #expect(grid.allSatisfy { $0 > 0 && $0 < 1 })
        #expect(state.rank == Double(grid.filter { $0 <= state.estimate.value }.count) / Double(grid.count))
    }
}
