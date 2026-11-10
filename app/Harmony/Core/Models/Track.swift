import Foundation
import SwiftData

/// A song of the user's Spotify library (TODO 1.7). One row per Spotify ID:
/// inserting the same ID again updates the existing row.
@Model
final class Track {
    @Attribute(.unique) var spotifyId: String
    var title: String
    /// In Spotify's order; the first one is the main artist.
    var artists: [String]
    var coverURL: URL?
    /// Where the import found it.
    var source: TrackSource
    var addedAt: Date

    init(spotifyId: String, title: String, artists: [String], coverURL: URL?, source: TrackSource, addedAt: Date) {
        self.spotifyId = spotifyId
        self.title = title
        self.artists = artists
        self.coverURL = coverURL
        self.source = source
        self.addedAt = addedAt
    }
}

/// Spotify list a track was imported from: liked songs, top tracks or recently played.
enum TrackSource: String, Codable {
    case saved, top, recent
}
