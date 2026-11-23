import SwiftData
import SwiftUI

@main
struct HarmonyApp: App {
    @AppStorage(DemoMode.key) private var demoMode = false
    /// The queue being played, shared by Home, the player and Debug (TODO 3.11+).
    @State private var player = PlayerController()
    /// Library import and scores, shared by the onboarding, the launch screen and Settings (TODO 3.16).
    @State private var library = LibrarySync()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(demoMode ? Self.demoStore : Self.store)
                .environment(player)
                .environment(library)
                // The Spotify app comes back here after being woken up for App Remote (TODO 3.10).
                .onOpenURL { SpotifyRemote.shared.handle($0) }
        }
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
