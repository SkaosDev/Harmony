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
