import Foundation
import Testing
@testable import Harmony

/// TODO 3.11 in demo mode.
@MainActor
struct DemoPlaybackTests {
    @Test func playsTheQueueInOrderThenStops() async throws {
        let playback = DemoPlayback()
        var states: [PlaybackState] = []
        playback.onChange = { states.append($0) }

        try await playback.start(spotifyIds: ["a", "b"])
        #expect(states.last?.spotifyId == "a")
        #expect(states.last?.isPaused == false)
        #expect(states.last?.duration == DemoPlayback.songSeconds)

        try await playback.pause()
        #expect(states.last?.isPaused == true)
        try await playback.resume()
        #expect(states.last?.isPaused == false && states.last?.spotifyId == "a")

        try await playback.skipToNext()
        #expect(states.last?.spotifyId == "b" && states.last?.position == 0)
        try await playback.skipToNext()
        #expect(states.last?.spotifyId == nil && states.last?.isPaused == true)
    }

    @Test func spotifyUrisRoundTrip() {
        #expect(SpotifyRemote.uri("abc") == "spotify:track:abc")
        #expect(SpotifyRemote.spotifyId(fromURI: "spotify:track:abc") == "abc")
        #expect(SpotifyRemote.spotifyId(fromURI: "spotify:episode:abc") == nil)
    }
}
