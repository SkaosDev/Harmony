#if DEBUG
import SwiftData
import SwiftUI

/// Developer screen, Debug builds only, opened from Settings (not in the design).
/// Content: demo mode switch (TODO 1.17); Apple Health (TODO 1.28+); Spotify outside demo mode
/// (TODO 1.18+); current features and state (TODO 2.22).
struct DebugView: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @Query private var tracks: [Track]
    @Query private var scores: [SongScore]
    /// Demo samples of the last 14 days, per signal; empty outside demo mode.
    @State private var demoSamples: [HealthSignal: Int] = [:]

    private static let signals: [HealthSignal] = [.heartRate, .steps, .hrv, .sleep]

    var body: some View {
        Form {
            Section {
                Toggle("Demo mode", isOn: $demoMode)
            } footer: {
                Text("Synthetic songs and watch data (Resources/demo), in a separate in-memory store. Real data are not touched.")
            }
            Section("Store") {
                LabeledContent("Tracks", value: tracks.count, format: .number)
                LabeledContent("Song scores", value: scores.count, format: .number)
            }
            HealthDebugSection()
            if demoMode {
                Section("Demo health samples, last 14 days") {
                    ForEach(Self.signals, id: \.self) { signal in
                        LabeledContent(signal.rawValue, value: demoSamples[signal] ?? 0, format: .number)
                    }
                }
            } else {
                SpotifyDebugSection()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Debug")
        .task(id: demoMode) { await countDemoSamples() }
    }

    private func countDemoSamples() async {
        demoSamples = [:]
        guard demoMode, let provider = try? DemoHealthProvider() else { return }
        let since = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
        for signal in Self.signals {
            demoSamples[signal] = (try? await provider.samples(signal, since: since))?.count
        }
    }
}
#endif
