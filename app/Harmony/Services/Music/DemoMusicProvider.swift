import Foundation

/// Music provider of demo mode (TODO 1.16, FR12): the synthetic library of
/// `Resources/demo/demo_songs.json` (TODO 1.15). There is no Spotify in demo mode, so signing in,
/// playing and saving do nothing.
struct DemoMusicProvider: MusicProvider {
    private let songs: [DemoSong]
    private let now: Date

    init(bundle: Bundle = .main, now: Date = .now) throws {
        guard let url = bundle.url(forResource: "demo_songs", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        songs = try JSONDecoder().decode(DemoSongsFile.self, from: Data(contentsOf: url)).songs
        self.now = now
    }

    func signIn() async throws {}

    func importLibrary() async throws -> [Track] {
        tracks()
    }

    func lookUp(spotifyId: String) async throws -> TrackInfo? {
        songs.first { $0.spotifyId == spotifyId }.map { song in
            TrackInfo(spotifyId: song.spotifyId, title: song.title, artists: song.artists, coverURL: nil)
        }
    }

    func play(spotifyIds: [String]) async throws {}

    func save(spotifyId: String) async throws {}

    /// The demo library, without waiting (fills the demo store, TODO 1.17).
    func tracks() -> [Track] {
        songs.map { song in
            Track(
                spotifyId: song.spotifyId,
                title: song.title,
                artists: song.artists,
                coverURL: nil,
                source: song.source,
                addedAt: now.addingTimeInterval(-Double(song.addedDaysAgo) * 86_400)
            )
        }
    }

    /// Scores of the demo songs. A real library gets them from MuSe or the LLM (TODO 2.34).
    func scores() -> [SongScore] {
        songs.map { SongScore(spotifyId: $0.spotifyId, energy: $0.energy, positivity: $0.positivity, origin: $0.origin) }
    }
}

/// Layout of `demo_songs.json`, written by `ml/make_demo_data.py`.
private struct DemoSongsFile: Decodable {
    let songs: [DemoSong]
}

private struct DemoSong: Decodable {
    let spotifyId: String
    let title: String
    let artists: [String]
    let source: TrackSource
    let addedDaysAgo: Int
    let energy: Double
    let positivity: Double
    let origin: ScoreOrigin
}
