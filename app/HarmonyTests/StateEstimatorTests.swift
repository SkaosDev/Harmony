import Foundation
import Testing
@testable import Harmony

/// TODO 2.20, 6.4: the Core ML model gives the probabilities Python expects.
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
        let count = estimator.params.features.count
        let unknown: [Double?] = Array(repeating: nil, count: count)
        let zeros: [Double?] = Array(repeating: 0, count: count)
        #expect(try estimator.modelProbability(unknown) != estimator.modelProbability(zeros))
    }

    /// TODO 6.4: the valence models (internal, never shown) match Python too.
    @Test func valenceModelsMatchTheGoldenFixtures() throws {
        let params = try ModelParams.bundled()
        let valence = try #require(params.valence)
        let valenceTimeOnly = try #require(params.valenceTimeOnly)
        #expect(valence.features == params.features)
        #expect(valenceTimeOnly.features == ["hour_sin", "hour_cos", "weekend"])
        for fixture in try StateFixtures.load().cases {
            expectClose(valence.probability(valence.features.map { fixture.expected($0) }),
                        fixture.valenceProbability, "\(fixture.name) valence")
            expectClose(valenceTimeOnly.probability(valenceTimeOnly.features.map { fixture.expected($0) }),
                        fixture.valenceTimeOnlyProbability, "\(fixture.name) valence time only")
        }
    }
}

/// TODO 2.21, 6.4: time-only mode (`prior(hour)` of the report) without a heart rate in the last
/// 30 min; with one, the model even before the 7-day reference (v3 rule, PROJECT.md §6.8).
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

    @Test func noRecentHeartRateGivesTheTimeOnlyMode() throws {
        let estimator = try StateEstimator.bundled()
        let fixture = try StateFixtures.named("watch_off_last_hour")
        let estimate = try estimator.estimate(features(fixture))
        #expect(estimate.mode == .timeOnly)
        expectClose(estimate.value, fixture.timeOnlyProbability, fixture.name)
        expectClose(estimate.valence, fixture.valenceTimeOnlyProbability, "\(fixture.name) valence")
    }

    @Test func recentHeartRateGivesTheBodyModeEvenWithoutAReference() throws {
        let estimator = try StateEstimator.bundled()
        for name in ["weekday_afternoon", "early_night", "night_unknown", "short_history", "constant_heart_rate"] {
            let fixture = try StateFixtures.named(name)
            let estimate = try estimator.estimate(features(fixture))
            #expect(estimate.mode == .body, "\(name)")
            expectClose(estimate.value, fixture.probability, name)
            expectClose(estimate.valence, fixture.valenceProbability, "\(name) valence")
        }
    }
}
