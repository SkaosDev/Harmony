import Foundation
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
        try seedAnswers(in: container.mainContext, now: .now)
        return container
    }

    /// Made-up answers to "Energy right now?" over the last two weeks, two a day, recorded through
    /// the real personal layer so that the "Your answers" card of About shows a curve (TODO 6.16,
    /// 4.13). Its own `UserDefaults` suite keeps the user's day of use untouched.
    static func seedAnswers(in context: ModelContext, now: Date) throws {
        let suite = "demoMode.answers"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let recorder = CheckInRecorder(context: context, defaults: defaults)
        for (index, energy) in demoAnswers.enumerated() {
            let date = now - 2 * 3600 - Double(demoAnswers.count - 1 - index) * 12 * 3600
            try recorder.record(energy: energy, channel: .notification, at: date,
                                common: StateEstimate(value: 0.5 + 0.04 * sin(Double(index)), mode: .body))
        }
    }

    /// Mixed at first, then more often above the usual.
    private static let demoAnswers = [0, -2, 2, 0, 0, 2, -2, 0, 2, 2, 0, 2, 2, 2, 2, 0, 2, 2, 0, 2, 2, 2, 2, 0, 0, 2, 2, 2]
}
