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
    /// Spotify's answer per endpoint (TODO 1.21).
    @State private var endpointResults: [(endpoint: String, result: String)] = []

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
                Button("Check endpoints") { run(checkEndpoints) }
                ForEach(endpointResults, id: \.endpoint) { row in
                    LabeledContent(row.endpoint, value: row.result)
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
        print("Spotify import: \(lastImport!)")
    }

    /// Calls each Web API endpoint of PROJECT.md §9 once and shows Spotify's answer (TODO 1.21).
    /// `/tracks/{id}` uses the first liked song.
    private func checkEndpoints() async throws {
        let api = SpotifyProvider.live.api
        var results: [(endpoint: String, result: String)] = []
        func check(_ endpoint: String, _ path: String) async -> Data? {
            let result: String
            var body: Data?
            do {
                body = try await api.data(for: URL(string: path, relativeTo: SpotifyAPI.baseURL)!.absoluteURL)
                result = "OK"
            } catch {
                result = "\(error)"
            }
            results.append((endpoint, result))
            print("Spotify check: \(endpoint): \(result)")
            return body
        }

        _ = await check("GET /me", "me")
        let liked = await check("GET /me/tracks", "me/tracks?limit=1")
        _ = await check("GET /me/top/tracks", "me/top/tracks?limit=1")
        _ = await check("GET /me/player/recently-played", "me/player/recently-played?limit=1")
        let firstLiked = liked.flatMap { try? SpotifyAPI.decoder().decode(SpotifyPage<SpotifySavedItem>.self, from: $0) }?
            .items.first?.track?.id
        if let firstLiked {
            _ = await check("GET /tracks/{id}", "tracks/\(firstLiked)")
        } else {
            results.append(("GET /tracks/{id}", "not checked: no liked song"))
        }
        endpointResults = results
    }

    /// TODO 1.26.
    private func disconnect(deletingLibrary: Bool) {
        lastImport = nil
        endpointResults = []
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
