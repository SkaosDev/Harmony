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

    /// The music provider of the mode: demo songs, or Spotify.
    static func musicProvider(_ isOn: Bool) throws -> any MusicProvider {
        isOn ? try DemoMusicProvider() : SpotifyProvider.live
    }

    /// Playback of the mode: simulated, or the Spotify app (TODO 3.11).
    static func playback(_ isOn: Bool) -> any Playback {
        isOn ? DemoPlayback() : SpotifyRemote.shared
    }

    /// Scores new songs: MuSe, then the LLM through the Worker (none in demo mode, TODO 2.34).
    static func scorer(_ isOn: Bool) -> SongScorer? {
        guard let muse = try? MuseCatalog.bundled() else { return nil }
        return SongScorer(muse: muse, worker: isOn ? nil : WorkerClient.live())
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
