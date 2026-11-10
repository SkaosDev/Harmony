import Foundation
import Testing
@testable import Harmony

/// TODO 1.18: PKCE sign-in, without client secret.
@MainActor
struct PKCETests {
    /// RFC 7636, Appendix B.
    @Test func challengeMatchesTheRFCExample() {
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func verifierIsRandomAndUsesTheAllowedCharacters() {
        let verifier = PKCE.makeVerifier()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect((43...128).contains(verifier.count))
        #expect(verifier.unicodeScalars.allSatisfy(allowed.contains))
        #expect(verifier != PKCE.makeVerifier())
    }
}

@MainActor
struct SpotifySignInTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// A fake login page: remembers the URL it was opened with and answers with `callback(state)`.
    private final class FakeLoginPage {
        var openedURL: URL?
        let callback: (String) -> String

        init(callback: @escaping (String) -> String) { self.callback = callback }

        func open(_ url: URL) -> URL {
            openedURL = url
            return URL(string: callback(StubHTTP.query(url)["state"] ?? ""))!
        }
    }

    private func makeAuth(server: StubHTTP, page: FakeLoginPage, clientID: String = "client-123") -> SpotifyAuth {
        SpotifyAuth(clientID: clientID, send: server.send, openLogin: page.open, now: { now })
    }

    @Test func authorizeURLAsksForACodeWithPKCEAndTheScopes() throws {
        let auth = makeAuth(server: StubHTTP(), page: FakeLoginPage { _ in "" })
        let url = auth.authorizeURL(challenge: "challenge", state: "state")
        let query = StubHTTP.query(url)
        #expect(url.host() == "accounts.spotify.com")
        #expect(url.path() == "/authorize")
        #expect(query["client_id"] == "client-123")
        #expect(query["response_type"] == "code")
        #expect(query["redirect_uri"] == "harmony://callback")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["code_challenge"] == "challenge")
        #expect(query["state"] == "state")
        #expect(query["scope"] == SpotifyAuth.scopes.joined(separator: " "))
    }

    @Test func signInExchangesTheCodeForTokens() async throws {
        let server = StubHTTP()
        server.on("/api/token", body: tokenJSON(access: "access-1", refresh: "refresh-1", scope: "user-library-read user-top-read"))
        let page = FakeLoginPage { state in "harmony://callback?code=the-code&state=\(state)" }
        let auth = makeAuth(server: server, page: page)

        try await auth.signIn()

        #expect(auth.tokens == SpotifyTokens(
            accessToken: "access-1",
            refreshToken: "refresh-1",
            expiresAt: now.addingTimeInterval(3600),
            scope: "user-library-read user-top-read"
        ))
        let request = try #require(server.requests.first)
        #expect(server.requests.count == 1)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://accounts.spotify.com/api/token")
        let form = StubHTTP.form(request)
        #expect(form["grant_type"] == "authorization_code")
        #expect(form["code"] == "the-code")
        #expect(form["redirect_uri"] == "harmony://callback")
        #expect(form["client_id"] == "client-123")
        // The verifier sent now is the one whose challenge was on the login page.
        let challenge = StubHTTP.query(try #require(page.openedURL))["code_challenge"]
        #expect(PKCE.challenge(for: try #require(form["code_verifier"])) == challenge)
    }

    @Test func wrongStateIsRejected() async throws {
        let server = StubHTTP()
        let auth = makeAuth(server: server, page: FakeLoginPage { _ in "harmony://callback?code=the-code&state=forged" })
        await #expect(throws: SpotifyError.loginFailed("state mismatch")) { try await auth.signIn() }
        #expect(server.requests.isEmpty)
        #expect(auth.tokens == nil)
    }

    @Test func refusedLoginIsAnError() async throws {
        let server = StubHTTP()
        let auth = makeAuth(server: server, page: FakeLoginPage { state in "harmony://callback?error=access_denied&state=\(state)" })
        await #expect(throws: SpotifyError.loginFailed("access_denied")) { try await auth.signIn() }
        #expect(server.requests.isEmpty)
    }

    @Test func missingClientIDIsAnError() async throws {
        let auth = makeAuth(server: StubHTTP(), page: FakeLoginPage { _ in "" }, clientID: "")
        await #expect(throws: SpotifyError.missingClientID) { try await auth.signIn() }
    }
}
