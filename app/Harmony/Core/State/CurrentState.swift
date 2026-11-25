import Foundation

/// The state at an instant, from the watch data of a health provider (TODO 2.22). Heart rate,
/// steps and sleep of the last 14 days are read, used and dropped: nothing raw is stored (§11).
struct CurrentState {
    let date: Date
    /// The 17 features by name; nil = unknown.
    let features: [String: Double?]
    let estimate: StateEstimate
    /// The probabilities of the worn points of the reference grid, scored with the references of
    /// `date` (TODO 6.11, design v2 §4.3).
    var gridProbabilities: [Double] = []

    /// `e0` without answers: the rank of the estimate among the grid probabilities, or the
    /// estimate itself with fewer than 32 of them.
    var rank: Double { PersonalRank.e0(probability: estimate.value, grid: gridProbabilities) }

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
        let series = WatchSeries(heartRate: heartRate, steps: steps)
        let grid = BaselineCalculator.gridValues(before: now, series: series, calendar: calendar)
        let baseline = BaselineCalculator.baseline(grid: grid, calendar: calendar)
        let sleepReference = FeatureBuilder.sleepReference(at: now, nights: nights, calendar: calendar)
        let features = FeatureBuilder.features(at: now, values: series.values(at: now), baseline: baseline,
                                               sleepReference: sleepReference, nights: nights, calendar: calendar)
        let rows = PersonalRank.rows(grid: grid, baseline: baseline, sleepReference: sleepReference,
                                     nights: nights, calendar: calendar)
        return CurrentState(date: now, features: features, estimate: try estimator.estimate(features),
                            gridProbabilities: try rows.map { try estimator.gridProbability($0.features) })
    }

    /// `compute`, or, when the health data cannot be read, the same as a phone without a watch:
    /// every watch feature unknown, so the time-of-day estimate (TODO 3.22).
    static func computeOrTimeOnly(provider: any HealthProvider, estimator: StateEstimator, now: Date = .now,
                                  calendar: Calendar = .current) async throws -> CurrentState {
        do {
            return try await compute(provider: provider, estimator: estimator, now: now, calendar: calendar)
        } catch {
            print("Health data not read, time of day only: \(error)")
            return try await timeOnly(estimator: estimator, now: now, calendar: calendar)
        }
    }

    /// The time-of-day estimate, whatever the watch gives: the fallback when the health data
    /// cannot be read.
    static func timeOnly(estimator: StateEstimator, now: Date = .now, calendar: Calendar = .current) async throws -> CurrentState {
        try await compute(provider: NoWatchData(), estimator: estimator, now: now, calendar: calendar)
    }
}

/// No sample of any kind: what a phone without a watch gives.
private struct NoWatchData: HealthProvider {
    func requestConsent(_ signals: Set<HealthSignal>) async throws {}

    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] { [] }

    func newSamples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] { [] }
}
