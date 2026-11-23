@preconcurrency import SpotifyiOS
import Foundation

/// Drives the Spotify app through App Remote (iOS SDK 5.0.1, TODO 3.10+, PROJECT.md §9).
/// Needs a real iPhone, the Spotify app and a Premium account.
///
/// Connection: first with the Web API token (scope `app-remote-control`); App Remote only
/// connects to a running Spotify app, so if that fails, Spotify is woken up on the first song
/// (`authorizeAndPlayURI`) and comes back to `harmony://callback` with a token (`handle(_:)`).
final class SpotifyRemote: NSObject, Playback {
    static let shared = SpotifyRemote(auth: .shared)

    enum Failure: Error, Equatable {
        /// The Spotify app is not installed: it cannot be opened.
        case spotifyNotInstalled
        /// App Remote could not connect, or lost the connection.
        case connection(String)
        /// Spotify refused a command (e.g. the account is not Premium).
        case command(String)
    }

    /// Longest wait for App Remote to answer a connection.
    static let connectTimeout: Duration = .seconds(10)
    /// Longest wait for the Spotify app to open, play and come back.
    static let wakeTimeout: Duration = .seconds(60)
    /// A song added to Spotify's queue before `play` took effect is refused
    /// (`error.request_execution_failed`), lost or doubled (tests of 23 Nov.): wait for a state
    /// sent after `play` that shows the first song at its start (`startWindow`), then try each
    /// song up to `enqueueTries` times, `enqueueRetryDelay` apart.
    static let firstSongTimeout: Duration = .seconds(5)
    static let startWindow: TimeInterval = 5
    static let enqueueTries = 3
    static let enqueueRetryDelay: Duration = .seconds(1)

    var onChange: ((PlaybackState) -> Void)?
    /// The last player state, and how many came since the connection.
    private var lastState: PlaybackState?
    private var stateCount = 0

    private let auth: SpotifyAuth
    private var connecting: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?

    private lazy var appRemote: SPTAppRemote = {
        let clientID = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? ""
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: URL(string: SpotifyAuth.redirectURI)!)
        let remote = SPTAppRemote(configuration: configuration, logLevel: .info)
        remote.delegate = self
        return remote
    }()

    init(auth: SpotifyAuth) {
        self.auth = auth
    }

    var isConnected: Bool { appRemote.isConnected }

    /// Connects to a running Spotify app with the Web API token.
    func connect() async throws {
        if appRemote.isConnected { return }
        appRemote.connectionParameters.accessToken = try await auth.validAccessToken()
        try await waitForConnection(timeout: Self.connectTimeout) { $0.appRemote.connect() }
    }

    /// Opens the Spotify app and plays `uri` (a song, `spotify:track:…`); returns once App
    /// Remote is connected, after Spotify came back to Harmony.
    func wake(playing uri: String) async throws {
        try await waitForConnection(timeout: Self.wakeTimeout) { remote in
            remote.appRemote.authorizeAndPlayURI(uri) { @Sendable opened in
                guard !opened else { return }
                Task { @MainActor in remote.finishConnecting(.failure(Failure.spotifyNotInstalled)) }
            }
        }
    }

    /// The Spotify app comes back to `harmony://callback` with an access token (or an error).
    /// Returns false for a URL that is not App Remote's.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let parameters = appRemote.authorizationParameters(from: url) else { return false }
        if let token = parameters[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        } else {
            let message = parameters[SPTAppRemoteErrorDescriptionKey] ?? "no token"
            finishConnecting(.failure(Failure.connection(message)))
        }
        return true
    }

    /// Starts `begin`, then waits for the delegate (connected or failed) or the timeout.
    private func waitForConnection(timeout: Duration, _ begin: @escaping (SpotifyRemote) -> Void) async throws {
        finishConnecting(.failure(Failure.connection("replaced by a new attempt")))
        try await withCheckedThrowingContinuation { continuation in
            connecting = continuation
            self.timeout = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                self?.finishConnecting(.failure(Failure.connection("no answer from Spotify")))
            }
            begin(self)
        }
    }

    private func finishConnecting(_ result: Result<Void, Error>) {
        timeout?.cancel()
        timeout = nil
        connecting?.resume(with: result)
        connecting = nil
    }

    private func didConnect() {
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { @Sendable _, _ in })
        finishConnecting(.success(()))
    }

    // MARK: Playback (TODO 3.11)

    /// Connects if needed, plays the first song and queues the others. If Spotify is not
    /// running, it is woken up on the first song.
    func start(spotifyIds: [String]) async throws {
        guard let first = spotifyIds.first else { return }
        let rest = spotifyIds.dropFirst()
        if !appRemote.isConnected {
            do {
                try await connect()
            } catch {
                let mark = stateCount
                try await wake(playing: Self.uri(first))
                try await enqueue(rest, after: first, statesBefore: mark)
                return
            }
        }
        let mark = stateCount
        try await command("play \(first)") { $0.play(Self.uri(first), callback: $1) }
        try await enqueue(rest, after: first, statesBefore: mark)
    }

    /// Adds `ids` to Spotify's queue once a state sent after `play` shows `first` at its start.
    private func enqueue(_ ids: some Collection<String>, after first: String, statesBefore mark: Int) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + Self.firstSongTimeout
        while clock.now < deadline {
            if stateCount > mark, let state = lastState, state.spotifyId == first, state.position < Self.startWindow { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        for id in ids {
            for attempt in 1...Self.enqueueTries {
                do {
                    try await command("enqueue \(id)") { $0.enqueueTrackUri(Self.uri(id), callback: $1) }
                    break
                } catch {
                    if attempt == Self.enqueueTries { throw error }
                    try await Task.sleep(for: Self.enqueueRetryDelay)
                }
            }
        }
    }

    func pause() async throws {
        try await command("pause") { $0.pause($1) }
    }

    func resume() async throws {
        try await command("resume") { $0.resume($1) }
    }

    func skipToNext() async throws {
        try await command("next") { $0.skip(toNext: $1) }
    }

    /// With the last token (Web API or the one Spotify gave): App Remote drops the connection
    /// when the app goes to the background (PROJECT.md §9).
    func reconnect() async {
        guard !appRemote.isConnected, appRemote.connectionParameters.accessToken != nil else { return }
        try? await waitForConnection(timeout: Self.connectTimeout) { $0.appRemote.connect() }
    }

    func disconnect() {
        // Not while Spotify is being woken up: the app is in the background on purpose.
        guard appRemote.isConnected, connecting == nil else { return }
        appRemote.disconnect()
    }

    nonisolated static func uri(_ spotifyId: String) -> String { "spotify:track:\(spotifyId)" }

    nonisolated static func spotifyId(fromURI uri: String) -> String? {
        let prefix = "spotify:track:"
        return uri.hasPrefix(prefix) ? String(uri.dropFirst(prefix.count)) : nil
    }

    /// Sends a player command and waits for Spotify's answer.
    private func command(_ name: String, _ send: (any SPTAppRemotePlayerAPI, @escaping SPTAppRemoteCallback) -> Void) async throws {
        guard appRemote.isConnected, let api = appRemote.playerAPI else { throw Failure.connection("not connected") }
        print("App Remote \(name)")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            send(api) { @Sendable _, error in
                if let error {
                    print("App Remote \(name) failed: \(error as NSError)")
                    continuation.resume(throwing: Failure.command("\(name): \(error.localizedDescription)"))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension SpotifyRemote: SPTAppRemotePlayerStateDelegate {
    nonisolated func playerStateDidChange(_ playerState: any SPTAppRemotePlayerState) {
        let state = PlaybackState(spotifyId: Self.spotifyId(fromURI: playerState.track.uri),
                                  position: Double(playerState.playbackPosition) / 1000,
                                  duration: Double(playerState.track.duration) / 1000,
                                  isPaused: playerState.isPaused)
        print("App Remote state: \(state.spotifyId ?? "-") at \(Int(state.position)) s\(state.isPaused ? ", paused" : "")")
        Task { @MainActor in
            self.lastState = state
            self.stateCount += 1
            self.onChange?(state)
        }
    }
}

extension SpotifyRemote: SPTAppRemoteDelegate {
    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in self.didConnect() }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        let message = error?.localizedDescription ?? "connection failed"
        Task { @MainActor in self.finishConnecting(.failure(Failure.connection(message))) }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        let message = error?.localizedDescription ?? "disconnected"
        Task { @MainActor in self.finishConnecting(.failure(Failure.connection(message))) }
    }
}
