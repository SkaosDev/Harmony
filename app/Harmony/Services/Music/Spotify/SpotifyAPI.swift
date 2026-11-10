import Foundation

/// Spotify Web API requests made with the user's token (TODO 1.20).
final class SpotifyAPI {
    static let baseURL = URL(string: "https://api.spotify.com/v1/")!

    private let auth: SpotifyAuth
    private let send: SpotifyAuth.Send

    init(auth: SpotifyAuth, send: @escaping SpotifyAuth.Send = { try await URLSession.shared.httpData(for: $0) }) {
        self.auth = auth
        self.send = send
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
    func data(for url: URL) async throws -> Data {
        var refreshed = false
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
