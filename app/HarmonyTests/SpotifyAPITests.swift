import Foundation
import Testing
@testable import Harmony

/// TODO 1.20: the token is refreshed automatically.
@MainActor
struct SpotifyTokenRefreshTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let store = makeTestStore()
    private let server = StubHTTP()

    private struct Me: Decodable, Equatable {
        let id: String
    }

    private func authorization(_ request: URLRequest) -> String? {
        request.value(forHTTPHeaderField: "Authorization")
    }

    @Test func validTokenIsUsedAsIs() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        server.on("/v1/me", body: #"{"id":"user-1"}"#)

        #expect(try await SpotifyAPI(auth: auth, send: server.send).get("me") == Me(id: "user-1"))
        #expect(server.requests.map { $0.url?.absoluteString } == ["https://api.spotify.com/v1/me"])
        #expect(authorization(server.requests[0]) == "Bearer access-1")
    }

    /// The ✔ of TODO 1.20: a call succeeds after a simulated expiry.
    @Test func expiredTokenIsRefreshedBeforeTheCall() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(-10))
        // Spotify may leave out the refresh token and scopes: the old ones are kept.
        server.on("/api/token", body: #"{"access_token":"access-2","token_type":"Bearer","expires_in":3600}"#)
        server.on("/v1/me", body: #"{"id":"user-1"}"#)

        #expect(try await SpotifyAPI(auth: auth, send: server.send).get("me") == Me(id: "user-1"))

        #expect(server.requests.map { $0.url?.path() } == ["/api/token", "/v1/me"])
        let form = StubHTTP.form(server.requests[0])
        #expect(form == ["grant_type": "refresh_token", "refresh_token": "refresh-1", "client_id": "client-123"])
        #expect(authorization(server.requests[1]) == "Bearer access-2")
        let expected = SpotifyTokens(accessToken: "access-2", refreshToken: "refresh-1", expiresAt: now.addingTimeInterval(3600), scope: "user-library-read")
        #expect(auth.tokens == expected)
        #expect(try store.load() == expected)
    }

    @Test func tokenExpiringWithinAMinuteIsRefreshed() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(30))
        server.on("/api/token", body: tokenJSON(access: "access-2", refresh: "refresh-2"))
        #expect(try await auth.validAccessToken() == "access-2")
        #expect(auth.tokens?.refreshToken == "refresh-2")
    }

    @Test func refusedTokenIsRefreshedAndTheCallSentAgain() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        server.on("/v1/me", status: 401)
        server.on("/api/token", body: tokenJSON(access: "access-2"))
        server.on("/v1/me", body: #"{"id":"user-1"}"#)

        #expect(try await SpotifyAPI(auth: auth, send: server.send).get("me") == Me(id: "user-1"))
        #expect(server.requests.map { $0.url?.path() } == ["/v1/me", "/api/token", "/v1/me"])
        #expect(authorization(server.requests[2]) == "Bearer access-2")
    }

    @Test func secondRefusalIsAnError() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(3600))
        server.on("/v1/me", status: 401)
        server.on("/api/token", body: tokenJSON(access: "access-2"))
        server.on("/v1/me", status: 401)

        await #expect(throws: SpotifyError.http(401)) {
            try await SpotifyAPI(auth: auth, send: server.send).get("me", as: Me.self)
        }
        #expect(server.requests.count == 3)
    }

    @Test func revokedRefreshTokenSignsOut() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(-10))
        server.on("/api/token", status: 400, body: #"{"error":"invalid_grant","error_description":"Refresh token revoked"}"#)

        await #expect(throws: SpotifyError.notSignedIn) { try await auth.validAccessToken() }
        #expect(auth.tokens == nil)
        #expect(try store.load() == nil)
    }

    @Test func concurrentCallersShareOneRefresh() async throws {
        defer { try? store.delete() }
        let auth = try makeSignedInAuth(server: server, store: store, now: now, expiresAt: now.addingTimeInterval(-10))
        server.on("/api/token", body: tokenJSON(access: "access-2", refresh: "refresh-2"))

        async let first = auth.validAccessToken()
        async let second = auth.validAccessToken()
        #expect(try await [first, second] == ["access-2", "access-2"])
        #expect(server.requests.count == 1)
    }

    @Test func signedOutUserCannotCall() async throws {
        let auth = SpotifyAuth(clientID: "client-123", store: store, send: server.send)
        await #expect(throws: SpotifyError.notSignedIn) {
            try await SpotifyAPI(auth: auth, send: server.send).get("me", as: Me.self)
        }
        #expect(server.requests.isEmpty)
    }
}
