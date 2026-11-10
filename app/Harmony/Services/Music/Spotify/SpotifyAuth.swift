import Foundation
import Observation

/// Tokens of the signed-in Spotify user (TODO 1.18).
struct SpotifyTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    /// Scopes the user granted, separated by spaces.
    var scope: String
}

/// Spotify sign-in with the Authorization Code flow and PKCE: no client secret in the app
/// (PROJECT.md §9, TODO 1.18).
@Observable
final class SpotifyAuth {
    typealias Send = (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Registered in the Spotify dashboard (TODO 0.C5).
    static let redirectURI = "harmony://callback"
    /// PROJECT.md §9. `app-remote-control` is for playback (TODO 3.10).
    static let scopes = [
        "user-library-read",
        "user-library-modify",
        "user-top-read",
        "user-read-recently-played",
        "app-remote-control",
    ]

    /// The app's instance; the client ID comes from `Config.xcconfig` through Info.plist.
    static let shared = SpotifyAuth(
        clientID: Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? "",
        store: KeychainTokenStore(service: "com.firestarter.harmony.spotify")
    )

    /// Nil when nobody is signed in. Read from the Keychain at launch (TODO 1.19).
    private(set) var tokens: SpotifyTokens?
    /// The refresh under way, shared by every caller (see `refresh()`).
    @ObservationIgnored private var refreshing: Task<SpotifyTokens, Error>?

    private let clientID: String
    private let store: KeychainTokenStore
    private let send: Send
    private let openLogin: (URL) async throws -> URL
    private let now: () -> Date

    /// `send` and `openLogin` are replaced in tests by a fake server and a fake login page.
    init(
        clientID: String,
        store: KeychainTokenStore,
        send: @escaping Send = { try await URLSession.shared.httpData(for: $0) },
        openLogin: @escaping (URL) async throws -> URL = { try await WebLogin().open($0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.clientID = clientID
        self.store = store
        self.send = send
        self.openLogin = openLogin
        self.now = now
        // Unreadable tokens count as signed out: the user signs in again.
        tokens = try? store.load()
    }

    /// Opens Spotify's login page, then exchanges the returned code for tokens.
    func signIn() async throws {
        guard !clientID.isEmpty else { throw SpotifyError.missingClientID }
        let verifier = PKCE.makeVerifier()
        let state = PKCE.makeVerifier()
        let callback = try await openLogin(authorizeURL(challenge: PKCE.challenge(for: verifier), state: state))

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("state") == state else { throw SpotifyError.loginFailed("state mismatch") }
        guard let code = value("code") else { throw SpotifyError.loginFailed(value("error") ?? "no code") }

        try keep(await requestTokens([
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", Self.redirectURI),
            ("client_id", clientID),
            ("code_verifier", verifier),
        ]))
    }

    /// A valid access token, refreshed first if it expires within a minute (TODO 1.20).
    func validAccessToken() async throws -> String {
        guard let tokens else { throw SpotifyError.notSignedIn }
        if tokens.expiresAt.timeIntervalSince(now()) > 60 { return tokens.accessToken }
        return try await refresh().accessToken
    }

    /// Gets a new access token with the refresh token (TODO 1.20). Callers arriving during a
    /// refresh wait for it instead of starting another one: Spotify may replace the refresh token,
    /// so a second request could use an old one. If Spotify refuses the refresh token
    /// (revoked or expired), the user is signed out.
    @discardableResult
    func refresh() async throws -> SpotifyTokens {
        if let refreshing { return try await refreshing.value }
        guard let current = tokens else { throw SpotifyError.notSignedIn }
        let task = Task {
            defer { refreshing = nil }
            do {
                let new = try await requestTokens([
                    ("grant_type", "refresh_token"),
                    ("refresh_token", current.refreshToken),
                    ("client_id", clientID),
                ], previous: current)
                try keep(new)
                return new
            } catch SpotifyError.http(400) {
                try? signOut()
                throw SpotifyError.notSignedIn
            }
        }
        refreshing = task
        return try await task.value
    }

    /// Forgets the tokens, in the Keychain too.
    func signOut() throws {
        try store.delete()
        tokens = nil
    }

    /// Saves the tokens in the Keychain, then uses them.
    private func keep(_ tokens: SpotifyTokens) throws {
        try store.save(tokens)
        self.tokens = tokens
    }

    /// Spotify's login page for this app.
    func authorizeURL(challenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: Self.scopes.joined(separator: " ")),
        ]
        return components.url!
    }

    /// `POST /api/token`. A refresh may come back without a refresh token or scopes:
    /// those of `previous` are kept.
    private func requestTokens(_ fields: [(String, String)], previous: SpotifyTokens? = nil) async throws -> SpotifyTokens {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(fields)

        let (data, response) = try await send(request)
        guard response.statusCode == 200 else { throw SpotifyError.http(response.statusCode) }
        let body = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refreshToken = body.refreshToken ?? previous?.refreshToken else {
            throw SpotifyError.loginFailed("no refresh token")
        }
        return SpotifyTokens(
            accessToken: body.accessToken,
            refreshToken: refreshToken,
            expiresAt: now().addingTimeInterval(body.expiresIn),
            scope: body.scope ?? previous?.scope ?? ""
        )
    }

    /// `application/x-www-form-urlencoded`, every character but the unreserved ones percent-encoded.
    private static func formBody(_ fields: [(String, String)]) -> Data {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return Data(fields.map { name, value in
            "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved)!)"
        }.joined(separator: "&").utf8)
    }
}

/// Body of Spotify's token responses.
private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Double
    /// Always there after a sign-in; maybe missing after a refresh.
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

extension URLSession {
    /// `data(for:)` for HTTP requests.
    func httpData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}
