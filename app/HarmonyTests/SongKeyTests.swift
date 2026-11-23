import Foundation
import Testing
@testable import Harmony

/// TODO 2.32: the Swift normalization gives the same keys as `ml/normalize.py` (TODO 1.40).
struct SongKeyTests {
    struct Case: Decodable, CustomTestStringConvertible {
        let title: String
        let artist: String
        let key: String
        var testDescription: String { "\(title) / \(artist)" }
    }

    /// `ml/fixtures/normalize_cases.json`, shared with `ml/tests/test_normalize.py`; the test
    /// target copies it into its bundle.
    static let cases: [Case] = {
        let url = Bundle(for: BundleToken.self).url(forResource: "normalize_cases", withExtension: "json")!
        return try! JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
    }()

    @Test func fixtureHasTheSharedCases() {
        #expect(Self.cases.count == 31)
    }

    @Test(arguments: cases)
    func matchesPython(_ testCase: Case) {
        #expect(SongKey.match(title: testCase.title, artist: testCase.artist) == testCase.key)
    }

    /// Python's `casefold`, not lowercase; Cherokee folds to uppercase in Unicode.
    @Test func casefoldsLikePython() {
        #expect(SongKey.title("Straße") == "strasse")
        #expect(SongKey.title("\u{AB70}\u{13A0}") == "\u{13A0}\u{13A0}")
        #expect(SongKey.title("\u{1C80}") == "\u{0432}")
    }

    /// As in Python: curly apostrophes become `'`, the ASCII one is punctuation, so a space.
    @Test func apostrophes() {
        #expect(SongKey.title("Don’t Stop") == "don't stop")
        #expect(SongKey.title("Don't Stop") == "don t stop")
    }
}

private final class BundleToken {}
