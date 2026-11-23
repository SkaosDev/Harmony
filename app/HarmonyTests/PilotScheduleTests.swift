import Foundation
import Testing
@testable import Harmony

/// TODO 4.4: the pilot's daily draw, body days vs time-only days (`docs/pilot-protocol.md` §6).
@MainActor
struct PilotScheduleTests {
    private let calendar = StateFixtures.calendar
    private var start: Date { calendar.date(from: DateComponents(year: 2026, month: 12, day: 7))! }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(byAdding: DateComponents(day: day - 1, hour: hour), to: start)!
    }

    private func kinds(seed: UInt64, days: Int = 14) -> [QueueKind?] {
        let schedule = PilotSchedule(startDay: start, seed: seed, calendar: calendar)
        return (1...days).map { schedule.kind(on: date(day: $0, hour: 12)) }
    }

    @Test func pilotDaysCountFromTheStartDay() {
        let schedule = PilotSchedule(startDay: start, seed: 1, calendar: calendar)
        #expect(schedule.day(of: date(day: 0, hour: 23)) == nil)
        #expect(schedule.kind(on: date(day: 0, hour: 23)) == nil)
        #expect(schedule.day(of: date(day: 1, hour: 0)) == 1)
        #expect(schedule.day(of: date(day: 1, hour: 23)) == 1)
        #expect(schedule.day(of: date(day: 14, hour: 8)) == 14)
    }

    /// Every queue of a day gets the same kind.
    @Test func aDayKeepsOneKind() {
        let schedule = PilotSchedule(startDay: start, seed: 42, calendar: calendar)
        for day in 1...14 {
            let kinds = Set([0, 7, 13, 23].map { schedule.kind(on: date(day: day, hour: $0)) })
            #expect(kinds.count == 1, "day \(day)")
        }
    }

    /// Blocks of two days with opposite kinds: 14 days give 7 body days and 7 time-only days.
    @Test func twoDayBlocksBalanceTheKinds() {
        for seed: UInt64 in [0, 1, 7, 42, .max] {
            let kinds = kinds(seed: seed)
            #expect(kinds.allSatisfy { $0 != nil })
            for block in 0..<7 {
                #expect(kinds[2 * block] != kinds[2 * block + 1], "seed \(seed), block \(block)")
            }
            #expect(kinds.filter { $0 == .body }.count == 7, "seed \(seed)")
        }
    }

    /// The same seed gives the same days; the order of a block depends on the seed.
    @Test func theSeedDecidesTheOrder() {
        #expect(kinds(seed: 1234) == kinds(seed: 1234))
        let firstDays = Set((0..<20).map { kinds(seed: UInt64($0), days: 1)[0] })
        #expect(firstDays == [.body, .timeOnly])
        let orders = Set((0..<20).map { kinds(seed: UInt64($0)) })
        #expect(orders.count > 2)
    }

    @Test func startingSavesTheScheduleAndStoppingRemovesIt() throws {
        let suite = "PilotScheduleTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PilotSchedule.stored(in: defaults, calendar: calendar) == nil)

        let started = PilotSchedule.start(in: defaults, now: date(day: 1, hour: 9), calendar: calendar, seed: .max)
        #expect(started.startDay == start && started.seed == .max)
        #expect(PilotSchedule.stored(in: defaults, calendar: calendar) == started)

        PilotSchedule.stop(in: defaults)
        #expect(PilotSchedule.stored(in: defaults, calendar: calendar) == nil)
        // "Delete everything" also ends the pilot (FR13).
        #expect(Set(PilotSchedule.keys).isSubset(of: DataControl.storedKeys))
    }
}
