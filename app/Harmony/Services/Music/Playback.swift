import Foundation

/// What the music app is playing, as it last said (TODO 3.11). The position is not sent
/// continuously: between two states it moves on with time, unless paused.
nonisolated struct PlaybackState: Equatable, Sendable {
    /// Nil when nothing is playing.
    var spotifyId: String?
    /// Seconds into the song when the state was sent.
    var position: TimeInterval
    /// Length of the song, in seconds.
    var duration: TimeInterval
    var isPaused: Bool
}

/// Playback of a queue in the music app (TODO 3.10–3.13): `SpotifyRemote` on an iPhone,
/// `DemoPlayback` in demo mode and on the simulator.
protocol Playback: AnyObject {
    /// Called at each change of song, pause or position jump.
    var onChange: ((PlaybackState) -> Void)? { get set }
    /// Plays the songs, in order.
    func start(spotifyIds: [String]) async throws
    /// Takes a coming song out of the queue ("Remove this song", TODO 3.18).
    func remove(spotifyId: String) async throws
    func pause() async throws
    func resume() async throws
    func skipToNext() async throws
    /// The app is back in the foreground: connects again (TODO 3.12).
    func reconnect() async
    /// The app goes to the background.
    func disconnect()
}
