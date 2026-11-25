import Foundation
import Testing
@testable import Harmony

/// TODO 6.10: when the questions are asked (design v2 §5.3), with fixed draws.
@MainActor
struct CheckInScheduleTests {
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private let calendar = StateFixtures.calendar

    private func at(day: Int = 1, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 12, day: day, hour: hour, minute: minute))!
    }

    private func minutes(_ date: Date) -> Int {
        let clock = calendar.dateComponents([.hour, .minute], from: date)
        return clock.hour! * 60 + clock.minute!
    }

    private func times(now: Date, windows: [CheckInWindow] = CheckInSchedule.defaultWindows, asked: [Date] = [],
                       quietUntil: Date? = nil, seed: UInt64) -> [Date] {
        var rng = SeededGenerator(state: seed)
        return CheckInSchedule.times(now: now, windows: windows, asked: asked, quietUntil: quietUntil,
                                     calendar: calendar, using: &rng)
    }

    @Test func oneQuestionInEachWindowForThreeDays() {
        for seed in 0..<200 as Range<UInt64> {
            let planned = times(now: at(7), seed: seed)
            #expect(planned.count == 6)
            #expect(planned == planned.sorted())
            for (index, time) in planned.enumerated() {
                let window = CheckInSchedule.defaultWindows[index % 2]
                #expect(minutes(time) >= window.start && minutes(time) < window.end)
                #expect(calendar.component(.second, from: time) == 0)
            }
            for (a, b) in zip(planned, planned.dropFirst()) {
                #expect(b.timeIntervalSince(a) >= CheckInSchedule.minimumGap)
            }
        }
    }

    @Test func timesAreSpreadOverTheWindow() {
        let mornings = (0..<300 as Range<UInt64>).map { minutes(times(now: at(7), seed: $0)[0]) }
        #expect(mornings.min()! < 10 * 60 + 20 && mornings.max()! > 12 * 60 + 40)
    }

    /// Windows already open start at now + 5 min; a window already asked today is skipped.
    @Test func todayOnlyAfterNowAndOnlyOncePerWindow() {
        let planned = times(now: at(11, 30), seed: 3)
        #expect(planned.first! >= at(11, 35) && planned.first! < at(13))
        #expect(planned.count == 6)

        let asked = times(now: at(11, 30), asked: [at(10, 15)], seed: 3)
        #expect(asked.count == 5 && asked.first! >= at(15))
        #expect(times(now: at(20), seed: 3).first! >= at(day: 2, 10))
    }

    /// Nothing in the 80 minutes after a queue starts.
    @Test func noQuestionRightAfterAQueue() {
        for seed in 0..<100 as Range<UInt64> {
            let planned = times(now: at(9), quietUntil: at(12, 40), seed: seed)
            #expect(planned.first! >= at(12, 40) && planned.first! < at(13))
        }
        #expect(times(now: at(12, 30), quietUntil: at(13, 10), seed: 1).first! >= at(15))
    }

    /// Windows too close for 2 hours: the second question of the day is dropped, never squeezed in.
    @Test func twoHoursApartEvenWithCloseWindows() {
        let close = [CheckInWindow(start: 10 * 60, end: 11 * 60), CheckInWindow(start: 11 * 60, end: 12 * 60)]
        for seed in 0..<100 as Range<UInt64> {
            let planned = times(now: at(7), windows: close, seed: seed)
            for (a, b) in zip(planned, planned.dropFirst()) {
                #expect(b.timeIntervalSince(a) >= CheckInSchedule.minimumGap)
            }
            #expect(planned.count <= 4)
        }
        #expect(times(now: at(7), windows: close, asked: [at(11, 50)], seed: 9).allSatisfy { $0 >= at(day: 2, 0) })
    }
}
