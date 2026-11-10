/// What can go wrong with Spotify (TODO 1.18+).
enum SpotifyError: Error, Equatable {
    /// `SPOTIFY_CLIENT_ID` is empty: `Config.xcconfig` is missing (see app/README.md).
    case missingClientID
    case notSignedIn
    /// The login page returned an error (e.g. `access_denied`) or an unexpected callback.
    case loginFailed(String)
    /// Spotify answered with this HTTP status.
    case http(Int)
    /// Too many requests, and Spotify asks to wait longer than `SpotifyAPI.longestWait` seconds.
    case rateLimited(retryAfter: Int)
    /// Playback and likes come with the Spotify SDK (TODO 3.11, 3.14).
    case notImplemented
}
