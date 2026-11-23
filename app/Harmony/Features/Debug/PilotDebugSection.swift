#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, pilot part (`docs/pilot-protocol.md` §4–§7): starts or stops the pilot, shows
/// the pilot day and the kind of today's queues (TODO 4.4), exports the anonymous pilot file
/// (TODO 4.5).
struct PilotDebugSection: View {
    @Environment(\.modelContext) private var context
    @State private var schedule = PilotSchedule.stored()
    @State private var export: MyDataView.ExportFile?
    @State private var problem: String?

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
                Button("Export pilot data") { exportFile(schedule) }
            }
            if let problem {
                Text(problem).foregroundStyle(.red)
            }
        } header: {
            Text("Pilot")
        } footer: {
            Text("Switch on once, on day 1: it saves today as the start and a new random draw. Switching off ends the pilot.")
        }
        .sheet(item: $export) { ShareSheet(url: $0.url) }
    }

    private func exportFile(_ schedule: PilotSchedule) {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("harmony-pilot.json")
            try PilotExport.json(from: context, schedule: schedule).write(to: url, options: [.atomic, .completeFileProtection])
            export = MyDataView.ExportFile(url: url)
            problem = nil
        } catch {
            problem = UserMessage.text(for: error)
        }
    }
}
#endif
