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

/// TODO 2.22: the state now, from what a health provider returns (as the Debug screen does).
@MainActor
struct CurrentStateTests {
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
            let body = fixture.expected("z_hr_30") != nil
            #expect(state.estimate.mode == (body ? .body : .timeOnly), "\(fixture.name)")
            expectClose(state.estimate.value, body ? fixture.probability : fixture.timeOnlyProbability, fixture.name)
        }
    }

    @Test func demoDataGiveAStateOnTheirLastDay() async throws {
        let calendar = StateFixtures.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 16))!
        let provider = try DemoHealthProvider(now: now, calendar: calendar)
        let state = try await CurrentState.compute(provider: provider, estimator: try StateEstimator.bundled(),
                                                   now: now, calendar: calendar)
        #expect(state.features.count == 13)
        #expect(state.estimate.value > 0 && state.estimate.value < 1)
    }
}
