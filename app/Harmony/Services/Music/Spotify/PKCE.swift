import CryptoKit
import Foundation

/// Proof Key for Code Exchange (RFC 7636), so the app signs in to Spotify without a client
/// secret (PROJECT.md §9, TODO 1.18).
enum PKCE {
    /// The characters RFC 7636 allows in a code verifier.
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// A random code verifier (64 characters; RFC 7636 asks for 43 to 128).
    /// Also used for the `state` parameter of the login.
    static func makeVerifier() -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<64).map { _ in alphabet.randomElement(using: &generator)! })
    }

    /// The S256 code challenge: base64url of the SHA-256 of the verifier, without padding.
    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
