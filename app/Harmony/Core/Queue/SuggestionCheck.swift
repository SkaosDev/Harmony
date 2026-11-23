import Foundation

/// Checks a MuSe suggestion with the music service before it is played (TODO 3.6, PROJECT.md §8):
/// MuSe's Spotify IDs can be wrong (§5.2), so the ID must exist and give the same title and first
/// artist, compared as MuSe keys (`SongKey`, either apostrophe).
enum SuggestionCheck {
    /// The service's view of the song, or nil if the suggestion must be left out (unknown ID,
    /// another song, or no answer).
    static func verify(_ song: QueueCandidate, using provider: any MusicProvider) async -> TrackInfo? {
        guard let info = try? await provider.lookUp(spotifyId: song.spotifyId) else { return nil }
        let expected = Set(MuseCatalog.titleKeys(title: song.title, artist: song.artists.first ?? ""))
        let found = Set(MuseCatalog.titleKeys(title: info.title, artist: info.artists.first ?? ""))
        return expected.isDisjoint(with: found) ? nil : info
    }
}
