import Foundation

/// A music service: sign-in, library import, song lookup, playback and likes (TODO 1.13).
/// The core (scores, state, queue) only sees this protocol, never Spotify itself
/// (PROJECT.md §4.3, FR14). Implementations: `SpotifyProvider` (TODO 1.18+), `DemoMusicProvider`.
protocol MusicProvider {
    func signIn() async throws
    /// The user's library (liked songs, top tracks, recently played), not yet inserted in the store.
    /// The same song can come back twice; `Track.spotifyId` is unique, so inserting merges them.
    func importLibrary() async throws -> [Track]
    /// Title, artists and cover of any song, in the library or not (checks a suggestion, TODO 3.6).
    /// Nil if the service has no song with this ID.
    func lookUp(spotifyId: String) async throws -> TrackInfo?
    /// Plays the first song and queues the others, in order.
    func play(spotifyIds: [String]) async throws
    /// Adds the song to the user's liked songs.
    func save(spotifyId: String) async throws
}

/// A song as the music service describes it, without anything stored by the app.
struct TrackInfo: Equatable {
    let spotifyId: String
    let title: String
    /// In the service's order; the first one is the main artist.
    let artists: [String]
    let coverURL: URL?
}
