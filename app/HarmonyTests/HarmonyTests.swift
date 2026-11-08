import Testing
@testable import Harmony

@MainActor
struct HarmonyTests {
    /// Smoke test: the test target builds against the app module and runs.
    @Test func rootViewBuilds() {
        _ = RootView()
    }

    /// The tab bar follows `docs/design/`: Home, Library, Settings, in this order.
    @Test func tabsFollowTheDesign() {
        #expect(AppTab.allCases.map(\.title) == ["Home", "Library", "Settings"])
    }
}
