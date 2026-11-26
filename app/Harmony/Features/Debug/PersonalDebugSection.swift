#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, personal layer (TODO 6.13, design v2 §8 S8): b_E and b_V, the common and personal
/// probabilities, the labelled answers, where a queue's e0 would come from now, and the planned
/// questions. "Send a test question in 15 s" is for the lock screen and Apple Watch check (6.10).
struct PersonalDebugSection: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @AppStorage(QuestionSettings.pilotFourKey) private var pilotFour = false
    @Environment(\.modelContext) private var context
    @Query(sort: \CheckIn.answeredAt, order: .reverse) private var checkIns: [CheckIn]
    @Query(sort: \PromptLog.scheduledAt, order: .reverse) private var prompts: [PromptLog]
    @State private var state: CurrentState?
    @State private var personal: PersonalState?
    @State private var start: QueueStart?
    @State private var message: String?

    var body: some View {
        Section {
            LabeledContent("Mode", value: PersonalMode.current == .shadow ? "Shadow" : "Active")
            LabeledContent("Questions", value: QuestionSettings.isEnabled() ? "On" : "Off")
            // Pilot only (`docs/pilot-protocol.md` §10.6): 09–11, 12–14, 15–17 and 18–21.
            Toggle("Pilot: 4 questions a day", isOn: $pilotFour)
                .onChange(of: pilotFour) {
                    Task { await CheckInNotifications.shared.reschedule(context: context) }
                }
            Button("Compute") { compute() }
            if let state, let personal, let start {
                LabeledContent("p common", value: format(state.estimate.value))
                LabeledContent("p personal", value: format(personal.energy.probability))
                LabeledContent("b_E", value: format(personal.energy.offset))
                LabeledContent("Labelled energy answers, 14 days", value: personal.energy.count, format: .number)
                LabeledContent("b_V (internal)", value: format(personal.pleasantness.offset))
                LabeledContent("Labelled pleasantness answers", value: personal.pleasantness.count, format: .number)
                LabeledContent("Rank", value: "\(format(state.rank)) of \(state.gridProbabilities.count) points")
                LabeledContent("e0 now", value: "\(format(start.e0)) (\(start.e0Source.rawValue))")
                LabeledContent("v0", value: format(start.v0))
            }
            LabeledContent("Check-ins", value: checkIns.count, format: .number)
            LabeledContent("Waiting for their state", value: checkIns.filter { $0.zEnergy == nil }.count, format: .number)
            ForEach(checkIns.prefix(5)) { checkIn in
                LabeledContent(checkIn.answeredAt.formatted(date: .abbreviated, time: .shortened),
                               value: "\(checkIn.energy) \(checkIn.channel.rawValue), day \(checkIn.dayOfUse)")
            }
            ForEach(prompts.filter { $0.scheduledAt > .now }.reversed()) { prompt in
                LabeledContent("Question planned", value: prompt.scheduledAt.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Questions answered / not now / ignored",
                           value: [PromptOutcome.answered, .notNow, .ignored]
                               .map { outcome in "\(prompts.filter { $0.outcome == outcome }.count)" }
                               .joined(separator: " / "))
            Button("Send a test question in 15 s") { sendTest() }
            if let message {
                Text(message).font(.caption)
            }
        } header: {
            Text("Personal layer")
        } footer: {
            Text("Lock the phone after the test button, then answer on the lock screen or the watch.")
        }
    }

    private func compute() {
        Task {
            do {
                let state = try await CurrentState.compute(provider: try DemoMode.healthProvider(demoMode),
                                                           estimator: try StateEstimator.bundled())
                let personal = try CheckInRecorder(context: context).personal(at: state.date, common: state.estimate)
                self.state = state
                self.personal = personal
                start = QueueStart.choose(state: state, personal: personal, mode: .current)
                message = nil
            } catch {
                message = "\(error)"
            }
        }
    }

    private func sendTest() {
        Task {
            if await CheckInNotifications.shared.requestAuthorization() {
                do {
                    try await CheckInNotifications.shared.sendTest(in: 15, context: context)
                    message = "Question in 15 s."
                } catch {
                    message = "\(error)"
                }
            } else {
                message = "Notifications are not allowed."
            }
        }
    }

    private func format(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(3))) } ?? "unknown"
    }
}
#endif
