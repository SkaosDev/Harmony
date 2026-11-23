#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, playback part (TODO 3.10+): checks App Remote on a real iPhone before the
/// player screens exist (TODO 3.18).
struct PlayerDebugSection: View {
    private let remote = SpotifyRemote.shared
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @State private var status = "Not connected"
    @State private var isWorking = false

    var body: some View {
        Section("Spotify App Remote") {
            LabeledContent("Status", value: status)
            Button("Connect with the Web API token") {
                run("Connected with the Web API token") { try await remote.connect() }
            }
            if let song = tracks.first {
                Button("Wake Spotify on \(song.title), then connect") {
                    run("Connected after waking Spotify") { try await remote.wake(playing: "spotify:track:\(song.spotifyId)") }
                }
            }
            if tracks.count >= 5 {
                Button("Play the 5 latest library songs") {
                    let ids = tracks.prefix(5).map(\.spotifyId)
                    run("Playing 5 songs: check Spotify's queue") { try await remote.start(spotifyIds: ids) }
                }
            }
            if isWorking {
                ProgressView()
            }
        }
        .disabled(isWorking)
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
