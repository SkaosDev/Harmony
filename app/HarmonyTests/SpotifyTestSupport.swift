import Foundation
import Testing
@testable import Harmony

/// A fake Spotify server: answers each request with the next response queued for its path,
/// and keeps the requests it received.
final class StubHTTP {
    struct Response {
        var status = 200
        var headers: [String: String] = [:]
        var body = "{}"
    }

    private(set) var requests: [URLRequest] = []
    private var queues: [String: [Response]] = [:]

    /// Queues a response for a path such as `/api/token` or `/v1/me/tracks` (query ignored).
    func on(_ path: String, status: Int = 200, headers: [String: String] = [:], body: String = "{}") {
        queues[path, default: []].append(Response(status: status, headers: headers, body: body))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url!.path
        guard let response = queues[path]?.first else {
            Issue.record("Unexpected request: \(request.url!)")
            throw URLError(.badServerResponse)
        }
        queues[path]!.removeFirst()
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: response.headers)!
        return (Data(response.body.utf8), http)
    }

    /// The fields of a form-encoded request body.
    static func form(_ request: URLRequest) -> [String: String] {
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        let items = URLComponents(string: "?" + body)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
    }

    /// The query parameters of a request URL.
    static func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
    }
}

/// A Keychain store used by one test only. Tests that save tokens delete them at the end.
func makeTestStore() -> KeychainTokenStore {
    KeychainTokenStore(service: "com.firestarter.harmony.tests.\(UUID().uuidString)")
}

/// A token response as Spotify sends it.
func tokenJSON(access: String, refresh: String? = nil, expiresIn: Int = 3600, scope: String = "user-library-read") -> String {
    let refreshField = refresh.map { #","refresh_token":"\#($0)""# } ?? ""
    return #"{"access_token":"\#(access)","token_type":"Bearer","expires_in":\#(expiresIn),"scope":"\#(scope)"\#(refreshField)}"#
}
