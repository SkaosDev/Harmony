import Foundation
import SQLite3
@testable import Harmony

/// A MuSe row as `ml/muse_build.py` writes it. `matchKey` is written by hand, as Python gives it.
struct MuseRow {
    var spotifyId = ""
    var title: String
    var artists: String
    var genre = ""
    var energy: Double
    var positivity: Double
    var matchKey: String
}

/// A temporary `muse.sqlite` with the schema of `ml/muse_build.py` and the given rows.
func makeMuseFile(_ rows: [MuseRow]) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("muse-\(UUID().uuidString).sqlite")
    var db: OpaquePointer?
    guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw MuseCatalog.OpenError.sqlite("cannot create") }
    defer { sqlite3_close(db) }
    sqlite3_exec(db, """
        CREATE TABLE songs (
            spotify_id TEXT NOT NULL, title TEXT NOT NULL, artists TEXT NOT NULL, genre TEXT NOT NULL,
            energy REAL NOT NULL, positivity REAL NOT NULL, match_key TEXT PRIMARY KEY
        ) WITHOUT ROWID;
        CREATE INDEX songs_spotify_id ON songs (spotify_id);
        """, nil, nil, nil)
    for row in rows {
        let values = [row.spotifyId, row.title, row.artists, row.genre].map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
        let key = "'\(row.matchKey.replacingOccurrences(of: "'", with: "''"))'"
        let sql = "INSERT INTO songs VALUES (\(values.joined(separator: ", ")), \(row.energy), \(row.positivity), \(key))"
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw MuseCatalog.OpenError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }
    return url
}

/// Every row of a query, as text columns.
func sqliteRows(_ url: URL, _ sql: String) throws -> [[String]] {
    var db: OpaquePointer?
    guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { throw MuseCatalog.OpenError.missing }
    defer { sqlite3_close(db) }
    var statement: OpaquePointer?
    sqlite3_prepare_v2(db, sql, -1, &statement, nil)
    defer { sqlite3_finalize(statement) }
    var rows: [[String]] = []
    while sqlite3_step(statement) == SQLITE_ROW {
        rows.append((0..<sqlite3_column_count(statement)).map { String(cString: sqlite3_column_text(statement, $0)) })
    }
    return rows
}
