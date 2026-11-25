import Foundation
import Testing
@testable import Harmony

/// TODO 6.11: the rank `e0` against `ml/fixtures/rank_cases.json` (the rank rule, exact) and
/// `rank_grid_cases.json` (made by `ml/make_rank_fixtures.py`: the grid rows scored with the
/// reference of the prediction instant, within 1e-6; e0 exact).
@MainActor
struct PersonalRankTests {
    private struct RankCases: Decodable {
        let cases: [Case]
        struct Case: Decodable {
            let name: String
            let probability: Double
            /// [probability, count]
            let grid: [[Double]]
            let expected: Double
        }
    }

    private struct GridCases: Decodable {
        let quantities: [String]
        let features: [String]
        let rankMinimumRows: Int
        let cases: [Case]

        struct Case: Decodable {
            let name: String
            let originMs: Int64
            let tMinute: Int
            /// [minute, then the 6 quantities]; nil = unknown.
            let grid: [[Double?]]
            let nights: [Night]
            /// [minute, then the 17 features]
            let rows: [[Double?]]
            let rowProbabilities: [Double]
            let probability: Double
            let e0: Double

            func date(_ minute: Double) -> Date {
                Date(timeIntervalSince1970: Double(originMs) / 1000 + minute * 60)
            }
        }

        /// `day` and `wake_minute` count local days and minutes since 1970-01-01 (Korea).
        struct Night: Decodable {
            let day: Int
            let sleepMin: Double?
            let wakeMinute: Double?
        }
    }

    private func load<T: Decodable>(_ name: String) throws -> T {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }

    @Test func rankRuleMatchesPython() throws {
        let cases: RankCases = try load("rank_cases")
        #expect(cases.cases.count == 5)
        for item in cases.cases {
            let grid = item.grid.flatMap { Array(repeating: $0[0], count: Int($0[1])) }
            #expect(PersonalRank.e0(probability: item.probability, grid: grid) == item.expected, "\(item.name)")
        }
    }

    @Test func gridRowsAndRankMatchPython() throws {
        let fixture: GridCases = try load("rank_grid_cases")
        #expect(fixture.quantities == WindowQuantity.allCases.map(\.rawValue))
        #expect(fixture.rankMinimumRows == PersonalRank.minimumRows)
        let estimator = try StateEstimator.bundled()
        #expect(fixture.features == estimator.params.features)
        let calendar = StateFixtures.calendar
        let koreaSeconds = 9.0 * 3600

        for item in fixture.cases {
            let t = item.date(Double(item.tMinute))
            let start = t - Double(BaselineCalculator.referenceDays) * 86400
            // The fixture grid has points outside [t − 14 days, t) on purpose.
            let grid = item.grid.compactMap { point -> GridPoint? in
                let time = item.date(point[0]!)
                guard time >= start && time < t else { return nil }
                var values: [WindowQuantity: Double] = [:]
                for (quantity, value) in zip(WindowQuantity.allCases, point.dropFirst()) {
                    values[quantity] = value
                }
                return GridPoint(time: time, values: values)
            }
            let nights = item.nights.map { night in
                NightSummary(date: Date(timeIntervalSince1970: Double(night.day) * 86400 - koreaSeconds),
                             sleepMinutes: night.sleepMin,
                             sleepEnd: night.wakeMinute.map { Date(timeIntervalSince1970: $0 * 60 - koreaSeconds) },
                             wornFraction: night.sleepMin == nil ? 0 : 1)
            }
            let rows = PersonalRank.rows(
                grid: grid, baseline: BaselineCalculator.baseline(grid: grid, calendar: calendar),
                sleepReference: FeatureBuilder.sleepReference(at: t, nights: nights, calendar: calendar),
                nights: nights, calendar: calendar)

            #expect(rows.count == item.rows.count, "\(item.name)")
            for (row, expected) in zip(rows, item.rows) {
                #expect(row.time == item.date(expected[0]!), "\(item.name)")
                for (name, value) in zip(fixture.features, expected.dropFirst()) {
                    expectClose(row.features[name] ?? nil, value, "\(item.name) \(name)")
                }
            }
            let probabilities = try rows.map { try estimator.gridProbability($0.features) }
            for (got, want) in zip(probabilities, item.rowProbabilities) {
                expectClose(got, want, "\(item.name) probability")
            }
            #expect(PersonalRank.e0(probability: item.probability, grid: probabilities) == item.e0, "\(item.name)")
        }
    }
}

private final class BundleToken {}
