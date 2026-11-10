import Foundation

/// A page of a Spotify list.
struct SpotifyPage<Item: Decodable>: Decodable {
    let items: [Item]
    /// Full URL of the next page; nil on the last one.
    let next: String?
}

/// An item of `GET /me/tracks`.
struct SpotifySavedItem: Decodable {
    let addedAt: Date
    /// Nil for a song that is no longer available.
    let track: SpotifyTrack?
}

/// A song as the Web API describes it (only the fields the app uses).
struct SpotifyTrack: Decodable {
    /// Nil for a local file.
    let id: String?
    let name: String
    let artists: [Artist]
    let album: Album?
    let isLocal: Bool?

    struct Artist: Decodable {
        let name: String
    }

    struct Album: Decodable {
        /// Widest first.
        let images: [Image]
    }

    struct Image: Decodable {
        let url: URL
    }

    var info: TrackInfo? {
        guard let id, isLocal != true else { return nil }
        return TrackInfo(spotifyId: id, title: name, artists: artists.map(\.name), coverURL: album?.images.first?.url)
    }

    /// Nil for a song the app cannot use: a local file, which has no Spotify ID.
    func makeTrack(source: TrackSource, addedAt: Date) -> Track? {
        info.map { Track(spotifyId: $0.spotifyId, title: $0.title, artists: $0.artists, coverURL: $0.coverURL, source: source, addedAt: addedAt) }
    }
}
