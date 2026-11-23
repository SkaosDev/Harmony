import Foundation
import Testing
@testable import Harmony

/// TODO 3.8
@MainActor
struct SituationSuggesterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func suggest(_ hour: Int, _ minute: Int = 0, wake: Double? = nil, e0: Double = 0.5) -> Situation? {
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: hour, minute: minute))!
        return SituationSuggester.suggestion(at: date, hoursSinceWake: wake, e0: e0, calendar: calendar)
    }

    @Test func wakeUpWithinTwoHoursOfTheEndOfSleep() {
        #expect(suggest(7, wake: 0) == .wakeUp)
        #expect(suggest(9, wake: 2) == .wakeUp)
        #expect(suggest(9, wake: 2.1) == nil)
        // A late wake-up still counts, and it wins over the evening and afternoon rules.
        #expect(suggest(14, wake: 1, e0: 0.1) == .wakeUp)
        // Unknown night: no Wake-up.
        #expect(suggest(7) == nil)
    }

    @Test func windDownFromNinePmToFiveAm() {
        #expect(suggest(20, 59) == nil)
        #expect(suggest(21) == .windDown)
        #expect(suggest(23, 30) == .windDown)
        #expect(suggest(2) == .windDown)
        #expect(suggest(4, 59) == .windDown)
        #expect(suggest(5) == nil)
    }

    @Test func lowEnergyInTheAfternoonOnlyWhenTheStateIsLow() {
        #expect(suggest(13, e0: 0.39) == .lowEnergy)
        #expect(suggest(16, 59, e0: 0.2) == .lowEnergy)
        #expect(suggest(15, e0: 0.4) == nil)
        #expect(suggest(12, 59, e0: 0.1) == nil)
        #expect(suggest(17, e0: 0.1) == nil)
    }

    @Test func stressIsNeverSuggested() {
        for hour in 0..<24 {
            for e0 in stride(from: 0.0, through: 1.0, by: 0.1) {
                for wake in [nil, 0.5, 5.0] {
                    #expect(suggest(hour, wake: wake, e0: e0) != .stress)
                }
            }
        }
    }
}
