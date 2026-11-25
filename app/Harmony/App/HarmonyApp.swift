import SwiftData
import SwiftUI

/// Sets up the check-in questions at launch, before an answer given on the lock screen or the
/// watch reaches the app (TODO 6.10).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let notifications = CheckInNotifications.shared
        notifications.container = { HarmonyApp.container }
        notifications.healthProvider = { try DemoMode.healthProvider(UserDefaults.standard.bool(forKey: DemoMode.key)) }
        notifications.register()
        return true
    }
}

@main
struct HarmonyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(DemoMode.key) private var demoMode = false
    /// The queue being played, shared by Home, the player and Debug (TODO 3.11+).
    @State private var player: PlayerController = {
        let player = PlayerController()
        player.onQueueRecorded = { @MainActor context, now in
            Task { await CheckInNotifications.shared.reschedule(context: context, now: now) }
        }
        return player
    }()
    /// Library import and scores, shared by the onboarding, the launch screen and Settings (TODO 3.16).
    @State private var library = LibrarySync()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(Self.container)
                .environment(player)
                .environment(library)
                // The Spotify app comes back here after being woken up for App Remote (TODO 3.10).
                .onOpenURL { SpotifyRemote.shared.handle($0) }
        }
    }

    /// The store in use: the demo one while demo mode is on.
    static var container: ModelContainer {
        UserDefaults.standard.bool(forKey: DemoMode.key) ? demoStore : store
    }

    /// The user's data, on the phone.
    private static let store = open { try HarmonyStore.container() }
    /// Demo mode's store, built the first time demo mode is on (a `static let` is lazy).
    private static let demoStore = open { try DemoMode.container() }

    private static func open(_ makeContainer: () throws -> ModelContainer) -> ModelContainer {
        do {
            return try makeContainer()
        } catch {
            fatalError("Cannot open the store: \(error)")
        }
    }
}
