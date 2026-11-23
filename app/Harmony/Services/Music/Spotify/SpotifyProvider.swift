import Foundation
import SwiftData

/// The real music provider: the user's Spotify account (PROJECT.md §4.3, §9).
/// Library and likes through the Web API (TODO 1.23+, 3.14); playback through App Remote (TODO 3.10+).
struct SpotifyProvider: MusicProvider {
    /// The app's provider, on the signed-in account.
    static let live = SpotifyProvider(auth: .shared, api: SpotifyAPI(auth: .shared))

    let auth: SpotifyAuth
    let api: SpotifyAPI
    var now: () -> Date = Date.init

    func signIn() async throws {
        try await auth.signIn()
    }

    /// Forgets the tokens, in the Keychain too (TODO 1.26). With a `context`, also deletes the
    /// imported songs; their scores stay, as a cache that holds no account data.
    func signOut(deletingLibraryFrom context: ModelContext? = nil) throws {
        try auth.signOut()
        if let context {
            try context.delete(model: Track.self)
            try context.save()
        }
    }

    /// Liked songs, then the 50 top tracks of the last ~6 months and the 50 last songs played
    /// (TODO 1.25). One `Track` per song: a song in several lists keeps the first of
    /// saved, top, recent. `addedAt` is the like date, the import date (top) or the last play.
    func importLibrary() async throws -> [Track] {
        try await importLibrary { _, _ in }
    }

    /// The progress counts the liked songs, page by page; the last two lists come after.
    func importLibrary(progress: @escaping (_ done: Int, _ total: Int) -> Void) async throws -> [Track] {
        let saved = try await savedTracks(progress: progress)
        let top = try await api.get("me/top/tracks?limit=50&time_range=medium_term", as: SpotifyPage<SpotifyTrack>.self)
            .items.compactMap { $0.makeTrack(source: .top, addedAt: now()) }
        // Newest first, so a song played twice keeps its last play.
        let recent = try await api.get("me/player/recently-played?limit=50", as: SpotifyPage<SpotifyPlayedItem>.self)
            .items.compactMap { $0.track.makeTrack(source: .recent, addedAt: $0.playedAt) }
        var seen = Set<String>()
        return (saved + top + recent).filter { seen.insert($0.spotifyId).inserted }
    }

    /// Every liked song, 50 per page (Spotify's maximum), following each page's `next` (TODO 1.23).
    func savedTracks(progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async throws -> [Track] {
        var tracks: [Track] = []
        var read = 0
        var next: String? = "me/tracks?limit=50"
        while let url = next {
            let page = try await api.get(url, as: SpotifyPage<SpotifySavedItem>.self)
            tracks += page.items.compactMap { $0.track?.makeTrack(source: .saved, addedAt: $0.addedAt) }
            read += page.items.count
            progress(read, max(page.total ?? read, read))
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

    /// Through App Remote, in the Spotify app (TODO 3.11).
    func play(spotifyIds: [String]) async throws {
        try await SpotifyRemote.shared.start(spotifyIds: spotifyIds)
    }

    /// `PUT /me/library` with the song's URI (scope `user-library-modify`, TODO 3.14): since
    /// February 2026 it replaces `PUT /me/tracks` (PROJECT.md §9).
    func save(spotifyId: String) async throws {
        let uri = SpotifyRemote.uri(spotifyId).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        try await api.put("me/library?uris=\(uri)")
    }
}
