import Foundation

/// A song as the Worker receives it: title and artists only, nothing else leaves the phone
/// (PROJECT.md §7.1, §11). Cut to the limits the Worker checks (`worker/src/validate.ts`).
struct WorkerSong: Encodable, Equatable {
    static let maxTitle = 200
    static let maxArtists = 10
    static let maxArtist = 100

    let title: String
    let artists: [String]

    /// Nil when the Worker would refuse the song: blank title or no artist.
    init?(title: String, artists: [String]) {
        let title = Self.cut(title, to: Self.maxTitle)
        let artists = artists.map { Self.cut($0, to: Self.maxArtist) }.filter { !$0.isEmpty }.prefix(Self.maxArtists)
        guard !title.isEmpty, !artists.isEmpty else { return nil }
        self.title = title
        self.artists = Array(artists)
    }

    /// Trimmed, then at most `max` UTF-16 units (JavaScript's `length`), never inside a character.
    private static func cut(_ text: String, to max: Int) -> String {
        var result = ""
        var length = 0
        for character in text.trimmingCharacters(in: .whitespacesAndNewlines) {
            length += character.utf16.count
            if length > max { break }
            result.append(character)
        }
        return result
    }
}

/// Energy and positivity from the LLM, both between 0 and 1.
struct SongPair: Decodable, Equatable {
    let energy: Double
    let positivity: Double
}

enum WorkerError: Error, Equatable {
    /// 400: the Worker refused the songs; sending them again would not help.
    case rejected
    /// 403: this Spotify account is not on the Worker's list.
    case notAllowed
    /// 429: the account's requests for today are used up; seconds until 00:00 UTC.
    case dailyLimit(retryAfter: Int?)
    /// Any other status, e.g. 502 when Spotify or the LLM failed: try again later.
    case http(Int)
    /// A 200 whose body is not one score (or null) per song.
    case invalidResponse
}

/// Client of the Cloudflare Worker that asks the LLM for song scores (TODO 2.33, PROJECT.md §7.1).
/// The Worker checks the user with their Spotify token, so the app holds no key.
final class WorkerClient {
    /// Most songs per request, as the Worker accepts.
    static let batchSize = 50

    private let scoreURL: URL
    private let auth: SpotifyAuth
    private let send: SpotifyAuth.Send

    init(
        baseURL: URL,
        auth: SpotifyAuth,
        send: @escaping SpotifyAuth.Send = { try await URLSession.shared.httpData(for: $0) }
    ) {
        self.scoreURL = baseURL.appending(path: "score")
        self.auth = auth
        self.send = send
    }

    /// The app's client, with the URL of `Config.xcconfig` (through Info.plist); nil without one.
    static func live() -> WorkerClient? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "WorkerURL") as? String,
              let url = URL(string: text), url.scheme == "https" else { return nil }
        return WorkerClient(baseURL: url, auth: .shared)
    }

    /// `POST /score` with 1 to 50 songs. One score per song, in order; nil when the LLM gave no
    /// valid pair for it. A token Spotify refuses (401) is refreshed once and the request sent again.
    func score(_ songs: [WorkerSong]) async throws -> [SongPair?] {
        precondition((1...Self.batchSize).contains(songs.count), "1 to \(Self.batchSize) songs per request")
        let body = try JSONEncoder().encode(["songs": songs])
        var refreshed = false
        while true {
            var request = URLRequest(url: scoreURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
            request.httpBody = body
            let (data, response) = try await send(request)
            switch response.statusCode {
            case 200:
                return try Self.scores(in: data, count: songs.count)
            case 401 where !refreshed:
                refreshed = true
                try await auth.refresh()
            case 400:
                throw WorkerError.rejected
            case 403:
                throw WorkerError.notAllowed
            case 429:
                throw WorkerError.dailyLimit(retryAfter: response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) })
            default:
                throw WorkerError.http(response.statusCode)
            }
        }
    }

    /// `{"scores":[{"energy":…,"positivity":…} | null, …]}`; a pair outside 0…1 counts as nil.
    private static func scores(in data: Data, count: Int) throws -> [SongPair?] {
        struct Body: Decodable { let scores: [SongPair?] }
        guard let body = try? JSONDecoder().decode(Body.self, from: data), body.scores.count == count else {
            throw WorkerError.invalidResponse
        }
        return body.scores.map { pair in
            pair.flatMap { (0...1).contains($0.energy) && (0...1).contains($0.positivity) ? $0 : nil }
        }
    }
}
