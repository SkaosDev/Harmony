#if DEBUG
import SwiftData
import SwiftUI

/// Debug screen, song scores (TODO 2.34, 2.35): scores the library (MuSe, then the Worker outside
/// demo mode), shows where the scores come from and the MuSe coverage, before the real screens
/// use them. Also printed, to be read from the Xcode console.
struct ScoresDebugSection: View {
    @AppStorage(DemoMode.key) private var demoMode = false
    @Environment(\.modelContext) private var context
    @Query(sort: \Track.addedAt, order: .reverse) private var tracks: [Track]
    @Query private var scores: [SongScore]
    @State private var lastRun: String?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        let byId = Dictionary(scores.map { ($0.spotifyId, $0) }, uniquingKeysWith: { first, _ in first })
        let library = tracks.compactMap { byId[$0.spotifyId] }
        Section {
            Button("Score songs") { score() }
            ForEach([ScoreOrigin.muse, .llm, .neutral], id: \.self) { origin in
                LabeledContent("Library: \(origin.rawValue)", value: library.count { $0.origin == origin }, format: .number)
            }
            LabeledContent("Library: not scored", value: tracks.count - library.count, format: .number)
            LabeledContent("MuSe coverage", value: percent(library.count { $0.origin == .muse }, of: tracks.count))
            if let lastRun {
                Text(lastRun).font(.caption)
            }
            ForEach(tracks.prefix(10)) { track in
                LabeledContent(track.title, value: byId[track.spotifyId].map(describe) ?? "–")
            }
            if isWorking {
                ProgressView()
            }
            if let message {
                Text(message).foregroundStyle(.red)
            }
        } header: {
            Text("Song scores")
        } footer: {
            Text("Energy (E) and positivity (P), 0…1: MuSe, else the LLM through the Worker, else 0.5. Last 10 songs added.")
        }
        .disabled(isWorking)
    }

    /// Scores the songs without a score yet, and times it.
    private func score() {
        isWorking = true
        message = nil
        Task {
            do {
                let clock = ContinuousClock()
                let start = clock.now
                let scorer = SongScorer(muse: try MuseCatalog.bundled(), worker: demoMode ? nil : WorkerClient.live())
                let summary = try await scorer.score(tracks, in: context)
                let duration = (clock.now - start).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
                lastRun = "\(tracks.count) songs in \(duration): \(summary.alreadyScored) already scored, "
                    + "MuSe \(summary.museBySpotifyId) by ID + \(summary.museByTitle) by title, "
                    + "LLM \(summary.llm), neutral \(summary.neutral), not scored \(summary.unscored)."
                print("Song scores: \(lastRun!)")
                if let error = summary.workerError {
                    message = "Worker: \(error)"
                }
            } catch {
                message = "\(error)"
            }
            isWorking = false
        }
    }

    private func describe(_ score: SongScore) -> String {
        "E \(score.energy.formatted(.number.precision(.fractionLength(2)))) · "
            + "P \(score.positivity.formatted(.number.precision(.fractionLength(2)))) · \(score.origin.rawValue)"
    }

    private func percent(_ count: Int, of total: Int) -> String {
        total == 0 ? "–" : (Double(count) / Double(total)).formatted(.percent.precision(.fractionLength(1)))
    }
}
#endif
