#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, playback part (TODO 3.10–3.15): checks App Remote and the recorded events on a
/// real iPhone before the player screens exist (TODO 3.18).
struct PlayerDebugSection: View {
    private let remote = SpotifyRemote.shared
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Environment(PlayerController.self) private var player
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @Query(sort: \FeedbackEvent.time, order: .reverse) private var events: [FeedbackEvent]
    @State private var status = "Not connected"
    @State private var isWorking = false

    var body: some View {
        if !demoMode {
            Section("Spotify App Remote") {
                LabeledContent("Status", value: status)
                Button("Connect with the Web API token") {
                    run("Connected with the Web API token") { try await remote.connect() }
                }
                if let song = tracks.first {
                    Button("Wake Spotify on \(song.title), then connect") {
                        run("Connected after waking Spotify") { try await remote.wake(playing: SpotifyRemote.uri(song.spotifyId)) }
                    }
                }
                if isWorking {
                    ProgressView()
                }
            }
            .disabled(isWorking)
        }
        Section("Last queue") {
            if tracks.count >= 3 {
                Button("Play test queue (3 latest library songs)") { playTestQueue() }
            }
            LabeledContent("Phase", value: "\(player.phase)")
            if let index = player.currentIndex, let queue = player.queue {
                LabeledContent("Song", value: "\(index + 1) / \(queue.entries.count)  \(queue.songs[index].title)")
            }
            if player.phase == .playing || player.phase == .ended {
                Button(player.state?.isPaused == true ? "Resume" : "Pause") { Task { await player.togglePause() } }
                Button("Next") { Task { await player.next() } }
                Button("Like") { Task { await player.like() } }
                Button("Open in Spotify") { player.openInSpotify() }
            }
            if player.phase == .cannotPlay {
                Button("Try again") { Task { await player.retry() } }
                Button("Open in Spotify") { player.openInSpotify() }
            }
            if player.phase == .ended {
                Button("Did it fit? Yes") { player.answer(fits: true) }
                Button("Did it fit? Nope") { player.answer(fits: false) }
                Button("Did it fit? Skip") { player.answer(fits: nil) }
            }
            if let problem = player.problem {
                Text(problem).foregroundStyle(.red)
            }
            ForEach(events.filter { $0.queueId == player.queueId }) { event in
                LabeledContent(event.event.rawValue,
                               value: [event.spotifyId, event.seconds.map { String(format: "%.0f s", $0) }]
                                   .compactMap(\.self).joined(separator: "  "))
            }
        }
    }

    private func playTestQueue() {
        let entries = tracks.prefix(3).map { track in
            QueueEntry(song: QueueCandidate(spotifyId: track.spotifyId, title: track.title, artists: track.artists,
                                            energy: 0.5, positivity: 0.5, origin: .neutral),
                       target: 0.5, info: nil)
        }
        let songs = tracks.prefix(3).map {
            TrackInfo(spotifyId: $0.spotifyId, title: $0.title, artists: $0.artists, coverURL: $0.coverURL)
        }
        let queue = PreparedQueue(situation: .wakeUp, e0: 0.5, reason: "Debug test queue.", entries: Array(entries), songs: Array(songs))
        Task {
            do {
                try await player.play(queue, playback: DemoMode.playback(demoMode), music: DemoMode.musicProvider(demoMode),
                                      context: context)
            } catch {
                status = "Failed: \(error)"
            }
        }
    }

    private func run(_ success: String, _ work: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            do {
                try await work()
                status = success
            } catch {
                status = "Failed: \(error)"
            }
            isWorking = false
        }
    }
}
#endif
