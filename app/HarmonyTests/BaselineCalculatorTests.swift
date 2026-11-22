import Foundation
import Testing
@testable import Harmony

/// TODO 2.18: window values and personal references of PROJECT.md §6 « Features v1 ».
private let calendar = StateFixtures.calendar

/// `day` of November 2026 at `hour:minute:second`, Seoul time.
private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
}

@MainActor
private func reading(_ date: Date, _ value: Double) -> HealthSample {
    HealthSample(start: date, end: date, value: value)
}

/// A heart rate every 5 minutes from `first` to `last` day (whole days), value `value(i)`.
@MainActor
private func heartRate(days first: Int, _ last: Int, value: (Int) -> Double) -> [HealthSample] {
    let start = date(first, 0)
    let count = (last - first + 1) * 288
    return (0..<count).map { reading(start.addingTimeInterval(Double($0) * 300), value($0)) }
}

@MainActor
struct WatchSeriesTests {
    @Test func keepsTheFirstHeartRateOfEachFiveMinuteSlice() {
        let raw = [
            reading(date(3, 10, 6), 90),          // unsorted input
            reading(date(3, 10, 0), 70),
            reading(date(3, 10, 0), 72),          // same instant: the first one given wins
            reading(date(3, 10, 4, 59), 71),
            reading(date(3, 10, 5), 80),
        ]
        let series = WatchSeries(heartRate: raw, steps: [])
        #expect(series.heartRate == [reading(date(3, 10, 0), 70), reading(date(3, 10, 5), 80)])
    }

    @Test func windowHoldsTheMinutesAfterTMinusWUpToT() throws {
        let t = date(3, 12)
        let series = WatchSeries(heartRate: [
            reading(t.addingTimeInterval(-15 * 60), 100),     // t − 15 min: outside (t − 15, t]
            reading(t.addingTimeInterval(-10 * 60), 60),
            reading(t, 70),                                   // t itself is inside
            reading(t.addingTimeInterval(5 * 60), 200),       // after t: never used
        ], steps: [])
        let values = series.values(at: t)
        #expect(values[.hr15] == 65)
        #expect(values[.hr30] == 230.0 / 3)                 // 100, 60 and 70
    }

    @Test func stepsAreZeroWhenWornAndUnknownWithoutAnyData() throws {
        let t = date(3, 12)
        let worn = WatchSeries(heartRate: [reading(t.addingTimeInterval(-5 * 60), 70)], steps: [])
        #expect(worn.values(at: t)[.logSteps15] == 0)

        let nothing = WatchSeries(heartRate: [], steps: [])
        #expect(nothing.values(at: t).isEmpty)

        let stepsOnly = WatchSeries(heartRate: [], steps: [
            reading(t.addingTimeInterval(-20 * 60), 30), reading(t.addingTimeInterval(-5 * 60), 10),
        ])
        let values = stepsOnly.values(at: t)
        #expect(values[.logSteps15] == log1p(10))
        #expect(values[.logSteps30] == log1p(40))
        #expect(values[.hr15] == nil)
    }
}

@MainActor
struct BaselineCalculatorTests {
    @Test func gridRunsEveryHalfHourFromEightInTheFourteenDaysBeforeT() {
        let t = date(15, 10)
        let grid = BaselineCalculator.gridPoints(before: t, calendar: calendar)
        #expect(grid.first == date(1, 10))                  // t − 14 days is included
        #expect(grid.last == date(15, 9, 30))               // t is not
        #expect(grid.count == 448)                          // 28 on day 1, 13 × 32, 4 on day 15
        #expect(!grid.contains(date(5, 7, 30)) && grid.contains(date(5, 23, 30)))
    }

    @Test func referenceNeedsSevenDistinctDays() throws {
        let days = (1...7).map { date($0, 0) }
        let six = [1.0, 2, 3, 4, 5, 6, 7].enumerated().map { (value: $1, day: days[min($0, 5)]) }
        #expect(BaselineCalculator.reference(six, minDays: 7) == nil)

        let seven = [1.0, 2, 3, 4, 5, 6, 7].enumerated().map { (value: $1, day: days[$0]) }
        let reference = try #require(BaselineCalculator.reference(seven, minDays: 7))
        #expect(reference.mean == 4)
        #expect(abs(reference.std - (28.0 / 6).squareRoot()) < 1e-12)     // n − 1
    }

    @Test func zScoreIsUnknownWithoutValueOrSpread() {
        #expect(Reference(mean: 70, std: 5).z(80) == 2)
        #expect(Reference(mean: 70, std: 5).z(nil) == nil)
        #expect(Reference(mean: 70, std: 0).z(80) == nil)
    }

    @Test func baselineIsUnknownBeforeSevenDays() {
        let series = WatchSeries(heartRate: heartRate(days: 1, 7) { 60 + Double($0 % 17) }, steps: [])
        let ready = BaselineCalculator.baseline(at: date(7, 12), series: series, calendar: calendar)
        #expect(ready.references[.hr30] != nil)              // grid points on days 1…7

        let early = BaselineCalculator.baseline(at: date(7, 8), series: series, calendar: calendar)
        #expect(early.references[.hr30] == nil)              // no grid point yet on day 7: 6 days
    }

    @Test func baselineNeverUsesDataAtOrAfterT() {
        let t = date(12, 15)
        let past = heartRate(days: 1, 11) { 60 + Double($0 % 23) }
        let before = BaselineCalculator.baseline(at: t, series: WatchSeries(heartRate: past, steps: []),
                                                 calendar: calendar)
        let future = [reading(t, 190), reading(t.addingTimeInterval(600), 180)]
        let after = BaselineCalculator.baseline(at: t, series: WatchSeries(heartRate: past + future, steps: []),
                                                calendar: calendar)
        #expect(before == after)
        #expect(before.references[.hr30] != nil)
    }

    @Test func blockOfTheDayIsThreeHours() {
        #expect(BaselineCalculator.block(of: date(3, 2, 59), calendar: calendar) == 0)
        #expect(BaselineCalculator.block(of: date(3, 8, 30), calendar: calendar) == 2)
        #expect(BaselineCalculator.block(of: date(3, 23, 30), calendar: calendar) == 7)
    }

    /// Golden check against Python: the 6 window z-scores and zb_hr_30 of the 10 fixtures.
    @Test func zScoresMatchTheGoldenFixtures() throws {
        let fixtures = try StateFixtures.load()
        let names: [(String, WindowQuantity)] = [
            ("z_hr_15", .hr15), ("z_hr_30", .hr30), ("z_hr_60", .hr60),
            ("z_log_steps_15", .logSteps15), ("z_log_steps_30", .logSteps30), ("z_log_steps_60", .logSteps60),
        ]
        for fixture in fixtures.cases {
            let series = WatchSeries(heartRate: fixture.heartRate, steps: fixture.stepSamples)
            let baseline = BaselineCalculator.baseline(at: fixture.answer, series: series, calendar: calendar)
            let now = series.values(at: fixture.answer)
            var got = Dictionary(uniqueKeysWithValues: names.map { ($0.0, baseline.z($0.1, now[$0.1])) })
            got["zb_hr_30"] = baseline.zBlock(now[.hr30], block: BaselineCalculator.block(of: fixture.answer, calendar: calendar))
            for (name, value) in got {
                expectClose(value, fixture.expected(name), "\(fixture.name) \(name)")
            }
        }
    }
}

/// Same value within 1e-6, or both unknown (PROJECT.md §6.7).
func expectClose(_ got: Double?, _ want: Double?, _ label: String,
                 sourceLocation: SourceLocation = #_sourceLocation) {
    switch (got, want) {
    case (nil, nil):
        break
    case let (got?, want?):
        #expect(abs(got - want) < 1e-6, "\(label): \(got) vs \(want)", sourceLocation: sourceLocation)
    default:
        Issue.record("\(label): \(String(describing: got)) vs \(String(describing: want))", sourceLocation: sourceLocation)
    }
}
