import Foundation
import Testing
@testable import Harmony

/// The pilot's calendar (`docs/pilot-protocol.md` §6): pilot days count from the start day; every
/// day uses the watch data (TODO 4.4, no daily draw).
@MainActor
struct PilotScheduleTests {
    private let calendar = StateFixtures.calendar
    private var start: Date { calendar.date(from: DateComponents(year: 2026, month: 12, day: 7))! }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(byAdding: DateComponents(day: day - 1, hour: hour), to: start)!
    }

    @Test func pilotDaysCountFromTheStartDay() {
        let schedule = PilotSchedule(startDay: start, calendar: calendar)
        #expect(schedule.day(of: date(day: 0, hour: 23)) == nil)
        #expect(schedule.day(of: date(day: 1, hour: 0)) == 1)
        #expect(schedule.day(of: date(day: 1, hour: 23)) == 1)
        #expect(schedule.day(of: date(day: 7, hour: 8)) == 7)
    }

    @Test func startingSavesTheScheduleAndStoppingRemovesIt() throws {
        let suite = "PilotScheduleTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PilotSchedule.stored(in: defaults, calendar: calendar) == nil)

        let started = PilotSchedule.start(in: defaults, now: date(day: 1, hour: 9), calendar: calendar)
        #expect(started.startDay == start)
        #expect(PilotSchedule.stored(in: defaults, calendar: calendar) == started)

        PilotSchedule.stop(in: defaults)
        #expect(PilotSchedule.stored(in: defaults, calendar: calendar) == nil)
        // "Delete everything" also ends the pilot (FR13).
        #expect(Set(PilotSchedule.keys).isSubset(of: DataControl.storedKeys))
    }

    /// A pilot started before TODO 4.4 left the seed of the draw: stopping removes it too.
    @Test func stoppingRemovesTheOldSeed() throws {
        let suite = "PilotScheduleTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        PilotSchedule.start(in: defaults, now: date(day: 1, hour: 9), calendar: calendar)
        defaults.set("42", forKey: PilotSchedule.oldSeedKey)

        PilotSchedule.stop(in: defaults)
        #expect(defaults.object(forKey: PilotSchedule.oldSeedKey) == nil)
    }
}
