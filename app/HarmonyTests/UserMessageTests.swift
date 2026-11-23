import Foundation
import Testing
@testable import Harmony

/// TODO 3.22: failures are told in a plain sentence, never as the raw error.
@MainActor
struct UserMessageTests {
    @Test func noNetworkSaysSo() {
        #expect(UserMessage.text(for: URLError(.notConnectedToInternet)) == UserMessage.offline)
        #expect(UserMessage.text(for: URLError(.timedOut)) == UserMessage.offline)
        // URLSession's errors arrive as NSError in NSURLErrorDomain (-1009: offline).
        #expect(UserMessage.text(for: NSError(domain: NSURLErrorDomain, code: -1009)) == UserMessage.offline)
    }

    @Test func spotifyRateLimitAsksToWait() {
        #expect(UserMessage.text(for: SpotifyError.rateLimited(retryAfter: 120)) == UserMessage.spotifyBusy)
    }

    @Test func anythingElseIsAPlainSentence() {
        #expect(UserMessage.text(for: SpotifyError.http(503)) == UserMessage.other)
        #expect(UserMessage.text(for: CocoaError(.fileNoSuchFile)) == UserMessage.other)
    }
}
