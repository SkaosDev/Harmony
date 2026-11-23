import Foundation

/// What the app tells the user when something fails (TODO 3.22): a short sentence that says what
/// to do, never the raw error. The raw error still goes to the console.
enum UserMessage {
    static let offline = "No internet connection. Check it and try again."
    static let spotifyBusy = "Spotify is busy. Try again in a minute."
    static let other = "Something went wrong. Try again."

    static func text(for error: Error) -> String {
        print("Error shown to the user: \(error)")
        if let urlError = error as? URLError, offlineCodes.contains(urlError.code) {
            return offline
        }
        if case SpotifyError.rateLimited = error {
            return spotifyBusy
        }
        return other
    }

    /// No network, or a network that does not answer.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
        .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
    ]
}
