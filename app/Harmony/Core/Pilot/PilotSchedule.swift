import Foundation

/// The pilot's calendar (`docs/pilot-protocol.md` §6): the start day, saved when the pilot starts,
/// gives the pilot day of each queue. Every pilot day uses the watch data (TODO 4.4).
nonisolated struct PilotSchedule: Equatable {
    static let startKey = "pilot.startDay"
    /// Seed of the daily draw removed in TODO 4.4; still removed when the pilot stops.
    static let oldSeedKey = "pilot.seed"
    static let keys = [startKey, oldSeedKey]

    /// Midnight of pilot day 1.
    let startDay: Date
    var calendar: Calendar = .current

    /// Pilot day of `date`, 1 on the start day; nil before it.
    func day(of date: Date) -> Int? {
        let days = calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: date)).day!
        return days >= 0 ? days + 1 : nil
    }

    // MARK: Storage (UserDefaults, removed by "Delete everything")

    /// The running pilot, or nil.
    static func stored(in defaults: UserDefaults = .standard, calendar: Calendar = .current) -> PilotSchedule? {
        guard let start = defaults.object(forKey: startKey) as? Double else { return nil }
        return PilotSchedule(startDay: Date(timeIntervalSince1970: start), calendar: calendar)
    }

    /// Starts the pilot today.
    @discardableResult
    static func start(in defaults: UserDefaults = .standard, now: Date = .now,
                      calendar: Calendar = .current) -> PilotSchedule {
        let schedule = PilotSchedule(startDay: calendar.startOfDay(for: now), calendar: calendar)
        defaults.set(schedule.startDay.timeIntervalSince1970, forKey: startKey)
        return schedule
    }

    static func stop(in defaults: UserDefaults = .standard) {
        keys.forEach(defaults.removeObject(forKey:))
    }
}
