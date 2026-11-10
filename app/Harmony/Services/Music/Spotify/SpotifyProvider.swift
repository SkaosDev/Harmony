import Foundation

/// The real music provider: the user's Spotify account (PROJECT.md §4.3, §9).
/// Library through the Web API (TODO 1.23+); playback through App Remote later (TODO 3.10+).
struct SpotifyProvider: MusicProvider {
    /// The app's provider, on the signed-in account.
    static let live = SpotifyProvider(auth: .shared, api: SpotifyAPI(auth: .shared))

    let auth: SpotifyAuth
    let api: SpotifyAPI
    var now: () -> Date = Date.init

    func signIn() async throws {
        try await auth.signIn()
    }

    /// Liked songs, then the 50 top tracks of the last ~6 months and the 50 last songs played
    /// (TODO 1.25). One `Track` per song: a song in several lists keeps the first of
    /// saved, top, recent. `addedAt` is the like date, the import date (top) or the last play.
    func importLibrary() async throws -> [Track] {
        let saved = try await savedTracks()
        let top = try await api.get("me/top/tracks?limit=50&time_range=medium_term", as: SpotifyPage<SpotifyTrack>.self)
            .items.compactMap { $0.makeTrack(source: .top, addedAt: now()) }
        // Newest first, so a song played twice keeps its last play.
        let recent = try await api.get("me/player/recently-played?limit=50", as: SpotifyPage<SpotifyPlayedItem>.self)
            .items.compactMap { $0.track.makeTrack(source: .recent, addedAt: $0.playedAt) }
        var seen = Set<String>()
        return (saved + top + recent).filter { seen.insert($0.spotifyId).inserted }
    }

    /// Every liked song, 50 per page (Spotify's maximum), following each page's `next` (TODO 1.23).
    func savedTracks() async throws -> [Track] {
        var tracks: [Track] = []
        var next: String? = "me/tracks?limit=50"
        while let url = next {
            let page = try await api.get(url, as: SpotifyPage<SpotifySavedItem>.self)
            tracks += page.items.compactMap { $0.track?.makeTrack(source: .saved, addedAt: $0.addedAt) }
            next = page.next
        }
        return tracks
    }

    /// `GET /tracks/{id}`. Spotify answers 404 for an unknown ID and 400 for a malformed one.
    func lookUp(spotifyId: String) async throws -> TrackInfo? {
        guard let path = spotifyId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        do {
            return try await api.get("tracks/\(path)", as: SpotifyTrack.self).info
        } catch SpotifyError.http(404), SpotifyError.http(400) {
            return nil
        }
    }

    func play(spotifyIds: [String]) async throws {
        throw SpotifyError.notImplemented
    }

    func save(spotifyId: String) async throws {
        throw SpotifyError.notImplemented
    }
}
