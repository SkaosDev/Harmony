import Foundation
import Testing
@testable import Harmony

/// Shared by the summary tests: a fixed time zone, so they do not depend on the machine.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()

/// `day` of November 2026 at `hour:minute`, Seoul time.
private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

/// One heart rate every `minutes` from `start` (included) to `end` (excluded).
private func heartRate(every minutes: Int = 5, from start: Date, to end: Date, bpm: Double = 60) -> [HealthSample] {
    stride(from: start, to: end, by: TimeInterval(minutes * 60)).map { HealthSample(start: $0, end: $0, value: bpm) }
}

private func instant(_ date: Date, _ value: Double) -> HealthSample {
    HealthSample(start: date, end: date, value: value)
}

private func interval(_ start: Date, _ end: Date, _ value: Double = 1) -> HealthSample {
    HealthSample(start: start, end: end, value: value)
}

/// TODO 1.32: hourly summaries.
@MainActor
struct HourSummariesTests {
    private func hours(heartRate: [HealthSample] = [], steps: [HealthSample] = [], hrv: [HealthSample] = [],
                       from: Date = at(10, 0)) -> [HourSummary] {
        HealthSummaries.hours(heartRate: heartRate, steps: steps, hrv: hrv, from: from, calendar: calendar)
    }

    @Test func averagesHeartRateAndHRVOverTheHour() throws {
        let summaries = hours(
            heartRate: [instant(at(10, 10, 5), 60), instant(at(10, 10, 20), 70), instant(at(10, 10, 50), 80)],
            hrv: [instant(at(10, 10, 30), 40), instant(at(10, 10, 40), 50)]
        )
        let hour = try #require(summaries.first)
        #expect(summaries.count == 1)
        #expect(hour.hourStart == at(10, 10))
        #expect(hour.meanHR == 70)
        #expect(hour.hrCount == 3)
        #expect(hour.sdnnHRV == 45)
        // Worn (heart rate) without any step: 0 steps, known.
        #expect(hour.steps == 0)
    }

    @Test func stepsAreSharedBetweenHoursByOverlap() {
        let summaries = hours(
            heartRate: [instant(at(10, 10, 10), 60), instant(at(10, 11, 30), 60)],
            steps: [interval(at(10, 10, 50), at(10, 11, 10), 100)]
        )
        #expect(summaries.map(\.hourStart) == [at(10, 10), at(10, 11)])
        #expect(summaries.map(\.steps) == [50, 50])
    }

    /// Unknown is not zero: an hour without heart rate or steps is not stored, and an hour with
    /// only an HRV reading has unknown steps.
    @Test func hoursWithoutWatchDataStayUnknown() throws {
        let summaries = hours(
            heartRate: [instant(at(10, 10, 15), 60)],
            hrv: [instant(at(10, 12, 15), 50)]
        )
        try #require(summaries.map(\.hourStart) == [at(10, 10), at(10, 12)])
        #expect(summaries[1].meanHR == nil)
        #expect(summaries[1].hrCount == 0)
        #expect(summaries[1].steps == nil)
    }

    /// A step interval begun before `from` must not create a partial hour before it.
    @Test func hoursBeforeTheStartAreLeftOut() {
        let summaries = hours(steps: [interval(at(10, 9, 50), at(10, 10, 10), 100)], from: at(10, 10))
        #expect(summaries.map(\.hourStart) == [at(10, 10)])
        #expect(summaries.map(\.steps) == [50])
    }
}

/// TODO 1.31, 1.32: nightly summaries, window 21:00 → 12:00 (PROJECT.md §10).
@MainActor
struct NightSummariesTests {
    /// The night ending on 11 November: 10 Nov 21:00 → 11 Nov 12:00.
    private let wakeDay = at(11, 0)
    private var fullHeartRate: [HealthSample] { heartRate(from: at(10, 21), to: at(11, 12)) }

    private func night(heartRate: [HealthSample], sleep: [HealthSample], now: Date = at(11, 15)) -> NightSummary? {
        HealthSummaries.night(wakeDay: wakeDay, heartRate: heartRate, sleep: sleep, now: now, calendar: calendar)
    }

    @Test func windowRunsFrom21To12() {
        let window = HealthSummaries.nightWindow(wakeDay: wakeDay, calendar: calendar)
        #expect(window.start == at(10, 21))
        #expect(window.end == at(11, 12))
    }

    /// Like the Health app: every asleep interval counts, even after a 45-min wake-up, and
    /// overlapping intervals are counted once.
    @Test func addsAsleepIntervalsLikeHealth() throws {
        let summary = try #require(night(heartRate: fullHeartRate, sleep: [
            interval(at(10, 23), at(11, 3)),
            interval(at(11, 2), at(11, 2, 30)),
            interval(at(11, 3, 45), at(11, 7)),
        ]))
        #expect(summary.date == wakeDay)
        #expect(summary.sleepMinutes == 435)  // 240 + 195
        #expect(summary.sleepEnd == at(11, 7))
        #expect(summary.wornFraction == 1)
    }

    @Test func sleepBeforeTheWindowIsCutAt21() throws {
        let summary = try #require(night(heartRate: fullHeartRate, sleep: [interval(at(10, 20, 30), at(10, 23))]))
        #expect(summary.sleepMinutes == 120)
    }

    /// Heart rate on 8 h of the 15 h window (53 %): watch not worn enough, sleep unknown.
    @Test func nightWithLittleHeartRateIsUnknown() throws {
        let summary = try #require(night(
            heartRate: heartRate(from: at(10, 21), to: at(11, 5)),
            sleep: [interval(at(10, 23), at(11, 5))]
        ))
        #expect(summary.sleepMinutes == nil)
        #expect(summary.sleepEnd == nil)
        #expect(abs(summary.wornFraction - 8.0 / 15) < 1e-9)
    }

    /// Unknown is not zero: watch worn all night but no asleep sample (sleep tracking off).
    @Test func nightWithoutAsleepSampleIsUnknownNotZero() throws {
        let summary = try #require(night(heartRate: fullHeartRate, sleep: []))
        #expect(summary.sleepMinutes == nil)
        #expect(summary.sleepEnd == nil)
        #expect(summary.wornFraction == 1)
    }

    /// At 07:00 the window is not over: coverage counts the elapsed part only, so a morning
    /// queue still knows last night.
    @Test func morningUsesTheElapsedPartOfTheWindow() throws {
        let summary = try #require(night(
            heartRate: heartRate(from: at(10, 21), to: at(11, 7)),
            sleep: [interval(at(10, 23), at(11, 6, 30))],
            now: at(11, 7)
        ))
        #expect(summary.wornFraction == 1)
        #expect(summary.sleepMinutes == 450)
        #expect(summary.sleepEnd == at(11, 6, 30))
    }

    /// Coverage is measured in 5-min slots: one reading every 10 min covers half of them.
    @Test func coverageCountsSlotsWithAReading() throws {
        let summary = try #require(night(heartRate: heartRate(every: 10, from: at(10, 21), to: at(11, 12)), sleep: []))
        #expect(summary.wornFraction == 0.5)
        let wide = try #require(HealthSummaries.night(
            wakeDay: wakeDay, heartRate: heartRate(every: 10, from: at(10, 21), to: at(11, 12)), sleep: [],
            now: at(11, 15), calendar: calendar, slotMinutes: 15
        ))
        #expect(wide.wornFraction == 1)
    }

    @Test func nightNotStartedYetIsNil() {
        #expect(night(heartRate: [], sleep: [], now: at(10, 20)) == nil)
    }

    @Test func wakeDaysTouchingAPeriod() {
        func days(_ start: Date, _ end: Date) -> [Date] {
            HealthSummaries.wakeDays(touching: start, end, calendar: calendar)
        }
        #expect(days(at(10, 22), at(11, 8)) == [at(11, 0)])
        #expect(days(at(10, 10), at(10, 11)) == [at(10, 0)])
        #expect(days(at(10, 13), at(10, 15)) == [])
        #expect(days(at(10, 10), at(11, 22)) == [at(10, 0), at(11, 0), at(12, 0)])
    }
}

/// TODO 1.33: the Debug measure of how often the watch reads the heart rate.
@MainActor
struct HeartRateIntervalTests {
    @Test func medianIntervalByTimeOfDay() throws {
        // Night: every 5 min from 01:00 to 02:00. Day: 10:00, 10:04, 10:10, 10:30.
        let night = heartRate(every: 5, from: at(10, 1), to: at(10, 2))
        let day = [at(10, 10), at(10, 10, 4), at(10, 10, 10), at(10, 10, 30)].map { instant($0, 70) }
        let samples = night + day

        let atNight = try #require(HealthDebugSection.medianInterval(samples, hours: 0..<6, calendar: calendar))
        #expect(atNight.minutes == 5)
        #expect(atNight.count == 12)  // the last one runs to 10:00
        let byDay = try #require(HealthDebugSection.medianInterval(samples, hours: 8..<24, calendar: calendar))
        #expect(byDay.minutes == 6)  // 4, 6, 20
        #expect(byDay.count == 3)
        #expect(HealthDebugSection.medianInterval([], hours: 0..<24, calendar: calendar) == nil)
    }
}
