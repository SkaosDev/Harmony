import SwiftData
import SwiftUI

/// Root screen: the selected tab above the design's tab bar. At each opening of the app, it
/// brings the watch summaries up to date (TODO 1.29, 1.32).
struct RootView: View {
    @State private var selection: AppTab = .home
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @AppStorage(DemoMode.key) private var demoMode = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .home: HomeView()
                case .library: LibraryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $selection)
        }
        // The tab bar reaches the bottom edge and keeps its own 26 pt bottom padding, as in the design.
        .ignoresSafeArea(edges: .bottom)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active { updateHealth() }
        }
        .onChange(of: demoMode) { updateHealth() }
    }

    /// Apple Health cannot be read while the phone is locked, so this runs when the app comes to
    /// the front. A failure leaves the summaries as they were: unknown, never a crash.
    private func updateHealth() {
        Task {
            do {
                let report = try await SummaryStore.update(provider: DemoMode.healthProvider(demoMode), context: context)
                if let report {
                    print("Health update: \(report)")
                }
            } catch {
                print("Health update failed: \(error)")
            }
        }
    }
}

#Preview {
    RootView()
}
