#if DEBUG
import SwiftUI

/// Debug screen, state part (TODO 2.22): the 13 features and the state now, from the watch data
/// (the demo files in demo mode), before the real screens use them. Also printed, to be read from
/// the Xcode console.
struct StateDebugSection: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @State private var state: CurrentState?
    @State private var order: [String] = []
    @State private var duration: String?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        Section {
            Button("Compute state") { compute() }
            if let state {
                LabeledContent("Mode", value: describe(state.estimate.mode))
                LabeledContent("State, 0…1", value: format(state.estimate.value))
                ForEach(order, id: \.self) { name in
                    LabeledContent(name, value: format(state.features[name] ?? nil))
                }
                if let duration {
                    Text("At \(state.date.formatted(date: .omitted, time: .shortened)), in \(duration).").font(.caption)
                }
            }
            if isWorking {
                ProgressView()
            }
            if let message {
                Text(message).foregroundStyle(.red)
            }
        } header: {
            Text("State")
        } footer: {
            Text("1 = more activated than usual. Time of day only without a 7-day reference or a heart rate in the last 30 min.")
        }
        .disabled(isWorking)
    }

    private func compute() {
        isWorking = true
        message = nil
        Task {
            do {
                let clock = ContinuousClock()
                let start = clock.now
                let estimator = try StateEstimator.bundled()
                let state = try await CurrentState.compute(provider: try DemoMode.healthProvider(demoMode),
                                                           estimator: estimator)
                duration = (clock.now - start).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 2)))
                order = estimator.params.features
                self.state = state
                let features = order.map { "\($0) \(format(state.features[$0] ?? nil))" }.joined(separator: ", ")
                print("State: \(describe(state.estimate.mode)) \(format(state.estimate.value)) in \(duration!); \(features)")
            } catch {
                message = "\(error)"
            }
            isWorking = false
        }
    }

    private func describe(_ mode: StateEstimate.Mode) -> String {
        switch mode {
        case .body: "Body (13 features)"
        case .timeOnly: "Time of day only"
        }
    }

    private func format(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(3))) } ?? "unknown"
    }
}
#endif
