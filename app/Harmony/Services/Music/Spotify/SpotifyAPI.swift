import Foundation

/// Spotify Web API requests made with the user's token (TODO 1.20).
final class SpotifyAPI {
    static let baseURL = URL(string: "https://api.spotify.com/v1/")!

    /// Longest `Retry-After` the app waits for. In development mode Spotify can ask for hours:
    /// better to say so than to hang.
    static let longestWait = 30
    /// How many times a rate-limited request is sent again.
    static let rateLimitRetries = 3

    private let auth: SpotifyAuth
    private let send: SpotifyAuth.Send
    private let sleep: (Duration) async throws -> Void

    init(
        auth: SpotifyAuth,
        send: @escaping SpotifyAuth.Send = { try await URLSession.shared.httpData(for: $0) },
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.auth = auth
        self.send = send
        self.sleep = sleep
    }

    /// `GET` a path under `/v1/` (e.g. `me/tracks?limit=50`) or a full URL (a page's `next`),
    /// decoded as `T`.
    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let url = path.hasPrefix("https://") ? URL(string: path)! : URL(string: path, relativeTo: Self.baseURL)!.absoluteURL
        let body = try await data(for: url)
        return try Self.decoder().decode(T.self, from: body)
    }

    /// Body of a successful `GET`; any other status is a `SpotifyError.http`.
    /// A token Spotify refuses (401, e.g. revoked early) is refreshed once and the request sent again.
    /// Too many requests (429): waits `Retry-After` seconds and sends it again (TODO 1.24).
    func data(for url: URL) async throws -> Data {
        var refreshed = false
        var rateLimitRetries = 0
        while true {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(try await auth.validAccessToken())", forHTTPHeaderField: "Authorization")
            let (data, response) = try await send(request)
            switch response.statusCode {
            case 200..<300:
                return data
            case 401 where !refreshed:
                refreshed = true
                try await auth.refresh()
            case 429 where rateLimitRetries < Self.rateLimitRetries:
                rateLimitRetries += 1
                let wait = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) } ?? 1
                guard wait <= Self.longestWait else { throw SpotifyError.rateLimited(retryAfter: wait) }
                try await sleep(.seconds(wait))
            default:
                throw SpotifyError.http(response.statusCode)
            }
        }
    }

    /// Spotify's JSON uses snake_case keys.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
