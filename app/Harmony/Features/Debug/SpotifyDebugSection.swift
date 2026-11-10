#if DEBUG
import SwiftUI

/// Debug screen, Spotify part (TODO 1.18+): sign in and check the connection before the real
/// screens exist (onboarding 3.16, Spotify account 3.19).
struct SpotifyDebugSection: View {
    private let auth = SpotifyAuth.shared
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        Section {
            if let tokens = auth.tokens {
                LabeledContent("Status", value: "Connected")
                LabeledContent("Token expires", value: tokens.expiresAt.formatted(date: .omitted, time: .shortened))
                LabeledContent("Scopes", value: tokens.scope)
            } else {
                LabeledContent("Status", value: "Not connected")
                Button("Connect") { run { try await auth.signIn() } }
            }
            if let message {
                Text(message).foregroundStyle(.red)
            }
        } header: {
            Text("Spotify")
        }
        .disabled(isWorking)
    }

    /// Runs a Spotify action, showing its error if any.
    private func run(_ action: @escaping () async throws -> Void) {
        isWorking = true
        message = nil
        Task {
            do {
                try await action()
            } catch {
                message = "\(error)"
            }
            isWorking = false
        }
    }
}
#endif
