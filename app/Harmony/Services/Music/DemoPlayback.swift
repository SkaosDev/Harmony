import Foundation

/// Playback of demo mode and the simulator (FR12): no Spotify, the songs "play" in real time,
/// each for `songSeconds`, and the state is sent like App Remote sends it (at each change).
final class DemoPlayback: Playback {
    static let songSeconds: TimeInterval = 180

    var onChange: ((PlaybackState) -> Void)?

    private var spotifyIds: [String] = []
    private var index = 0
    /// Position at `since`, in seconds.
    private var position: TimeInterval = 0
    private var since = Date.now
    private var isPaused = true
    private var songEnd: Task<Void, Never>?

    func start(spotifyIds: [String]) async throws {
        self.spotifyIds = spotifyIds
        index = 0
        play(from: 0)
    }

    func pause() async throws {
        guard !isPaused else { return }
        position += Date.now.timeIntervalSince(since)
        isPaused = true
        songEnd?.cancel()
        send()
    }

    func resume() async throws {
        guard isPaused, index < spotifyIds.count else { return }
        play(from: position)
    }

    func skipToNext() async throws {
        next()
    }

    func remove(spotifyId: String) async throws {
        guard let place = spotifyIds.firstIndex(of: spotifyId), place > index else { return }
        spotifyIds.remove(at: place)
    }

    func reconnect() async {}

    func disconnect() {}

    private func play(from seconds: TimeInterval) {
        position = seconds
        since = .now
        isPaused = index >= spotifyIds.count
        send()
        songEnd?.cancel()
        guard !isPaused else { return }
        let left = Self.songSeconds - seconds
        songEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(left))
            guard !Task.isCancelled else { return }
            self?.next()
        }
    }

    private func next() {
        index += 1
        play(from: 0)
    }

    private func send() {
        let id = index < spotifyIds.count ? spotifyIds[index] : nil
        onChange?(PlaybackState(spotifyId: id, position: position, duration: Self.songSeconds, isPaused: isPaused))
    }
}
