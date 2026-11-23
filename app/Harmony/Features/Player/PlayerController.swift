import Foundation
import Observation
import SwiftData
import UIKit

/// Plays a queue in the music app and records what the user does with it (TODO 3.11–3.15,
/// FR9, FR10): skips before 30 s, finished songs, likes and the "Did it fit?" answer.
@Observable
final class PlayerController {
    enum Phase: Equatable {
        case idle
        case starting
        case playing
        /// The music app could not play the queue: "Can't play this" (TODO 3.13).
        case cannotPlay
        /// The last song is over: "Did it fit?" (TODO 3.15).
        case ended
    }

    private(set) var phase = Phase.idle
    /// The player screen is open (TODO 3.18); Back closes it, the queue goes on in Spotify.
    var isPresented = false
    private(set) var queue: PreparedQueue?
    /// The music app's last state, and when it came.
    private(set) var state: PlaybackState?
    private(set) var stateTime = Date.distantPast
    private(set) var liked: Set<String> = []
    /// Songs the user removed from the queue (design `V2-File`).
    private(set) var removed: Set<String> = []
    /// What went wrong with the last command (pause, like…), nil when it worked.
    private(set) var problem: String?
    /// `QueueRecord.id` of the queue, also in its `FeedbackEvent`s.
    private(set) var queueId = UUID()
    /// Time from the tap on a situation to this queue on screen (TODO 3.21, NFR3: < 2 s); set by Home.
    var queueDelay: Duration?

    @ObservationIgnored private var playback: (any Playback)?
    @ObservationIgnored private var music: (any MusicProvider)?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var tracker = PlaybackTracker(queue: [])
    @ObservationIgnored private var isRecorded = false
    @ObservationIgnored var now: () -> Date = Date.init
    @ObservationIgnored var openURL: (URL) -> Void = { UIApplication.shared.open($0) }
    @ObservationIgnored var spotifyIsInstalled: () -> Bool = { UIApplication.shared.canOpenURL(URL(string: "spotify:")!) }

    /// Songs still in the queue, in order.
    var activeIds: [String] {
        queue?.entries.map(\.song.spotifyId).filter { !removed.contains($0) } ?? []
    }

    /// Place of the playing song in the queue; nil if it is not one of the queue.
    var currentIndex: Int? {
        guard let id = state?.spotifyId else { return nil }
        return queue?.entries.firstIndex { $0.song.spotifyId == id }
    }

    /// The playing song, else the first of the queue while the music app starts.
    var currentSong: TrackInfo? {
        guard let queue else { return nil }
        let index = currentIndex ?? 0
        return queue.songs.indices.contains(index) ? queue.songs[index] : nil
    }

    /// A queue plays while the player is closed: the mini-player brings it back.
    var showsMiniPlayer: Bool {
        queue != nil && !isPresented && (phase == .playing || phase == .starting)
    }

    /// Estimated position of the playing song at `date`, in seconds.
    func position(at date: Date) -> TimeInterval {
        guard let state else { return 0 }
        let position = state.isPaused ? state.position : state.position + date.timeIntervalSince(stateTime)
        return min(max(position, 0), state.duration)
    }

    /// Starts a queue; the previous one, if any, stops being followed.
    func play(_ queue: PreparedQueue, playback: any Playback, music: any MusicProvider, context: ModelContext) async {
        self.playback?.onChange = nil
        self.queue = queue
        self.playback = playback
        self.music = music
        self.context = context
        queueId = UUID()
        isRecorded = false
        liked = []
        removed = []
        state = nil
        problem = nil
        tracker = PlaybackTracker(queue: queue.entries.map(\.song.spotifyId))
        isPresented = true
        playback.onChange = { [weak self] in self?.receive($0) }
        await start()
    }

    /// "Try again" on "Can't play this".
    func retry() async {
        await start()
    }

    /// The link to Spotify (NFR6) and the fallback of FR9 (TODO 3.13). While the queue plays, it
    /// only brings the Spotify app to the front: opening a song's URI would start it again
    /// (test of 23 Nov.). Otherwise it opens the playing song (else the first of the queue), in the
    /// app or, when the app is not installed, on Spotify's web page.
    func openInSpotify() {
        guard let id = state?.spotifyId ?? activeIds.first else { return }
        recordQueue()
        if !spotifyIsInstalled() {
            openURL(URL(string: "https://open.spotify.com/track/\(id)")!)
        } else if phase == .playing {
            openURL(URL(string: "spotify:")!)
        } else {
            openURL(URL(string: SpotifyRemote.uri(id))!)
        }
    }

    func togglePause() async {
        guard let playback, let state else { return }
        await run { state.isPaused ? try await playback.resume() : try await playback.pause() }
    }

    /// Next song; on the last one, the queue ends ("Did it fit?") and the music pauses instead
    /// of going on with songs outside the queue.
    func next() async {
        guard let playback else { return }
        if let current = state?.spotifyId, tracker.isAtOrAfterLastSong(current) {
            handle(tracker.endNow(at: now()))
            await run { try await playback.pause() }
        } else {
            await run { try await playback.skipToNext() }
        }
    }

    /// Adds the playing song to the user's liked songs (TODO 3.14).
    func like() async {
        guard let id = state?.spotifyId, let music, !liked.contains(id) else { return }
        await run {
            try await music.save(spotifyId: id)
            liked.insert(id)
            record(.like, spotifyId: id, seconds: nil)
        }
    }

    /// Removes a coming song from the music app's queue; nothing is recorded for it. Should it
    /// still start (the removal failed), it is passed.
    func remove(_ spotifyId: String) {
        guard spotifyId != state?.spotifyId else { return }
        removed.insert(spotifyId)
        tracker.removed = removed
        Task { [playback] in
            do {
                try await playback?.remove(spotifyId: spotifyId)
            } catch {
                print("Song not removed from the music app: \(error)")
            }
        }
    }

    /// "Did it fit?": Yes, Nope, or nil for Skip, which records nothing (TODO 3.15).
    func answer(fits: Bool?) {
        if let fits {
            record(fits ? .fitYes : .fitNo, spotifyId: nil, seconds: nil)
        }
        playback?.onChange = nil
        phase = .idle
        queue = nil
        state = nil
        isPresented = false
    }

    /// App Remote drops its connection in the background (PROJECT.md §9, TODO 3.12).
    func enterBackground() {
        playback?.disconnect()
    }

    func enterForeground() async {
        guard phase == .playing, let playback else { return }
        await playback.reconnect()
    }

    private func start() async {
        guard let playback else { return }
        phase = .starting
        do {
            try await playback.start(spotifyIds: activeIds)
            recordQueue()
            if phase == .starting { phase = .playing }
        } catch {
            print("Playback failed: \(error)")
            phase = .cannotPlay
        }
    }

    private func receive(_ newState: PlaybackState) {
        let time = now()
        let events = tracker.update(newState, at: time)
        state = newState
        stateTime = time
        handle(events)
    }

    private func handle(_ events: [PlaybackTracker.Event]) {
        for event in events {
            switch event {
            case let .skip(id, seconds):
                record(.skip, spotifyId: id, seconds: seconds)
            case let .finish(id, seconds):
                record(.finish, spotifyId: id, seconds: seconds)
            case .passRemoved:
                Task { [weak self] in await self?.run { try await self?.playback?.skipToNext() } }
            case .end:
                phase = .ended
            }
        }
    }

    private func record(_ event: FeedbackType, spotifyId: String?, seconds: Double?) {
        guard let context else { return }
        recordQueue()
        context.insert(FeedbackEvent(queueId: queueId, spotifyId: spotifyId, event: event, seconds: seconds, time: now()))
        try? context.save()
    }

    /// The queue is stored once, when it starts playing (or opens in Spotify).
    private func recordQueue() {
        guard !isRecorded, let queue, let context, let music else { return }
        do {
            try QueueMaker(context: context, catalog: nil, music: music).record(queue, id: queueId, at: now())
            isRecorded = true
        } catch {
            print("Queue not recorded: \(error)")
        }
    }

    private func run(_ work: () async throws -> Void) async {
        do {
            try await work()
            problem = nil
        } catch {
            problem = "\(error)"
        }
    }
}
