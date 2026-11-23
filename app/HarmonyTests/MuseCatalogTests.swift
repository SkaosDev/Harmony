import Foundation
import Testing
@testable import Harmony

/// TODO 2.32: MuSe lookup, first by Spotify ID, then by title + first artist (PROJECT.md §7).
@MainActor
struct MuseCatalogTests {
    /// Keys written as `ml/normalize.py` gives them.
    nonisolated static let rows = [
        MuseRow(spotifyId: "id-bohemian", title: "Bohemian Rhapsody", artists: "Queen", energy: 0.81, positivity: 0.42, matchKey: "bohemian rhapsody\tqueen"),
        // ID cleared by `muse_build.py` (shared by several MuSe songs): findable by title only.
        MuseRow(title: "Song For Nobody", artists: "Some Band", energy: 0.30, positivity: 0.60, matchKey: "song for nobody\tsome band"),
        MuseRow(spotifyId: "id-cafe", title: "Café del Mar", artists: "Energy 52", energy: 0.70, positivity: 0.65, matchKey: "cafe del mar\tenergy 52"),
        MuseRow(spotifyId: "id-hangul", title: "밤편지", artists: "아이유", energy: 0.20, positivity: 0.55, matchKey: "밤편지\t아이유"),
        MuseRow(spotifyId: "id-september", title: "September", artists: "Earth, Wind & Fire", energy: 0.85, positivity: 0.95, matchKey: "september\tearth wind fire"),
        MuseRow(spotifyId: "id-dont-stop", title: "Don't Stop Me Now", artists: "Queen", energy: 0.90, positivity: 0.90, matchKey: "don t stop me now\tqueen"),
        MuseRow(spotifyId: "id-live", title: "Song (Live)", artists: "Live Band", energy: 0.55, positivity: 0.50, matchKey: "song live\tlive band"),
        MuseRow(spotifyId: "id-other", title: "Other Title", artists: "Other Artist", energy: 0.10, positivity: 0.15, matchKey: "other title\tother artist"),
        // Curly apostrophes in MuSe (62 titles), and one song written both ways.
        MuseRow(title: "Sweet Child O’ Mine", artists: "Guns N’ Roses", energy: 0.75, positivity: 0.70, matchKey: "sweet child o' mine\tguns n' roses"),
        MuseRow(title: "It’s Time", artists: "Some Band", energy: 0.20, positivity: 0.30, matchKey: "it's time\tsome band"),
        MuseRow(title: "It's Time", artists: "Some Band", energy: 0.60, positivity: 0.40, matchKey: "it s time\tsome band"),
    ]

    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        var spotifyId = ""
        let title: String
        let artists: [String]
        /// MuSe energy of the expected row, or nil if the song must not be found.
        let energy: Double?
        var foundBy: MuseCatalog.Match.Key = .titleAndArtist
        var testDescription: String { name }
    }

    /// The 20 cases of TODO 2.32, Spotify-style inputs.
    nonisolated static let cases: [Case] = [
        Case(name: "Spotify ID", spotifyId: "id-bohemian", title: "Anything", artists: ["Anyone"], energy: 0.81, foundBy: .spotifyId),
        Case(name: "ID beats title", spotifyId: "id-other", title: "Bohemian Rhapsody", artists: ["Queen"], energy: 0.10, foundBy: .spotifyId),
        Case(name: "unknown ID, then title", spotifyId: "no-such-id", title: "Bohemian Rhapsody", artists: ["Queen"], energy: 0.81),
        Case(name: "remaster after a dash", title: "Bohemian Rhapsody - Remastered 2011", artists: ["Queen"], energy: 0.81),
        Case(name: "remaster in brackets", title: "Bohemian Rhapsody (2011 Remaster)", artists: ["Queen"], energy: 0.81),
        Case(name: "case and spaces", title: "  BOHEMIAN   rhapsody ", artists: ["QUEEN"], energy: 0.81),
        Case(name: "second artist ignored", title: "Bohemian Rhapsody", artists: ["Queen", "David Bowie"], energy: 0.81),
        Case(name: "feat. in the title", title: "September (feat. Someone)", artists: ["Earth, Wind & Fire"], energy: 0.85),
        Case(name: "feat. in the artist", title: "September", artists: ["Earth, Wind & Fire feat. Someone"], energy: 0.85),
        Case(name: "only the first artist counts", title: "September", artists: ["Earth", "Wind & Fire"], energy: nil),
        Case(name: "accents removed", title: "Cafe Del Mar", artists: ["Energy 52"], energy: 0.70),
        Case(name: "full-width letters", title: "Ｃａｆé ｄｅｌ Ｍａｒ", artists: ["Ｅｎｅｒｇｙ ５２"], energy: 0.70),
        Case(name: "Hangul untouched", title: "밤편지", artists: ["아이유"], energy: 0.20),
        Case(name: "row without ID, by title", title: "Song For Nobody", artists: ["Some Band"], energy: 0.30),
        Case(name: "empty ID never matches a row without ID", title: "Nothing Here", artists: ["Nobody"], energy: nil),
        Case(name: "ASCII apostrophe", title: "Don't Stop Me Now", artists: ["Queen"], energy: 0.90),
        Case(name: "radio edit", title: "Don't Stop Me Now - Radio Edit", artists: ["Queen"], energy: 0.90),
        Case(name: "live is kept", title: "Song - Live", artists: ["Live Band"], energy: 0.55),
        Case(name: "studio version is not the live one", title: "Song", artists: ["Live Band"], energy: nil),
        Case(name: "no artist", title: "Bohemian Rhapsody", artists: [], energy: nil),
    ]

    @Test func twentyCases() {
        #expect(Self.cases.count == 20)
    }

    @Test(arguments: cases)
    func lookUp(_ testCase: Case) throws {
        let catalog = try MuseCatalog(url: makeMuseFile(Self.rows))
        let match = catalog.lookUp(spotifyId: testCase.spotifyId, title: testCase.title, artists: testCase.artists)
        if let energy = testCase.energy {
            let found = try #require(match)
            #expect(found.energy == energy)
            #expect(found.foundBy == testCase.foundBy)
        } else {
            #expect(match == nil)
        }
    }

    /// "Don’t" finds "Don't" and the other way round; when MuSe has both, the straight one
    /// (most of MuSe) comes first.
    @Test(arguments: [
        ("Don’t Stop Me Now", "Queen", 0.90),
        ("Sweet Child O' Mine", "Guns N' Roses", 0.75),
        ("Sweet Child O’ Mine", "Guns N’ Roses", 0.75),
        ("Sweet Child Oʼ Mine", "Guns N' Roses", 0.75),
        ("It's Time", "Some Band", 0.60),
        ("It’s Time", "Some Band", 0.60),
    ])
    func apostrophesMatchEitherWay(_ title: String, _ artist: String, _ energy: Double) throws {
        let catalog = try MuseCatalog(url: makeMuseFile(Self.rows))
        let match = try #require(catalog.lookUp(spotifyId: "", title: title, artists: [artist]))
        #expect(match.energy == energy)
        #expect(match.foundBy == .titleAndArtist)
    }

    @Test func oneKeyWithoutApostrophe() {
        #expect(MuseCatalog.titleKeys(title: "Song", artist: "Artist") == ["song\tartist"])
        #expect(MuseCatalog.titleKeys(title: "It’s", artist: "A") == ["it s\ta", "it's\ta"])
    }

    @Test func missingFileIsAnError() {
        #expect(throws: MuseCatalog.OpenError.self) {
            try MuseCatalog(url: URL(fileURLWithPath: "/no/such/muse.sqlite"))
        }
    }
}

/// The copy shipped in the app (`Resources/muse.sqlite`, TODO 1.39).
@MainActor
struct BundledMuseTests {
    static let url = Bundle.main.url(forResource: "muse", withExtension: "sqlite")

    @Test func isBundledWithEveryRow() throws {
        let url = try #require(Self.url)
        #expect(try sqliteRows(url, "SELECT COUNT(*) FROM songs") == [["89269"]])
        _ = try MuseCatalog.bundled()
    }

    /// Swift and Python give the same key for every MuSe song (PROJECT.md §7).
    @Test func swiftKeysEqualPythonKeys() throws {
        let rows = try sqliteRows(#require(Self.url), "SELECT title, artists, match_key FROM songs")
        let mismatches = rows.filter { SongKey.match(title: $0[0], artist: $0[1]) != $0[2] }
        #expect(rows.count == 89_269)
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }

    /// Real rows come back, by ID and by title + artist.
    @Test func findsRealSongs() throws {
        let url = try #require(Self.url)
        let catalog = try MuseCatalog.bundled()
        let withId = try sqliteRows(url, "SELECT spotify_id, energy FROM songs WHERE spotify_id != '' LIMIT 50")
        #expect(withId.count == 50)
        for row in withId {
            let match = try #require(catalog.lookUp(spotifyId: row[0], title: "", artists: []))
            #expect(match.foundBy == .spotifyId)
            #expect(abs(match.energy - Double(row[1])!) < 1e-12)
        }
        let withoutId = try sqliteRows(url, "SELECT title, artists, energy FROM songs WHERE spotify_id = '' LIMIT 50")
        #expect(withoutId.count == 50)
        for row in withoutId {
            let match = try #require(catalog.lookUp(spotifyId: "", title: row[0], artists: [row[1]]))
            #expect(match.foundBy == .titleAndArtist)
            #expect(abs(match.energy - Double(row[2])!) < 1e-12)
        }
    }
}
