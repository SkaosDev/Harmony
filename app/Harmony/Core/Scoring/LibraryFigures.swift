import Foundation

/// What the Library tab shows about the songs (TODO 3.19b), kept apart so the Debug screen gives
/// the same MuSe coverage (TODO 2.35).
enum LibraryFigures {
    /// Share of the library's songs whose score comes from MuSe, 0…1; nil for an empty library.
    static func museCoverage(tracks: [Track], scores: [SongScore]) -> Double? {
        guard !tracks.isEmpty else { return nil }
        let museIds = Set(scores.filter { $0.origin == .muse }.map(\.spotifyId))
        return Double(tracks.count { museIds.contains($0.spotifyId) }) / Double(tracks.count)
    }

    /// The search of the Library tab: the title or one of the artists contains the query,
    /// whatever the case and accents. An empty query keeps every song.
    static func matches(title: String, artists: [String], query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return title.localizedStandardContains(query) || artists.contains { $0.localizedStandardContains(query) }
    }
}
