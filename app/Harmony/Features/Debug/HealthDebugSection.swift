#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, Apple Health part (TODO 1.28+): ask for access and check the readings before
/// the real screens exist (onboarding 3.16, health settings 3.19). Demo mode reads the demo files.
/// Each reading is also printed, to be read from the Xcode console.
struct HealthDebugSection: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Query private var consents: [Consent]
    @Query(sort: \HourSummary.hourStart, order: .reverse) private var hours: [HourSummary]
    @Query(sort: \NightSummary.date, order: .reverse) private var nights: [NightSummary]
    @State private var askingAccess = false
    @State private var isWorking = false
    @State private var message: String?
    /// What the last update read (TODO 1.29).
    @State private var lastUpdate: String?
    /// Heart-rate measures of TODO 1.33 and 1.34, read again from the provider, never stored.
    @State private var intervals: String?
    @State private var coverage5: [Date: Double] = [:]

    var body: some View {
        Section("Apple Health") {
            LabeledContent("Access asked", value: consents.isEmpty ? "No" : "Yes")
            Button("Ask for access") { askingAccess = true }
            Button("Update now") { run(update) }
            if let lastUpdate {
                Text(lastUpdate).font(.caption)
            }
            LabeledContent("Hours / nights stored", value: "\(hours.count) / \(nights.count)")
            LabeledContent("Steps today", value: stepsToday(hours))
            LabeledContent("Last heart rate", value: lastHeartRate(hours))
            LabeledContent("Last HRV", value: lastHRV(hours))
            ForEach(nights.prefix(3)) { night in
                LabeledContent(night.date.formatted(date: .abbreviated, time: .omitted), value: describe(night))
            }
            Button("Measure heart-rate intervals") { run(measure) }
            if let intervals {
                Text(intervals).font(.caption)
            }
            if isWorking {
                ProgressView()
            }
            if let message {
                Text(message).foregroundStyle(.red)
            }
        }
        .disabled(isWorking)
        .fullScreenCover(isPresented: $askingAccess) {
            HealthPermissionView { Task { await askAccess() } }
        }
    }

    private var provider: any HealthProvider {
        get throws { try DemoMode.healthProvider(demoMode) }
    }

    /// TODO 1.30: to compare with the Health app. Unknown hours (nil) are left out.
    /// `hours`: newest first.
    private func stepsToday(_ hours: [HourSummary]) -> String {
        let today = hours.filter { Calendar.current.isDateInToday($0.hourStart) }.compactMap(\.steps)
        return today.isEmpty ? "unknown" : today.reduce(0, +).formatted()
    }

    private func lastHeartRate(_ hours: [HourSummary]) -> String {
        guard let hour = hours.first(where: { $0.meanHR != nil }), let mean = hour.meanHR else { return "none" }
        return "\(Int(mean.rounded())) bpm, \(hour.hrCount)× at \(hour.hourStart.formatted(date: .omitted, time: .shortened))"
    }

    private func lastHRV(_ hours: [HourSummary]) -> String {
        guard let hour = hours.first(where: { $0.sdnnHRV != nil }), let hrv = hour.sdnnHRV else { return "none" }
        return "\(Int(hrv.rounded())) ms at \(hour.hourStart.formatted(date: .abbreviated, time: .shortened))"
    }

    /// TODO 1.31, 1.34: sleep, its end, and the share of the window covered by heart rate
    /// (15-min slots, as the app uses; 5-min slots, the first rule, once measured).
    private func describe(_ night: NightSummary) -> String {
        var text = night.sleepMinutes.map { "\(Int($0) / 60) h \(Int($0) % 60) min" } ?? "unknown"
        if let end = night.sleepEnd {
            text += ", end \(end.formatted(date: .omitted, time: .shortened))"
        }
        text += ", worn \(night.wornFraction.formatted(.percent.precision(.fractionLength(0))))"
        if let narrow = coverage5[night.date] {
            text += " (5 min: \(narrow.formatted(.percent.precision(.fractionLength(0)))))"
        }
        return text
    }

    /// System sheet for the four signals, then the user's choice in `Consent` (TODO 1.28).
    private func askAccess() async {
        message = nil
        do {
            try await provider.requestConsent(Set(HealthSignal.allCases))
            for signal in HealthSignal.allCases {
                context.insert(Consent(source: signal, granted: true, time: .now))
            }
            try context.save()
        } catch {
            message = "\(error)"
        }
        askingAccess = false
    }

    /// TODO 1.29: what the watch added since the last update.
    private func update() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        guard let report = try await SummaryStore.update(provider: provider, context: context) else {
            lastUpdate = "Already updating"
            return
        }
        let counts = HealthSignal.allCases.map { "\($0.rawValue) \(report.newSamples[$0] ?? 0)" }.joined(separator: ", ")
        let duration = (clock.now - start).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
        lastUpdate = "New: \(counts). Rewritten: \(report.hours) hours, \(report.nights) nights, in \(duration)."
        print("Health update: \(lastUpdate!)")
        // The @Query arrays only refresh with the view: read the store again for the console.
        let hours = try context.fetch(FetchDescriptor<HourSummary>(sortBy: [SortDescriptor(\.hourStart, order: .reverse)]))
        let nights = try context.fetch(FetchDescriptor<NightSummary>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        print("Health today: steps \(stepsToday(hours)); last heart rate \(lastHeartRate(hours)); last HRV \(lastHRV(hours))")
        for night in nights.prefix(3) {
            print("Health night \(night.date.formatted(date: .numeric, time: .omitted)): \(describe(night))")
        }
    }

    /// TODO 1.33: median time between two heart rates over the last 48 h, at night (0–6 h) and
    /// during the day (8–24 h). TODO 1.34: coverage of the last 3 nights with 5-min slots.
    private func measure() async throws {
        let calendar = Calendar.current
        let now = Date.now
        let lastNights = Array(nights.prefix(3))
        let since = min(
            now.addingTimeInterval(-48 * 3600),
            lastNights.last.map { HealthSummaries.nightWindow(wakeDay: $0.date, calendar: calendar).start } ?? now
        )
        let heartRate = try await provider.samples(.heartRate, since: since)
        let recent = heartRate.filter { $0.start >= now.addingTimeInterval(-48 * 3600) }
        func median(_ hours: Range<Int>) -> String {
            guard let median = Self.medianInterval(recent, hours: hours, calendar: calendar) else { return "not enough readings" }
            return "\(median.minutes.formatted(.number.precision(.fractionLength(1)))) min (\(median.count) intervals)"
        }
        intervals = "Last 48 h, \(recent.count) heart rates. Median interval: night 0–6 h \(median(0..<6)); day 8–24 h \(median(8..<24))."
        print("Health intervals: \(intervals!)")

        coverage5 = [:]
        for night in lastNights {
            let narrow = HealthSummaries.night(wakeDay: night.date, heartRate: heartRate, sleep: [], now: now,
                                               calendar: calendar, slotMinutes: 5)
            coverage5[night.date] = narrow?.wornFraction
            print("Health night \(night.date.formatted(date: .numeric, time: .omitted)): \(describe(night))")
        }
    }

    /// Median time, in minutes, from a heart rate to the next one, for readings taken during
    /// `hours` (local hour of the first reading). Nil without at least one interval.
    static func medianInterval(_ samples: [HealthSample], hours: Range<Int>, calendar: Calendar) -> (minutes: Double, count: Int)? {
        let starts = samples.map(\.start).sorted()
        let gaps = zip(starts, starts.dropFirst())
            .filter { hours.contains(calendar.component(.hour, from: $0.0)) }
            .map { $0.1.timeIntervalSince($0.0) / 60 }
            .sorted()
        guard !gaps.isEmpty else { return nil }
        let middle = gaps.count / 2
        let median = gaps.count.isMultiple(of: 2) ? (gaps[middle - 1] + gaps[middle]) / 2 : gaps[middle]
        return (median, gaps.count)
    }

    /// Runs an action, showing its error if any.
    private func run(_ action: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do {
                try await action()
            } catch {
                message = "\(error)"
            }
            isWorking = false
        }
    }
}
#endif
