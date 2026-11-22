import Foundation
import Testing
@testable import Harmony

/// TODO 2.20: the Core ML model gives the probabilities Python expects.
@MainActor
struct StateEstimatorTests {
    /// The fixture features in model order (nil = unknown).
    private func row(_ fixture: StateFixtures.Case, _ params: ModelParams) -> [Double?] {
        params.features.map { fixture.expected($0) }
    }

    @Test func modelProbabilityMatchesTheGoldenFixtures() throws {
        let estimator = try StateEstimator.bundled()
        for fixture in try StateFixtures.load().cases {
            let probability = try estimator.modelProbability(row(fixture, estimator.params))
            expectClose(probability, fixture.probability, "\(fixture.name) probability")
        }
    }

    @Test func unknownFeaturesAreImputedNotZero() throws {
        let estimator = try StateEstimator.bundled()
        let unknown: [Double?] = Array(repeating: nil, count: 13)
        let zeros: [Double?] = Array(repeating: 0, count: 13)
        #expect(try estimator.modelProbability(unknown) != estimator.modelProbability(zeros))
    }
}

/// TODO 2.21: time-only mode (`prior(hour)` of the report) without a reference or a heart rate.
@MainActor
struct TimeOnlyModeTests {
    private func features(_ fixture: StateFixtures.Case) -> [String: Double?] {
        Dictionary(uniqueKeysWithValues: fixture.features.keys.map { ($0, fixture.expected($0)) })
    }

    @Test func timeOnlyModelMatchesTheGoldenFixtures() throws {
        let timeOnly = try ModelParams.bundled().timeOnly
        #expect(timeOnly.features == ["hour_sin", "hour_cos", "weekend"])
        for fixture in try StateFixtures.load().cases {
            let row = timeOnly.features.map { fixture.expected($0) }
            expectClose(timeOnly.probability(row), fixture.timeOnlyProbability, "\(fixture.name) time only")
        }
    }

    @Test func noWatchDataGivesTheTimeOnlyMode() throws {
        let t = Date(timeIntervalSince1970: 1_795_500_000)
        let empty = FeatureBuilder.features(at: t, series: WatchSeries(heartRate: [], steps: []), nights: [],
                                            calendar: StateFixtures.calendar)
        let estimator = try StateEstimator.bundled()
        let estimate = try estimator.estimate(empty)
        #expect(estimate.mode == .timeOnly)
        let row = try FeatureBuilder.row(empty, order: estimator.params.timeOnly.features)
        #expect(estimate.value == estimator.params.timeOnly.probability(row))
    }

    @Test func noReferenceOrNoRecentHeartRateGivesTheTimeOnlyMode() throws {
        let estimator = try StateEstimator.bundled()
        for name in ["short_history", "watch_off_last_hour", "constant_heart_rate"] {
            let fixture = try StateFixtures.named(name)
            let estimate = try estimator.estimate(features(fixture))
            #expect(estimate.mode == .timeOnly, "\(name)")
            expectClose(estimate.value, fixture.timeOnlyProbability, name)
        }
    }

    @Test func heartRateComparedWithTheReferenceGivesTheBodyMode() throws {
        let estimator = try StateEstimator.bundled()
        for name in ["weekday_afternoon", "early_night", "night_unknown"] {
            let fixture = try StateFixtures.named(name)
            let estimate = try estimator.estimate(features(fixture))
            #expect(estimate.mode == .body, "\(name)")
            expectClose(estimate.value, fixture.probability, name)
        }
    }
}
