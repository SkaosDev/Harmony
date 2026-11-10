import Foundation
import HealthKit

/// The real health provider: Apple Health, Apple Watch samples only (PROJECT.md §10,
/// TODO 1.28–1.31). Only the watch counts: iPhone steps would be counted twice, and "no heart
/// rate" must keep meaning "watch not worn". Apple Health cannot be read while the phone is
/// locked, so reads happen when the app opens.
struct HealthKitProvider: HealthProvider {
    static let live = HealthKitProvider()

    private let store = HKHealthStore()

    /// Shows the system sheet listing the signals (TODO 1.28). It returns without saying what
    /// the user allowed: a refused signal just reads as no data.
    func requestConsent(_ signals: Set<HealthSignal>) async throws {
        try await store.requestAuthorization(toShare: [], read: Set(signals.map(\.sampleType)))
    }

    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        // No option: samples that overlap since…now, so a night begun before `since` is kept.
        let query = HKSampleQueryDescriptor(
            predicates: [.sample(type: signal.sampleType, predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await readIfAsked { try await query.result(for: store) }?.compactMap(signal.sample) ?? []
    }

    /// Anchored read (TODO 1.29): one anchor per signal, kept in `UserDefaults` and moved
    /// forward after each read, so each opening only gets what the watch added since.
    /// Deleted samples are ignored.
    func newSamples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        let query = HKAnchoredObjectQueryDescriptor(
            predicates: [.sample(type: signal.sampleType, predicate: HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate))],
            anchor: anchor(for: signal)
        )
        guard let result = try await readIfAsked({ try await query.result(for: store) }) else { return [] }
        saveAnchor(result.newAnchor, for: signal)
        return result.addedSamples.compactMap(signal.sample).sorted { $0.start < $1.start }
    }

    /// Before the user was asked, Apple Health answers "not determined": no data, unknown
    /// rather than an error (PROJECT.md §10).
    private func readIfAsked<T>(_ read: () async throws -> T) async throws -> T? {
        do {
            return try await read()
        } catch let error as HKError where error.code == .errorAuthorizationNotDetermined {
            return nil
        }
    }

    private func anchorKey(_ signal: HealthSignal) -> String { "healthAnchor.\(signal.rawValue)" }

    private func anchor(for signal: HealthSignal) -> HKQueryAnchor? {
        UserDefaults.standard.data(forKey: anchorKey(signal))
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
    }

    private func saveAnchor(_ anchor: HKQueryAnchor, for signal: HealthSignal) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        UserDefaults.standard.set(data, forKey: anchorKey(signal))
    }
}

private extension HealthSignal {
    var sampleType: HKSampleType {
        switch self {
        case .heartRate: HKQuantityType(.heartRate)
        case .steps: HKQuantityType(.stepCount)
        case .hrv: HKQuantityType(.heartRateVariabilitySDNN)
        case .sleep: HKCategoryType(.sleepAnalysis)
        }
    }

    /// The app's sample, or nil when it does not count: not from an Apple Watch (1.30), or a
    /// sleep value other than asleep (core, deep, REM, unspecified), such as "in bed" (1.31).
    func sample(_ sample: HKSample) -> HealthSample? {
        guard sample.sourceRevision.productType?.hasPrefix("Watch") == true else { return nil }
        let value: Double
        switch sample {
        case let category as HKCategorySample:
            guard let sleep = HKCategoryValueSleepAnalysis(rawValue: category.value),
                  HKCategoryValueSleepAnalysis.allAsleepValues.contains(sleep) else { return nil }
            value = 1
        case let quantity as HKQuantitySample:
            value = quantity.quantity.doubleValue(for: unit)
        default:
            return nil
        }
        return HealthSample(start: sample.startDate, end: sample.endDate, value: value)
    }

    /// Beats per minute, steps, milliseconds (`HealthSample.value`).
    private var unit: HKUnit {
        switch self {
        case .heartRate: .count().unitDivided(by: .minute())
        case .steps: .count()
        case .hrv: .secondUnit(with: .milli)
        case .sleep: .count()
        }
    }
}
