import Foundation
import SQLite3

/// The MuSe table shipped with the app (`Resources/muse.sqlite`, built by `ml/muse_build.py`,
/// TODO 1.39, 2.32): energy and positivity as MuSe percentiles, 0…1 (PROJECT.md §5.2).
/// MuSe: Akiki & Burghardt 2021, doi:10.5334/johd.33, CC BY 4.0.
nonisolated final class MuseCatalog {
    /// A score found in MuSe, and how the song was found.
    struct Match: Equatable {
        enum Key: Equatable { case spotifyId, titleAndArtist }
        let energy: Double
        let positivity: Double
        let foundBy: Key
    }

    enum OpenError: Error {
        case missing
        case sqlite(String)
    }

    private var db: OpaquePointer?
    private var byId: OpaquePointer?
    private var byKey: OpaquePointer?

    /// Opens a `muse.sqlite` file, read-only.
    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open"
            sqlite3_close(db)
            throw OpenError.sqlite(message)
        }
        byId = try prepare("SELECT energy, positivity, genre FROM songs WHERE spotify_id = ? LIMIT 1")
        byKey = try prepare("SELECT energy, positivity, genre FROM songs WHERE match_key = ?")
    }

    deinit {
        sqlite3_finalize(byId)
        sqlite3_finalize(byKey)
        sqlite3_close(db)
    }

    /// The copy in the app bundle.
    static func bundled() throws -> MuseCatalog {
        guard let url = Bundle.main.url(forResource: "muse", withExtension: "sqlite") else { throw OpenError.missing }
        return try MuseCatalog(url: url)
    }

    /// PROJECT.md §7: first the Spotify ID, then title + first artist (normalized with `SongKey`).
    /// Rows whose ID was shared by several MuSe songs have no ID (§5.2): title + artist only.
    func lookUp(spotifyId: String, title: String, artists: [String]) -> Match? {
        row(spotifyId: spotifyId, title: title, artists: artists)?.match
    }

    /// The MuSe genre of a song found as in `lookUp`; nil if not found or without genre.
    /// The genres of the library songs drive the MuSe suggestions (PROJECT.md §8).
    func genre(spotifyId: String, title: String, artists: [String]) -> String? {
        guard let genre = row(spotifyId: spotifyId, title: title, artists: artists)?.genre, !genre.isEmpty else { return nil }
        return genre
    }

    private func row(spotifyId: String, title: String, artists: [String]) -> (match: Match, genre: String)? {
        if !spotifyId.isEmpty, let (energy, positivity, genre) = scores(byId, spotifyId) {
            return (Match(energy: energy, positivity: positivity, foundBy: .spotifyId), genre)
        }
        for key in Self.titleKeys(title: title, artist: artists.first ?? "") {
            if let (energy, positivity, genre) = scores(byKey, key) {
                return (Match(energy: energy, positivity: positivity, foundBy: .titleAndArtist), genre)
            }
        }
        return nil
    }

    /// A MuSe song that can be suggested: it has a Spotify ID (to be checked before playing).
    struct Song: Equatable {
        let spotifyId: String
        let title: String
        /// MuSe's artist text, the first artist first.
        let artists: String
        let genre: String
        let energy: Double
        let positivity: Double
    }

    /// MuSe songs with a Spotify ID whose first artist (normalized, the artist half of
    /// `match_key`) is one of `artistKeys`, the closest to `energy` first.
    func songs(byArtists artistKeys: Set<String>, near energy: Double, limit: Int) -> [Song] {
        songs(where: "substr(match_key, instr(match_key, char(9)) + 1)", in: artistKeys, near: energy, limit: limit)
    }

    /// MuSe songs with a Spotify ID in one of `genres`, the closest to `energy` first.
    func songs(inGenres genres: Set<String>, near energy: Double, limit: Int) -> [Song] {
        songs(where: "genre", in: genres, near: energy, limit: limit)
    }

    /// Any MuSe song with a Spotify ID, the closest to `energy` first.
    func songs(near energy: Double, limit: Int) -> [Song] {
        songs(where: nil, in: [], near: energy, limit: limit)
    }

    private func songs(where column: String?, in values: Set<String>, near energy: Double, limit: Int) -> [Song] {
        if column != nil && values.isEmpty { return [] }
        let values = values.sorted()
        let filter = column.map { " AND \($0) IN (\(Array(repeating: "?", count: values.count).joined(separator: ", ")))" } ?? ""
        let sql = """
            SELECT spotify_id, title, artists, genre, energy, positivity FROM songs
            WHERE spotify_id != ''\(filter) ORDER BY abs(energy - ?), spotify_id LIMIT ?
            """
        guard let statement = try? prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, Self.transient)
        }
        sqlite3_bind_double(statement, Int32(values.count + 1), energy)
        sqlite3_bind_int(statement, Int32(values.count + 2), Int32(limit))
        var songs: [Song] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            func text(_ column: Int32) -> String { String(cString: sqlite3_column_text(statement, column)) }
            songs.append(Song(spotifyId: text(0), title: text(1), artists: text(2), genre: text(3),
                              energy: sqlite3_column_double(statement, 4), positivity: sqlite3_column_double(statement, 5)))
        }
        return songs
    }

    /// The key gives a different result for a straight `'` (a space) and a curly `’` (`'`), so
    /// "Don’t" would miss "Don't". Both spellings are tried: straight first, as most of MuSe writes
    /// it (6,595 titles with `'`, 62 with `’`), then curly (PROJECT.md §5.2).
    static func titleKeys(title: String, artist: String) -> [String] {
        func respell(_ text: String, _ apostrophe: Unicode.Scalar) -> String {
            String(String.UnicodeScalarView(text.unicodeScalars.map {
                $0 == "'" || SongKey.apostrophes.contains($0) ? apostrophe : $0
            }))
        }
        let straight = SongKey.match(title: respell(title, "'"), artist: respell(artist, "'"))
        let curly = SongKey.match(title: respell(title, "\u{2019}"), artist: respell(artist, "\u{2019}"))
        return straight == curly ? [straight] : [straight, curly]
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw OpenError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func scores(_ statement: OpaquePointer?, _ value: String) -> (Double, Double, String)? {
        defer { sqlite3_reset(statement) }
        sqlite3_bind_text(statement, 1, value, -1, Self.transient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (sqlite3_column_double(statement, 0), sqlite3_column_double(statement, 1),
                String(cString: sqlite3_column_text(statement, 2)))
    }

    /// SQLite copies the bound text.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
