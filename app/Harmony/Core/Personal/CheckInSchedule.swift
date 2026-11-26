import Foundation

/// A time window for the questions, in minutes after local midnight (`V2-Questions`).
nonisolated struct CheckInWindow: Equatable, Sendable {
    var start: Int
    var end: Int
}

/// When to ask "Quick check: energy right now?" (TODO 6.10, design v2 §5.3): at most one question
/// at a random time in each of the two windows, so at most 2 a day; at least 2 hours apart;
/// none in the 80 minutes after a queue starts (60 min after a ~20 min queue); planned 3 days
/// ahead. Windows can only be set within 07:00–22:00, so no question falls in the night.
nonisolated enum CheckInSchedule {
    /// Late morning and afternoon (`V2-Questions`).
    static let defaultWindows = [CheckInWindow(start: 10 * 60, end: 13 * 60), CheckInWindow(start: 15 * 60, end: 19 * 60)]
    /// Pilot only (`docs/pilot-protocol.md` §10.6): up to four questions a day, set in Debug.
    static let pilotWindows = [CheckInWindow(start: 9 * 60, end: 11 * 60), CheckInWindow(start: 12 * 60, end: 14 * 60),
                               CheckInWindow(start: 15 * 60, end: 17 * 60), CheckInWindow(start: 18 * 60, end: 21 * 60)]
    /// Bounds of a window and its shortest length, for the time pickers.
    static let earliest = 7 * 60
    static let latest = 22 * 60
    static let shortestWindow = 60
    static let minimumGap: TimeInterval = 2 * 3600
    static let quietAfterQueue: TimeInterval = 80 * 60
    static let daysAhead = 3
    /// Never closer than this to now: the request has time to be added.
    static let lead: TimeInterval = 5 * 60
    static let tries = 20

    /// The question times from `now`, in order.
    /// - `asked`: questions already sent (or due); their window is taken that day and the next
    ///   ones keep 2 hours from them.
    /// - `quietUntil`: no question before this (the last queue start + 80 min).
    static func times(now: Date, windows: [CheckInWindow], asked: [Date], quietUntil: Date?,
                      days: Int = daysAhead, calendar: Calendar, using rng: inout some RandomNumberGenerator) -> [Date] {
        var chosen: [Date] = []
        let today = calendar.startOfDay(for: now)
        for day in 0..<days {
            let dayStart = calendar.date(byAdding: .day, value: day, to: today)!
            for window in windows.sorted(by: { $0.start < $1.start }) {
                let opens = minute(window.start, of: dayStart, calendar: calendar)
                let closes = minute(window.end, of: dayStart, calendar: calendar)
                guard !asked.contains(where: { opens <= $0 && $0 < closes }) else { continue }
                let lower = max(opens, now + lead, quietUntil ?? opens)
                guard lower < closes else { continue }
                let span = closes.timeIntervalSince(lower)
                for _ in 0..<tries {
                    let seconds = (Double.random(in: 0..<span, using: &rng) / 60).rounded(.down) * 60
                    let time = lower + seconds
                    if (asked + chosen).allSatisfy({ abs($0.timeIntervalSince(time)) >= minimumGap }) {
                        chosen.append(time)
                        break
                    }
                }
            }
        }
        return chosen
    }

    private static func minute(_ minutes: Int, of day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)!
    }
}
