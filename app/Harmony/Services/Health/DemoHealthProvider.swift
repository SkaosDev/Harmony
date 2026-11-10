import Foundation

/// Health provider of demo mode (TODO 1.16, FR12): the 14 synthetic days of
/// `Resources/demo/demo_health.json` (TODO 1.15), placed so that the last day is today.
/// Samples after `now` are not returned, as if they had not been measured yet.
struct DemoHealthProvider: HealthProvider {
    private let samplesBySignal: [HealthSignal: [HealthSample]]
    private let now: Date

    init(bundle: Bundle = .main, now: Date = .now, calendar: Calendar = .current) throws {
        guard let url = bundle.url(forResource: "demo_health", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let file = try JSONDecoder().decode(DemoHealthFile.self, from: Data(contentsOf: url))

        // The file counts seconds from midnight of its first day, 13 days before today. Plain
        // seconds: a daylight-saving change would shift the later days by one hour (fine for a demo).
        let firstDay = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!
        func samples(_ rows: [[Double]]) -> [HealthSample] {
            rows.map { row in
                HealthSample(
                    start: firstDay.addingTimeInterval(row[0]),
                    end: firstDay.addingTimeInterval(row[1]),
                    value: row[2]
                )
            }
        }
        samplesBySignal = [
            .heartRate: samples(file.heartRate),
            .steps: samples(file.steps),
            .hrv: samples(file.hrv),
            .sleep: samples(file.sleep),
        ]
        self.now = now
    }

    /// Nothing to ask: the demo reads no real health data.
    func requestConsent(_ signals: Set<HealthSignal>) async throws {}

    func samples(_ signal: HealthSignal, since: Date) async throws -> [HealthSample] {
        samplesBySignal[signal, default: []].filter { $0.start >= since && $0.end <= now }
    }
}

/// Layout of `demo_health.json`, written by `ml/make_demo_data.py`: `[start, end, value]` rows.
private struct DemoHealthFile: Decodable {
    let heartRate: [[Double]]
    let steps: [[Double]]
    let hrv: [[Double]]
    let sleep: [[Double]]
}
