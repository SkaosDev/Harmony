import Foundation

/// Hourly and nightly summaries of watch samples (TODO 1.32, PROJECT.md §6, §10). Pure functions:
/// the samples come from a `HealthProvider` and are dropped once summarised.
/// Unknown is not zero: no watch data gives nil, never 0.
enum HealthSummaries {
    /// The night runs from 21:00 the day before to 12:00 on the wake-up day.
    static let nightStartHour = 21
    static let nightEndHour = 12
    /// Below this share of the window covered by heart rate, the night is unknown.
    static let wornThreshold = 0.6
    /// A slot of the window is "worn" if it holds at least one heart rate. 15 min (TODO 1.34): the
    /// Apple Watch reads about every 4–5 min, so 5-min slots left a night worn throughout at ~70 %.
    static let slotMinutes = 15

    /// One summary per hour from `from` on that has data. Heart rate and HRV count in the hour
    /// they were measured; steps are shared between hours by overlap. Steps are known (0 or more)
    /// when the hour has heart rate or steps, nil otherwise.
    static func hours(heartRate: [HealthSample], steps: [HealthSample], hrv: [HealthSample],
                      from: Date, calendar: Calendar) -> [HourSummary] {
        func hourStart(_ date: Date) -> Date { calendar.dateInterval(of: .hour, for: date)!.start }

        let heartRateByHour = Dictionary(grouping: heartRate) { hourStart($0.start) }
        let hrvByHour = Dictionary(grouping: hrv) { hourStart($0.start) }
        var stepsByHour: [Date: Double] = [:]
        for sample in steps {
            let duration = sample.end.timeIntervalSince(sample.start)
            var hour = hourStart(sample.start)
            repeat {
                let next = calendar.date(byAdding: .hour, value: 1, to: hour)!
                let overlap = min(sample.end, next).timeIntervalSince(max(sample.start, hour))
                stepsByHour[hour, default: 0] += duration > 0 ? sample.value * max(overlap, 0) / duration : sample.value
                hour = next
            } while hour < sample.end
        }

        let hours = Set(heartRateByHour.keys).union(hrvByHour.keys).union(stepsByHour.keys).filter { $0 >= from }
        return hours.sorted().map { hour in
            let heartRate = heartRateByHour[hour, default: []]
            let hrv = hrvByHour[hour, default: []]
            let steps = stepsByHour[hour]
            return HourSummary(
                hourStart: hour,
                meanHR: mean(heartRate),
                hrCount: heartRate.count,
                sdnnHRV: mean(hrv),
                steps: heartRate.isEmpty && steps == nil ? nil : Int((steps ?? 0).rounded())
            )
        }
    }

    /// 21:00 the day before `wakeDay` → 12:00 on `wakeDay` (start of day).
    static func nightWindow(wakeDay: Date, calendar: Calendar) -> DateInterval {
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: wakeDay)!
        return DateInterval(
            start: calendar.date(bySettingHour: nightStartHour, minute: 0, second: 0, of: dayBefore)!,
            end: calendar.date(bySettingHour: nightEndHour, minute: 0, second: 0, of: wakeDay)!
        )
    }

    /// The night ending on `wakeDay`, or nil if its window has not started at `now`.
    /// - `wornFraction`: share of `slotMinutes` slots holding a heart rate, over the elapsed part
    ///   of the window (a queue at 07:00 must still know last night).
    /// - Like the Health app: `sleepMinutes` adds up every asleep interval in the window (counted
    ///   once where they overlap), and `sleepEnd` is the end of the last one.
    /// - Unknown (nil sleep) when the watch covers less than 60 % or there is no asleep interval
    ///   at all (sleep tracking off): never 0 minutes.
    static func night(wakeDay: Date, heartRate: [HealthSample], sleep: [HealthSample], now: Date,
                      calendar: Calendar, slotMinutes: Int = HealthSummaries.slotMinutes) -> NightSummary? {
        let window = nightWindow(wakeDay: wakeDay, calendar: calendar)
        let end = min(now, window.end)
        guard end > window.start else { return nil }

        let slot = TimeInterval(slotMinutes * 60)
        let slotCount = (end.timeIntervalSince(window.start) / slot).rounded(.up)
        let wornSlots = Set(heartRate.lazy
            .filter { $0.start >= window.start && $0.start < end }
            .map { Int($0.start.timeIntervalSince(window.start) / slot) })
        let wornFraction = Double(wornSlots.count) / slotCount

        // Asleep intervals cut to the window, merged where they overlap.
        var merged: [DateInterval] = []
        for sample in sleep.sorted(by: { $0.start < $1.start }) {
            let start = max(sample.start, window.start)
            let stop = min(sample.end, end)
            guard stop > start else { continue }
            if let last = merged.last, start <= last.end {
                merged[merged.count - 1].end = max(last.end, stop)
            } else {
                merged.append(DateInterval(start: start, end: stop))
            }
        }

        let known = wornFraction >= wornThreshold && !merged.isEmpty
        return NightSummary(
            date: wakeDay,
            sleepMinutes: known ? merged.reduce(0) { $0 + $1.duration } / 60 : nil,
            sleepEnd: known ? merged.last?.end : nil,
            wornFraction: wornFraction
        )
    }

    /// Wake-up days (start of day) of the nights whose window overlaps `start`…`end`.
    static func wakeDays(touching start: Date, _ end: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var day = calendar.startOfDay(for: start)
        while true {
            let window = nightWindow(wakeDay: day, calendar: calendar)
            guard window.start < end else { return days }
            if window.end > start {
                days.append(day)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
    }

    private static func mean(_ samples: [HealthSample]) -> Double? {
        samples.isEmpty ? nil : samples.reduce(0) { $0 + $1.value } / Double(samples.count)
    }
}
