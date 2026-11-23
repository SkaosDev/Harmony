import Foundation
import Observation
import SwiftData

/// Imports the library with its progress (`V2-Onb5-Import`, `V2-Main`), then scores the new
/// songs in the background (TODO 3.16, PROJECT.md §7): the first scoring of a large library takes
/// minutes, so it never holds the user back.
@Observable
final class LibrarySync {
    /// `UserDefaults` key of the date of the last complete import.
    static let importDateKey = "libraryImportedAt"

    private(set) var isImporting = false
    /// Songs read so far, and out of how many (0 / 0 before the first page).
    private(set) var done = 0
    private(set) var total = 0
    private(set) var isScoring = false
    /// Why the last import failed, nil when it worked.
    private(set) var problem: String?
    /// When the library was last imported in full; nil if never.
    private(set) var importedAt: Date?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        importedAt = defaults.object(forKey: Self.importDateKey) as? Date
    }

    /// 0…1.
    var fraction: Double {
        total == 0 ? 0 : Double(done) / Double(total)
    }

    /// Imports the library into the store, then starts scoring it. Does nothing if an import is
    /// already running.
    func run(music: any MusicProvider, scorer: SongScorer?, context: ModelContext, now: Date = .now) async {
        guard !isImporting else { return }
        isImporting = true
        problem = nil
        done = 0
        total = 0
        defer { isImporting = false }
        do {
            let tracks = try await music.importLibrary { [weak self] done, total in
                self?.done = done
                self?.total = total
            }
            tracks.forEach(context.insert)
            try context.save()
            done = max(done, total)
            defaults.set(now, forKey: Self.importDateKey)
            importedAt = now
            if let scorer {
                Task { await score(with: scorer, context: context) }
            }
        } catch {
            print("Library import failed: \(error)")
            problem = "\(error)"
        }
    }

    /// Scores the songs that have no score yet (MuSe, else the LLM, else neutral).
    func score(with scorer: SongScorer, context: ModelContext) async {
        guard !isScoring else { return }
        isScoring = true
        defer { isScoring = false }
        do {
            let summary = try await scorer.score(try context.fetch(FetchDescriptor<Track>()), in: context)
            print("Song scores: LLM \(summary.llm), MuSe \(summary.museBySpotifyId + summary.museByTitle), "
                  + "neutral \(summary.neutral), not scored \(summary.unscored)")
        } catch {
            print("Scoring failed: \(error)")
        }
    }
}
