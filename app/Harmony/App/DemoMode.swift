import SwiftData

/// Demo mode (TODO 1.17, FR12), switched on in the Debug screen: the app runs on the synthetic
/// files of `Resources/demo/` instead of Spotify and Apple Health, in its own in-memory store,
/// so demo songs never mix with the user's real data.
enum DemoMode {
    /// `UserDefaults` key of the switch.
    static let key = "demoMode"

    /// The health provider of the mode: demo files, or Apple Health.
    static func healthProvider(_ isOn: Bool) throws -> any HealthProvider {
        isOn ? try DemoHealthProvider() : HealthKitProvider.live
    }

    /// An in-memory store holding the demo library and its scores.
    static func container() throws -> ModelContainer {
        let container = try HarmonyStore.container(inMemory: true)
        let music = try DemoMusicProvider()
        music.tracks().forEach(container.mainContext.insert)
        music.scores().forEach(container.mainContext.insert)
        try container.mainContext.save()
        return container
    }
}
