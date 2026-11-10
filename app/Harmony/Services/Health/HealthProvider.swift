import Foundation

/// A source of watch data: consent and new samples (TODO 1.14). The core (summaries, features,
/// state) only sees this protocol, never HealthKit itself (PROJECT.md §4.3, FR14).
/// Implementations: `HealthKitProvider` (TODO 1.28+), `DemoHealthProvider`.
protocol HealthProvider {
    /// Asks the user to allow reading these signals. HealthKit never says whether reading was
    /// refused (PROJECT.md §10): the user's choice is recorded apart, in `Consent`.
    func requestConsent(_ signals: Set<HealthSignal>) async throws
    /// Samples of one signal that overlap `since`…now (they end at or after `since`), oldest first.
    /// No data (watch not worn, reading refused) gives an empty array: unknown, not an error.
    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample]
    /// Samples added since the previous call (TODO 1.29), oldest first; the first call returns
    /// those that started at or after `since`. Reads that come later return only what is new.
    func newSamples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample]
}

/// One reading of the watch, over `start`…`end` (the same instant for heart rate and HRV).
/// `value`: heart rate in beats per minute; steps counted over the interval; HRV (SDNN) in ms;
/// sleep: one interval asleep (Apple Watch, asleep* values only), `value` is always 1.
struct HealthSample: Equatable {
    let start: Date
    let end: Date
    let value: Double
}
