#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, Spotify part (TODO 1.18+): sign in, import and check the connection before the
/// real screens exist (onboarding 3.16, Spotify account 3.19).
struct SpotifyDebugSection: View {
    private let auth = SpotifyAuth.shared
    @Environment(\.modelContext) private var context
    @Query private var tracks: [Track]
    @State private var isWorking = false
    @State private var confirmingDisconnect = false
    @State private var message: String?
    /// Size and duration of the last import (TODO 1.27).
    @State private var lastImport: String?

    var body: some View {
        Section {
            if let tokens = auth.tokens {
                LabeledContent("Status", value: "Connected")
                LabeledContent("Token expires", value: tokens.expiresAt.formatted(date: .omitted, time: .shortened))
                LabeledContent("Scopes", value: tokens.scope)
                Button("Import library") { run(importLibrary) }
                if let lastImport {
                    LabeledContent("Last import", value: lastImport)
                }
                Button("Disconnect", role: .destructive) { confirmingDisconnect = true }
                    .confirmationDialog("Disconnect from Spotify?", isPresented: $confirmingDisconnect) {
                        Button("Disconnect", role: .destructive) { disconnect(deletingLibrary: false) }
                        Button("Disconnect and delete library", role: .destructive) { disconnect(deletingLibrary: true) }
                    }
            } else {
                LabeledContent("Status", value: "Not connected")
                Button("Connect") { run { try await auth.signIn() } }
            }
            ForEach([TrackSource.saved, .top, .recent], id: \.self) { source in
                LabeledContent("Tracks: \(source.rawValue)", value: tracks.count { $0.source == source }, format: .number)
            }
            if isWorking {
                ProgressView()
            }
            if let message {
                Text(message).foregroundStyle(.red)
            }
        } header: {
            Text("Spotify")
        }
        .disabled(isWorking)
    }

    /// Imports the library into the store and times it, saving included (NFR3: < 60 s for 2,000 songs).
    private func importLibrary() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        let imported = try await SpotifyProvider.live.importLibrary()
        imported.forEach(context.insert)
        try context.save()
        let duration = (clock.now - start).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
        lastImport = "\(imported.count) tracks in \(duration)"
    }

    /// TODO 1.26.
    private func disconnect(deletingLibrary: Bool) {
        lastImport = nil
        run { try SpotifyProvider.live.signOut(deletingLibraryFrom: deletingLibrary ? context : nil) }
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
