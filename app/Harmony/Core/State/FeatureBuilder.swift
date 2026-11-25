import Foundation

/// The 17 features v3 of the state model at an instant t (TODO 2.19, 6.4), exactly as
/// `ml/features.py` computes them (PROJECT.md §6 « Features v1 » and §6.8): the 13 of v1 and
/// the 4 raw windows. Unknown is nil, never 0. Sleep is the Apple Watch's (`NightSummary`), not
/// estimated from heart rate as in Python.
enum FeatureBuilder {
    /// z_sleep_min needs this many known nights among the 14 days before the answer day.
    static let minKnownNights = 5

    struct UnknownFeature: Error {
        let name: String
    }

    /// Every feature by name; nil = unknown.
    /// - `series`: heart rate and steps of the 14 days (+ 1 h) before t.
    /// - `nights`: the night of t's day (cut at t before 12:00) and the full nights before it.
    static func features(at t: Date, series: WatchSeries, nights: [NightSummary],
                         calendar: Calendar) -> [String: Double?] {
        features(at: t, values: series.values(at: t),
                 baseline: BaselineCalculator.baseline(at: t, series: series, calendar: calendar),
                 sleepReference: sleepReference(at: t, nights: nights, calendar: calendar),
                 nights: nights, calendar: calendar)
    }

    /// The features of instant t from its window `values`, compared with `baseline` and
    /// `sleepReference`: the references of t itself, or, for a point of the rank grid (TODO 6.11,
    /// design v2 §4.3), those of the prediction instant. The night is the one of t's own day.
    static func features(at t: Date, values now: [WindowQuantity: Double], baseline: Baseline,
                         sleepReference: Reference?, nights: [NightSummary], calendar: Calendar) -> [String: Double?] {
        var features: [String: Double?] = [:]

        // Time: local hour + minutes / 60; weekend = Saturday or Sunday.
        let clock = calendar.dateComponents([.hour, .minute, .weekday], from: t)
        let hour = Double(clock.hour!) + Double(clock.minute!) / 60
        features["hour_sin"] = sin(2 * .pi * hour / 24)
        features["hour_cos"] = cos(2 * .pi * hour / 24)
        features["weekend"] = clock.weekday == 1 || clock.weekday == 7 ? 1 : 0

        // Heart rate and steps, compared with the 14 days before.
        for quantity in WindowQuantity.allCases {
            features["z_" + quantity.rawValue] = baseline.z(quantity, now[quantity])
        }
        features["zb_hr_30"] = baseline.zBlock(now[.hr30], block: BaselineCalculator.block(of: t, calendar: calendar))
        // v3: the 30 and 60-min windows before the z-score (PROJECT.md §6.8).
        for quantity in [WindowQuantity.hr30, .hr60, .logSteps30, .logSteps60] {
            features["raw_" + quantity.rawValue] = now[quantity]
        }

        // Sleep of the night ending on t's day, compared with the reference.
        let night = nights.first { $0.date == calendar.startOfDay(for: t) }
        let sleep = night?.sleepMinutes
        features["z_sleep_min"] = sleepReference?.z(sleep)
        features["hours_since_wake"] = hoursSinceWake(t, wake: sleep == nil ? nil : night?.sleepEnd)
        features["sleep_unknown"] = sleep == nil ? 1 : 0
        return features
    }

    /// Sleep reference of t: the known nights of the 14 days before t's day, at least 5 of them.
    static func sleepReference(at t: Date, nights: [NightSummary], calendar: Calendar) -> Reference? {
        let today = calendar.startOfDay(for: t)
        let firstDay = calendar.date(byAdding: .day, value: -BaselineCalculator.referenceDays, to: today)!
        let previous = nights.compactMap { night -> (value: Double, day: Date)? in
            guard night.date >= firstDay, night.date < today, let minutes = night.sleepMinutes else { return nil }
            return (minutes, night.date)
        }
        return BaselineCalculator.reference(previous, minDays: minKnownNights)
    }

    /// The model row: `features` in the order of `model_params.json`.
    static func row(_ features: [String: Double?], order: [String]) throws -> [Double?] {
        try order.map { name in
            guard let value = features[name] else { throw UnknownFeature(name: name) }
            return value
        }
    }

    /// Whole minutes from the wake-up to t, in hours; unknown before the wake-up.
    private static func hoursSinceWake(_ t: Date, wake: Date?) -> Double? {
        guard let wake else { return nil }
        let minutes = wholeMinutes(t) - wholeMinutes(wake)
        return minutes >= 0 ? minutes / 60 : nil
    }

    private static func wholeMinutes(_ date: Date) -> Double {
        (date.timeIntervalSince1970 / 60).rounded(.down)
    }
}
