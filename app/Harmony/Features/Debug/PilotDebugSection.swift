#if DEBUG
import SwiftUI

/// Debug screen, pilot part (TODO 4.4, `docs/pilot-protocol.md` §4–§6): starts or stops the
/// pilot, shows the pilot day and the kind of today's queues.
struct PilotDebugSection: View {
    @State private var schedule = PilotSchedule.stored()

    var body: some View {
        Section {
            Toggle("Pilot running", isOn: Binding(get: { schedule != nil }, set: { running in
                if running {
                    schedule = PilotSchedule.start()
                } else {
                    PilotSchedule.stop()
                    schedule = nil
                }
            }))
            if let schedule, let day = schedule.day(of: .now), let kind = schedule.kind(on: .now) {
                LabeledContent("Pilot day", value: day, format: .number)
                LabeledContent("Today's queues", value: kind == .body ? "Body" : "Time only")
            }
        } header: {
            Text("Pilot")
        } footer: {
            Text("Switch on once, on day 1: it saves today as the start and a new random draw. Switching off ends the pilot.")
        }
    }
}
#endif
