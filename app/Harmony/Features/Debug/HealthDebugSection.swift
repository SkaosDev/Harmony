#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, Apple Health part (TODO 1.28+): ask for access and check the readings before
/// the real screens exist (onboarding 3.16, health settings 3.19). Demo mode reads the demo files.
struct HealthDebugSection: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Query private var consents: [Consent]
    @State private var askingAccess = false
    @State private var message: String?

    var body: some View {
        Section("Apple Health") {
            LabeledContent("Access asked", value: consents.isEmpty ? "No" : "Yes")
            Button("Ask for access") { askingAccess = true }
            if let message {
                Text(message).foregroundStyle(.red)
            }
        }
        .fullScreenCover(isPresented: $askingAccess) {
            HealthPermissionView { Task { await askAccess() } }
        }
    }

    /// System sheet for the four signals, then the user's choice in `Consent` (TODO 1.28).
    private func askAccess() async {
        message = nil
        do {
            try await DemoMode.healthProvider(demoMode).requestConsent(Set(HealthSignal.allCases))
            for signal in HealthSignal.allCases {
                context.insert(Consent(source: signal, granted: true, time: .now))
            }
            try context.save()
        } catch {
            message = "\(error)"
        }
        askingAccess = false
    }
}
#endif
