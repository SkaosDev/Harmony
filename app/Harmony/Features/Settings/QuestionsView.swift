import SwiftData
import SwiftUI

/// `V2-Questions` (TODO 6.13): the two daily questions on or off, their windows, and "Reset what
/// Harmony learned". The time picker is not in the design: a system sheet.
struct QuestionsView: View {
    @AppStorage(QuestionSettings.enabledKey) private var enabled = false
    @Environment(\.modelContext) private var context
    @State private var windows = QuestionSettings.windows()
    /// The window being changed.
    @State private var editing: Int?
    @State private var confirmsReset = false
    @State private var problem: String?

    var body: some View {
        SettingsPage(title: CheckInTexts.questions) {
            CardText(text: CheckInTexts.questionsText)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CheckInTexts.questions)
                        .font(Theme.font(size: 16, bold: true))
                        .designLineHeight(16 * 1.2)
                        .foregroundStyle(Theme.textPrimary)
                    Text(CheckInTexts.questionsSwitch)
                        .font(Theme.font(size: 13))
                        .designLineHeight(13 * 1.3)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DesignSwitch(isOn: Binding(get: { enabled }, set: { turn($0) }), label: CheckInTexts.questions)
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 8) {
                CardLabel(text: CheckInTexts.askBetween)
                VStack(spacing: 12) {
                    window(0)
                    CardDivider()
                    window(1)
                }
                .card()
                CardText(text: CheckInTexts.windowsText)
            }
        } bottom: {
            VStack(alignment: .leading, spacing: 12) {
                CardText(text: CheckInTexts.resetText)
                PillButton(CheckInTexts.reset, style: .outline) { confirmsReset = true }
            }
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let editing {
                WindowPicker(name: CheckInTexts.windowNames[editing], window: windows[editing]) { save($0, at: editing) }
            }
        }
        .confirmationDialog(CheckInTexts.resetQuestion, isPresented: $confirmsReset, titleVisibility: .visible) {
            Button(CheckInTexts.resetButton, role: .destructive) { Task { await reset() } }
        } message: {
            Text(CheckInTexts.resetText)
        }
        .alert("Something went wrong", isPresented: .constant(problem != nil)) {
            Button("OK") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
    }

    private func window(_ index: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(CheckInTexts.windowNames[index])
                    .font(Theme.font(size: 16))
                    .designLineHeight(16 * 1.4)
                    .foregroundStyle(Theme.textSecondary)
                Text("\(Self.clock(windows[index].start)) – \(Self.clock(windows[index].end))")
                    .font(Theme.font(size: 20, bold: true))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer(minLength: 0)
            Button { editing = index } label: {
                Text(CheckInTexts.change)
                    .font(Theme.font(size: 13, bold: true))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// "10:00" from minutes after midnight.
    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// On only when iOS allows the notifications.
    private func turn(_ on: Bool) {
        Task {
            enabled = on ? await CheckInNotifications.shared.requestAuthorization() : false
            await CheckInNotifications.shared.reschedule(context: context)
        }
    }

    private func save(_ window: CheckInWindow, at index: Int) {
        QuestionSettings.setWindow(window, at: index)
        windows = QuestionSettings.windows()
        Task { await CheckInNotifications.shared.reschedule(context: context) }
    }

    /// The answers and the questions' log go, the offsets are back to 0; the questions stay on.
    private func reset() async {
        do {
            CheckInNotifications.shared.removeAll()
            try CheckInRecorder(context: context).reset()
        } catch {
            problem = UserMessage.text(for: error)
        }
        await CheckInNotifications.shared.reschedule(context: context)
    }
}

/// The system sheet that changes a window: from and to, within 07:00–22:00, at least an hour.
private struct WindowPicker: View {
    let name: String
    let onSave: (CheckInWindow) -> Void
    @State private var start: Date
    @State private var end: Date
    @Environment(\.dismiss) private var dismiss

    init(name: String, window: CheckInWindow, onSave: @escaping (CheckInWindow) -> Void) {
        self.name = name
        self.onSave = onSave
        _start = State(initialValue: Self.date(window.start))
        _end = State(initialValue: Self.date(window.end))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("From", selection: $start, in: Self.date(CheckInSchedule.earliest)...Self.date(CheckInSchedule.latest),
                           displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $end, in: Self.date(CheckInSchedule.earliest)...Self.date(CheckInSchedule.latest),
                           displayedComponents: .hourAndMinute)
                if !isValid {
                    Text(CheckInTexts.windowRule)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(CheckInWindow(start: Self.minutes(start), end: Self.minutes(end)))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var isValid: Bool {
        Self.minutes(end) - Self.minutes(start) >= CheckInSchedule.shortestWindow
            && Self.minutes(start) >= CheckInSchedule.earliest && Self.minutes(end) <= CheckInSchedule.latest
    }

    private static func date(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now)!
    }

    private static func minutes(_ date: Date) -> Int {
        let clock = Calendar.current.dateComponents([.hour, .minute], from: date)
        return clock.hour! * 60 + clock.minute!
    }
}

#Preview {
    NavigationStack { QuestionsView() }
}
