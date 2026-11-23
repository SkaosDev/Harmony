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
        byId = try prepare("SELECT energy, positivity FROM songs WHERE spotify_id = ? LIMIT 1")
        byKey = try prepare("SELECT energy, positivity FROM songs WHERE match_key = ?")
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
        if !spotifyId.isEmpty, let (energy, positivity) = scores(byId, spotifyId) {
            return Match(energy: energy, positivity: positivity, foundBy: .spotifyId)
        }
        let key = SongKey.match(title: title, artist: artists.first ?? "")
        if let (energy, positivity) = scores(byKey, key) {
            return Match(energy: energy, positivity: positivity, foundBy: .titleAndArtist)
        }
        return nil
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw OpenError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func scores(_ statement: OpaquePointer?, _ value: String) -> (Double, Double)? {
        defer { sqlite3_reset(statement) }
        sqlite3_bind_text(statement, 1, value, -1, Self.transient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (sqlite3_column_double(statement, 0), sqlite3_column_double(statement, 1))
    }

    /// SQLite copies the bound text.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
