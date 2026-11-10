import AuthenticationServices
import UIKit

/// Shows Spotify's login page in the system's secure browser sheet and returns the
/// `harmony://callback?…` URL Spotify redirects to (TODO 1.18).
final class WebLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// Kept alive while the sheet is open: a released session closes it.
    private var session: ASWebAuthenticationSession?

    func open(_ url: URL) async throws -> URL {
        defer { session = nil }
        return try await withCheckedThrowingContinuation { continuation in
            // @Sendable: the system may call this off the main thread.
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme("harmony")) { @Sendable callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? SpotifyError.loginFailed("no callback URL"))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                continuation.resume(throwing: SpotifyError.loginFailed("the login sheet could not open"))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
