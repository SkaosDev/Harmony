import Foundation

/// The state at an instant, from the watch data of a health provider (TODO 2.22). Heart rate,
/// steps and sleep of the last 14 days are read, used and dropped: nothing raw is stored (§11).
struct CurrentState {
    let date: Date
    /// The 13 features by name; nil = unknown.
    let features: [String: Double?]
    let estimate: StateEstimate

    static func compute(provider: any HealthProvider, estimator: StateEstimator, now: Date = .now,
                        calendar: Calendar = .current) async throws -> CurrentState {
        // The oldest night of the sleep reference starts at 21:00, 15 days ago: that is earlier
        // than the heart rate and steps the 14-day grid needs (from 14 days + 1 h before now).
        let today = calendar.startOfDay(for: now)
        let wakeDays = (0...BaselineCalculator.referenceDays).map {
            calendar.date(byAdding: .day, value: -$0, to: today)!
        }
        let since = HealthSummaries.nightWindow(wakeDay: wakeDays.last!, calendar: calendar).start
        let heartRate = try await provider.samples(.heartRate, since: since).filter { $0.start <= now }
        let steps = try await provider.samples(.steps, since: since).filter { $0.start <= now }
        let sleep = try await provider.samples(.sleep, since: since)

        // Apple Watch nights, the one of today cut at now, as the stored summaries.
        let nights = wakeDays.compactMap {
            HealthSummaries.night(wakeDay: $0, heartRate: heartRate, sleep: sleep, now: now, calendar: calendar)
        }
        let features = FeatureBuilder.features(at: now, series: WatchSeries(heartRate: heartRate, steps: steps),
                                               nights: nights, calendar: calendar)
        return CurrentState(date: now, features: features, estimate: try estimator.estimate(features))
    }
}
