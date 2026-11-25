import Foundation
import Testing
@testable import Harmony

/// The golden cases of `ml/fixtures/state_cases.json` (TODO 2.17), written by
/// `ml/make_fixtures.py`: synthetic series, the 17 features and the probabilities Python expects.
/// The file stays in `ml/fixtures`; the HarmonyTests target copies it into the test bundle, so
/// the tests also run on an iPhone. Times are minutes since `origin_ms`; local time is Korea.
struct StateFixtures: Decodable {
    let modelVersion: Int
    let features: [String]
    let cases: [Case]

    enum CodingKeys: String, CodingKey {
        case features, cases, modelVersion = "model_version"
    }

    /// Korea has no daylight-saving time: the same local time as UTC+9 in Python.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    static func load() throws -> StateFixtures {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "state_cases", withExtension: "json"))
        return try JSONDecoder().decode(StateFixtures.self, from: Data(contentsOf: url))
    }

    static func named(_ name: String) throws -> Case {
        try #require(load().cases.first { $0.name == name })
    }

    struct Case: Decodable {
        let name: String
        let originMs: Int64
        let answerMinute: Int
        let hr: [[Int]]
        let steps: [[Int]]
        let nights: [Night]
        let answerNight: NightValues
        /// Expected features; nil = unknown.
        let features: [String: Double?]
        let probability: Double
        let timeOnlyProbability: Double
        /// v3 (TODO 6.4): the valence model and its time-of-day model.
        let valenceProbability: Double?
        let valenceTimeOnlyProbability: Double?

        /// A full night of the 14 previous days: `day` and `wake_minute` count local days and
        /// minutes since 1970-01-01.
        struct Night: Decodable {
            let day: Int
            let sleepMin: Double?
            let wakeMinute: Double?

            enum CodingKeys: String, CodingKey {
                case day, sleepMin = "sleep_min", wakeMinute = "wake_minute"
            }
        }

        /// The night of the answer day, cut at the answer before 12:00.
        struct NightValues: Decodable {
            let sleepMin: Double?
            let wakeMinute: Double?

            enum CodingKeys: String, CodingKey {
                case sleepMin = "sleep_min", wakeMinute = "wake_minute"
            }
        }

        enum CodingKeys: String, CodingKey {
            case name, hr, steps, nights, features, probability
            case originMs = "origin_ms", answerMinute = "answer_minute", answerNight = "answer_night"
            case timeOnlyProbability = "time_only_probability"
            case valenceProbability = "valence_probability"
            case valenceTimeOnlyProbability = "valence_time_only_probability"
        }

        @MainActor var answer: Date { date(minute: answerMinute) }
        @MainActor var heartRate: [HealthSample] { hr.map { point(date(minute: $0[0]), $0[1]) } }
        @MainActor var stepSamples: [HealthSample] { steps.map { point(date(minute: $0[0]), $0[1]) } }

        /// The nights as the app holds them: the answer night and the full nights before it.
        /// `wornFraction` is not in the fixtures (the features do not use it).
        @MainActor var nightSummaries: [NightSummary] {
            let previous = nights.map { summary(day: $0.day, sleep: $0.sleepMin, wake: $0.wakeMinute) }
            let today = summary(day: Self.localDay(answer), sleep: answerNight.sleepMin,
                                wake: answerNight.wakeMinute)
            return previous + [today]
        }

        /// One asleep interval per known night, ending at its wake-up and lasting its sleep minutes:
        /// read by `HealthSummaries.night`, it gives back the fixture nights.
        @MainActor var sleepSamples: [HealthSample] {
            nightSummaries.compactMap { night in
                guard let minutes = night.sleepMinutes, let end = night.sleepEnd else { return nil }
                return HealthSample(start: end.addingTimeInterval(-minutes * 60), end: end, value: 1)
            }
        }

        /// Expected value of one feature, nil when unknown.
        func expected(_ name: String) -> Double? { features[name] ?? nil }

        private func date(minute: Int) -> Date {
            Date(timeIntervalSince1970: Double(originMs) / 1000 + Double(minute) * 60)
        }

        @MainActor private func point(_ date: Date, _ value: Int) -> HealthSample {
            HealthSample(start: date, end: date, value: Double(value))
        }

        @MainActor private func summary(day: Int, sleep: Double?, wake: Double?) -> NightSummary {
            NightSummary(date: Self.localDate(minute: Double(day * 1440)), sleepMinutes: sleep,
                         sleepEnd: wake.map(Self.localDate(minute:)), wornFraction: sleep == nil ? 0 : 1)
        }

        private static let koreaSeconds = 9.0 * 3600

        private static func localDate(minute: Double) -> Date {
            Date(timeIntervalSince1970: minute * 60 - koreaSeconds)
        }

        private static func localDay(_ date: Date) -> Int {
            Int(((date.timeIntervalSince1970 + koreaSeconds) / 86400).rounded(.down))
        }
    }
}

private final class BundleToken {}
