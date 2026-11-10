import SwiftData
import SwiftUI

@main
struct HarmonyApp: App {
    @AppStorage(DemoMode.key) private var demoMode = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(demoMode ? Self.demoStore : Self.store)
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
