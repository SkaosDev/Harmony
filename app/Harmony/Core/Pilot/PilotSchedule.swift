import Foundation

/// The pilot's daily draw (TODO 4.4, `docs/pilot-protocol.md` §6): each pilot day is a body day or
/// a time-only day, the same for every queue of the day. Days go in blocks of two with opposite
/// kinds, the order of each block drawn from the seed saved when the pilot starts, so 14 days give
/// 7 of each (a daily coin toss could give 10/4 with one participant).
nonisolated struct PilotSchedule: Equatable {
    static let startKey = "pilot.startDay"
    static let seedKey = "pilot.seed"
    static let keys = [startKey, seedKey]

    /// Midnight of pilot day 1.
    let startDay: Date
    let seed: UInt64
    var calendar: Calendar = .current

    /// Pilot day of `date`, 1 on the start day; nil before it.
    func day(of date: Date) -> Int? {
        let days = calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: date)).day!
        return days >= 0 ? days + 1 : nil
    }

    /// Kind of every queue started at `date`; nil before the pilot.
    func kind(on date: Date) -> QueueKind? {
        guard let day = day(of: date) else { return nil }
        let block = UInt64((day - 1) / 2)
        let bodyFirst = Self.splitMix(seed &+ (block &+ 1) &* 0x9E37_79B9_7F4A_7C15) & 1 == 0
        let isFirstDay = (day - 1) % 2 == 0
        return isFirstDay == bodyFirst ? .body : .timeOnly
    }

    /// SplitMix64 finalizer: a well-mixed 64-bit value for each block.
    private static func splitMix(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    // MARK: Storage (UserDefaults, removed by "Delete everything")

    /// The running pilot, or nil.
    static func stored(in defaults: UserDefaults = .standard, calendar: Calendar = .current) -> PilotSchedule? {
        guard let start = defaults.object(forKey: startKey) as? Double,
              let seed = defaults.string(forKey: seedKey).flatMap({ UInt64($0) }) else { return nil }
        return PilotSchedule(startDay: Date(timeIntervalSince1970: start), seed: seed, calendar: calendar)
    }

    /// Starts the pilot today, with a new random seed.
    @discardableResult
    static func start(in defaults: UserDefaults = .standard, now: Date = .now, calendar: Calendar = .current,
                      seed: UInt64 = .random(in: .min ... .max)) -> PilotSchedule {
        let schedule = PilotSchedule(startDay: calendar.startOfDay(for: now), seed: seed, calendar: calendar)
        defaults.set(schedule.startDay.timeIntervalSince1970, forKey: startKey)
        defaults.set(String(seed), forKey: seedKey)
        return schedule
    }

    static func stop(in defaults: UserDefaults = .standard) {
        keys.forEach(defaults.removeObject(forKey:))
    }
}
