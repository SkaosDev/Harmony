import Foundation
import SwiftData

/// Keeps the hourly and nightly summaries up to date from a health provider, at each opening of
/// the app (TODO 1.29, 1.32, PROJECT.md §4.3). Raw samples only live in memory during `update`:
/// the store keeps nothing but the summaries (§11).
enum SummaryStore {
    /// How far back the first opening reads: the personal means use the previous 14 days (§6.4).
    static let historyDays = 14

    /// What one update did, shown in Debug.
    struct Report {
        /// New samples per signal since the previous opening.
        var newSamples: [HealthSignal: Int] = [:]
        /// Hours and nights rewritten.
        var hours = 0
        var nights = 0
    }

    private static var isUpdating = false

    /// Reads what the watch added since the last opening; from the oldest new sample on,
    /// reads the samples again and rewrites every hour and every night touched (a late watch
    /// sync corrects older hours). Nothing new: nothing to do. Nil if an update is already running.
    static func update(provider: any HealthProvider, context: ModelContext, now: Date = .now,
                       calendar: Calendar = .current) async throws -> Report? {
        guard !isUpdating else { return nil }
        isUpdating = true
        defer { isUpdating = false }

        var report = Report()
        let since = calendar.date(byAdding: .day, value: -historyDays, to: calendar.startOfDay(for: now))!
        var oldestNew: Date?
        for signal in HealthSignal.allCases {
            let new = try await provider.newSamples(signal, since: since)
            report.newSamples[signal] = new.count
            if let first = new.first?.start {
                oldestNew = min(oldestNew ?? first, first)
            }
        }
        guard let oldestNew else { return report }

        let wakeDays = HealthSummaries.wakeDays(touching: oldestNew, now, calendar: calendar)
        var from = calendar.dateInterval(of: .hour, for: oldestNew)!.start
        if let firstNight = wakeDays.first {
            from = min(from, HealthSummaries.nightWindow(wakeDay: firstNight, calendar: calendar).start)
        }
        var samples: [HealthSignal: [HealthSample]] = [:]
        for signal in HealthSignal.allCases {
            samples[signal] = try await provider.samples(signal, since: from)
        }

        let hours = HealthSummaries.hours(
            heartRate: samples[.heartRate, default: []], steps: samples[.steps, default: []],
            hrv: samples[.hrv, default: []], from: from, calendar: calendar
        )
        let nights = wakeDays.compactMap {
            HealthSummaries.night(wakeDay: $0, heartRate: samples[.heartRate, default: []],
                                  sleep: samples[.sleep, default: []], now: now, calendar: calendar)
        }
        // `hourStart` and `date` are unique: inserting replaces the previous summary.
        hours.forEach(context.insert)
        nights.forEach(context.insert)
        try context.save()
        report.hours = hours.count
        report.nights = nights.count
        return report
    }
}
