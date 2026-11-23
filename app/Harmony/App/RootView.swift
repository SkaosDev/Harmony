import SwiftData
import SwiftUI

/// Root screen: the onboarding the first time (TODO 3.16), "Loading your library" until the first
/// import is done, then the selected tab above the design's tab bar. At each opening of the app,
/// it brings the watch summaries up to date (TODO 1.29, 1.32).
struct RootView: View {
    /// `UserDefaults` key: true once the onboarding is done ("Go to home").
    static let onboardedKey = "onboarded"

    @AppStorage(Self.onboardedKey) private var onboarded = false
    @Environment(LibrarySync.self) private var library
    @State private var selection: AppTab = .home
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(PlayerController.self) private var player

    var body: some View {
        Group {
            if !onboarded {
                OnboardingView { onboarded = true }
            } else if library.importedAt == nil {
                LaunchView()
            } else {
                tabs
            }
        }
        .onChange(of: scenePhase, initial: true) {
            switch scenePhase {
            case .active:
                updateHealth()
                Task { await player.enterForeground() }
            case .background:
                player.enterBackground()
            default:
                break
            }
        }
        .onChange(of: demoMode) { updateHealth() }
        // "Did it fit?" at the end of every queue, whatever the screen (TODO 3.15).
        .fullScreenCover(isPresented: .constant(player.phase == .ended)) {
            FeedbackView { player.answer(fits: $0) }
        }
    }

    private var tabs: some View {
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
        .environment(PlayerController())
        .environment(LibrarySync())
}
