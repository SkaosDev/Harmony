import Testing
@testable import Harmony

/// Smoke test: the test target builds against the app module and runs.
struct HarmonyTests {
    @Test @MainActor func appModuleIsReachable() {
        _ = ContentView()
    }
}
