import Foundation
import Testing
@testable import Harmony

/// TODO 6.8: the personal layer against `ml/fixtures/personal_layer_cases.json` (TODO 6.5, made by
/// `ml/make_personal_fixtures.py` with `ml/personal_layer.py`): offsets and probabilities within
/// 1e-6, counts and labels exact.
@MainActor
struct PersonalLayerTests {
    private struct Fixture: Decodable {
        let decayDays: Double
        let priorStd: Double
        let minimumPastResponses: Int
        let newtonSteps: Int
        let cases: [Case]
    }

    private struct Case: Decodable {
        let name: String
        let now: Date
        let zEnergy: Double?
        let observations: [Observation]?
        let offset: Double?
        let probability: Double?
        let usableLabelledCount: Int?
        let energy: Int?
        let priorResponses: [Observation]?
        let label: Bool?
    }

    private struct Observation: Decodable {
        let answeredAt: Date
        let energy: Int
        let zEnergy: Double
        let label: Bool?
        let usable: Bool

        var personal: PersonalObservation {
            PersonalObservation(answeredAt: answeredAt, value: energy, z: zEnergy, label: label, usable: usable)
        }
    }

    private func fixture() throws -> Fixture {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "personal_layer_cases", withExtension: "json"))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Fixture.self, from: Data(contentsOf: url))
    }

    @Test func constantsMatchTheSimulation() throws {
        let fixture = try fixture()
        #expect(fixture.decayDays == PersonalLayer.decayDays)
        #expect(fixture.priorStd == PersonalLayer.energyPriorStd)
        #expect(fixture.minimumPastResponses == PersonalLayer.minimumPastAnswers)
        #expect(fixture.newtonSteps == PersonalLayer.newtonSteps)
    }

    @Test func offsetsMatchPython() throws {
        let cases = try fixture().cases.filter { $0.observations != nil }
        #expect(cases.count == 5)
        for item in cases {
            let estimate = PersonalLayer.estimate(now: item.now, z: try #require(item.zEnergy),
                                                  observations: item.observations!.map(\.personal))
            expectClose(estimate.offset, item.offset, "\(item.name) offset")
            expectClose(estimate.probability, item.probability, "\(item.name) probability")
            #expect(estimate.count == item.usableLabelledCount, "\(item.name)")
        }
    }

    @Test func labelsMatchPython() throws {
        let cases = try fixture().cases.filter { $0.priorResponses != nil }
        #expect(cases.count == 2)
        for item in cases {
            let prior = item.priorResponses!.map { (answeredAt: $0.answeredAt, value: $0.energy) }
            #expect(PersonalLayer.pastLabel(at: item.now, value: try #require(item.energy), prior: prior) == item.label,
                    "\(item.name)")
        }
    }

    /// No answer: b = 0 exactly, the common model (design v2 G1).
    @Test func noAnswerIsTheCommonModel() {
        let estimate = PersonalLayer.estimate(now: .now, z: -0.3, observations: [])
        #expect(estimate.offset == 0 && estimate.count == 0)
        #expect(estimate.probability == PersonalLayer.sigmoid(-0.3))
    }

    /// Fewer than 5 earlier answers: no label; equal to the mean: not above.
    @Test func labelNeedsFiveEarlierAnswersAndStrictlyAbove() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let four = (1...4).map { (answeredAt: now - Double($0) * 3600, value: 0) }
        #expect(PersonalLayer.pastLabel(at: now, value: 3, prior: four) == nil)
        let five = four + [(answeredAt: now - 5 * 3600, value: 0)]
        #expect(PersonalLayer.pastLabel(at: now, value: 0, prior: five) == false)
        #expect(PersonalLayer.pastLabel(at: now, value: 1, prior: five) == true)
    }
}

private final class BundleToken {}
