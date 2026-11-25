import Foundation
import Testing
@testable import Harmony

/// TODO 2.19, 6.4: the 17 features v3 of PROJECT.md §6 and §6.8, in the order of `model_params.json`.
private let calendar = StateFixtures.calendar

/// `day` of November 2026 at `hour:minute:second`, Seoul time (Nov 21 is a Saturday).
private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
}

@MainActor
private func features(at t: Date, nights: [NightSummary] = []) -> [String: Double?] {
    FeatureBuilder.features(at: t, series: WatchSeries(heartRate: [], steps: []), nights: nights, calendar: calendar)
}

@MainActor
private func night(_ day: Int, minutes: Double?, end: Date? = nil) -> NightSummary {
    NightSummary(date: date(day, 0), sleepMinutes: minutes, sleepEnd: minutes == nil ? nil : end ?? date(day, 7),
                 wornFraction: minutes == nil ? 0 : 1)
}

@MainActor
struct FeatureBuilderTests {
    @Test func hourIsLocalHourAndMinutesOnTheClock() throws {
        let six = features(at: date(18, 6, 0, 40))                     // seconds are ignored
        #expect(abs(try #require(six["hour_sin"] ?? nil) - 1) < 1e-12)
        #expect(abs(try #require(six["hour_cos"] ?? nil)) < 1e-12)
        let half = features(at: date(18, 13, 30))
        #expect(abs(try #require(half["hour_sin"] ?? nil) - sin(2 * .pi * 13.5 / 24)) < 1e-12)
    }

    @Test func weekendIsSaturdayAndSunday() {
        #expect(features(at: date(20, 12))["weekend"] == 0)              // Friday
        #expect(features(at: date(21, 12))["weekend"] == 1)              // Saturday
        #expect(features(at: date(22, 12))["weekend"] == 1)              // Sunday
        #expect(features(at: date(23, 0, 30))["weekend"] == 0)           // Monday
    }

    @Test func noWatchDataIsUnknownNeverZero() {
        let empty = features(at: date(18, 15))
        #expect(empty.count == 17)
        for name in ["z_hr_15", "z_hr_30", "z_hr_60", "zb_hr_30", "z_log_steps_15", "z_log_steps_30",
                     "z_log_steps_60", "z_sleep_min", "hours_since_wake",
                     "raw_hr_30", "raw_hr_60", "raw_log_steps_30", "raw_log_steps_60"] {
            #expect(empty[name] == .some(nil), "\(name)")
        }
        #expect(empty["sleep_unknown"] == 1)
    }

    @Test func sleepScoreNeedsFiveKnownNightsBefore() throws {
        let t = date(18, 15)
        let today = night(18, minutes: 450, end: date(18, 7, 10))
        let four = [400.0, 440, 380, 460].enumerated().map { night(13 + $0, minutes: $1) }
        #expect(features(at: t, nights: four + [today])["z_sleep_min"] == .some(nil))

        let five = four + [night(17, minutes: 420), night(12, minutes: nil)]   // unknown nights do not count
        let known = features(at: t, nights: five + [today])
        let z = try #require(known["z_sleep_min"] ?? nil)
        let values = [400.0, 440, 380, 460, 420]
        let mean = values.reduce(0, +) / 5
        let std = (values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / 4).squareRoot()
        #expect(abs(z - (450 - mean) / std) < 1e-12)
        let hours = try #require(known["hours_since_wake"] ?? nil)
        #expect(abs(hours - 470.0 / 60) < 1e-12)                       // 07:10 → 15:00
        #expect(known["sleep_unknown"] == 0)
    }

    @Test func nightsFourteenDaysOldOrMoreAreLeftOut() {
        let t = date(18, 15)
        let old = [3, 4].map { night($0, minutes: 300) }            // day 3 is t − 15 days, 4 is t − 14
        let recent = [400.0, 440, 380, 460].enumerated().map { night(13 + $0, minutes: $1) }
        let result = features(at: t, nights: old + recent + [night(18, minutes: 420)])
        #expect(result["z_sleep_min"] != .some(nil))                     // day 4 + 4 recent = 5 nights
        let withoutDay4 = features(at: t, nights: [old[0]] + recent + [night(18, minutes: 420)])
        #expect(withoutDay4["z_sleep_min"] == .some(nil))
    }

    @Test func rowFollowsTheGivenOrderAndRefusesUnknownNames() throws {
        let values: [String: Double?] = ["a": 1, "b": nil]
        #expect(try FeatureBuilder.row(values, order: ["b", "a"]) == [nil, 1])
        #expect(throws: FeatureBuilder.UnknownFeature.self) { try FeatureBuilder.row(values, order: ["c"]) }
    }

    @Test func bundledParamsListTheSeventeenFeaturesOfTheFixtures() throws {
        let params = try ModelParams.bundled()
        let fixtures = try StateFixtures.load()
        #expect(params.version == 3)
        #expect(fixtures.modelVersion == params.version)
        #expect(params.features == fixtures.features)
        #expect(params.features.count == 17)
        #expect(params.features.suffix(4) == ["raw_hr_30", "raw_hr_60", "raw_log_steps_30", "raw_log_steps_60"])
    }

    /// Golden check against Python: the 17 features of the 10 fixtures, in model order.
    @Test func featuresMatchTheGoldenFixtures() throws {
        let fixtures = try StateFixtures.load()
        let order = try ModelParams.bundled().features
        for fixture in fixtures.cases {
            let series = WatchSeries(heartRate: fixture.heartRate, steps: fixture.stepSamples)
            let values = FeatureBuilder.features(at: fixture.answer, series: series,
                                                 nights: fixture.nightSummaries, calendar: calendar)
            let row = try FeatureBuilder.row(values, order: order)
            for (name, value) in zip(order, row) {
                expectClose(value, fixture.expected(name), "\(fixture.name) \(name)")
            }
        }
    }
}
