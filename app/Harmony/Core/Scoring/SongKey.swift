import Foundation

/// Title and artist normalization for MuSe lookups (TODO 2.32, PROJECT.md §7): the Swift twin of
/// `ml/normalize.py` (TODO 1.40), which built the `match_key` column of `muse.sqlite`. Both must
/// give the same key; the shared cases are `ml/fixtures/normalize_cases.json`.
///
/// Order: NFKC; casefold; cut at the first feat./ft./featuring marker; remove version labels
/// (Remaster(ed) with an optional year, Radio Edit, Single Version, Album Version, Mono, Stereo)
/// in brackets or at the end; curly apostrophes become `'`, other punctuation and symbols spaces;
/// accents removed from Latin letters only; spaces collapsed. Like Python, works on Unicode
/// scalars (code points), not on grapheme clusters.
nonisolated enum SongKey {
    /// `normalized title` + tab + `normalized first artist`, as `match_key` in `muse.sqlite`.
    static func match(title: String, artist: String) -> String {
        "\(self.title(title))\t\(self.artist(artist))"
    }

    /// Feat. markers and version labels removed. If nothing is left, the whole title is kept.
    static func title(_ value: String) -> String {
        normalize(value, isTitle: true)
    }

    /// The first artist: the text before a feat. marker (never cut at `&`, `and` or `,`).
    static func artist(_ value: String) -> String {
        normalize(firstArtist(value), isTitle: false)
    }

    private static let feat = try! NSRegularExpression(
        pattern: #"\b(?:feat\.?|ft\.?|featuring)\b"#, options: .caseInsensitive)
    private static let versionLabel =
        #"(?:\d{4}\s+remaster(?:ed)?|remaster(?:ed)?(?:\s+\d{4})?|radio\s+edit|single\s+version|album\s+version|mono|stereo)"#
    private static let versions = try! NSRegularExpression(
        pattern: #"(?:\s*[\[(]\s*\#(versionLabel)\s*[\])]|\s*[-–—]\s*\#(versionLabel)|\s+\#(versionLabel))\s*$"#,
        options: .caseInsensitive)
    /// The apostrophes that become `'` (the straight `'` itself is punctuation, so a space).
    static let apostrophes: Set<Unicode.Scalar> = ["\u{2018}", "\u{2019}", "\u{02BC}", "\u{FF07}", "\u{0060}", "\u{00B4}"]

    private static func firstArtist(_ value: String) -> String {
        cutAtFeat(value.precomposedStringWithCompatibilityMapping)
    }

    private static func normalize(_ value: String, isTitle: Bool) -> String {
        let original = casefold(value.precomposedStringWithCompatibilityMapping)
        var cleaned = cutAtFeat(original)
        while true {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            let updated = versions.stringByReplacingMatches(in: cleaned, range: range, withTemplate: " ")
            if updated == cleaned { break }
            cleaned = updated
        }
        let result = tidy(cleaned)
        return isTitle && result.isEmpty ? tidy(original) : result
    }

    private static func cutAtFeat(_ value: String) -> String {
        guard let match = feat.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range, in: value) else { return value }
        return String(value[..<range.lowerBound])
    }

    /// Python's `str.casefold()`: full case folding (`ß` → `ss`), not just lowercase. Foundation
    /// folds the same way on every code point except 181 (checked on all of Unicode): Cherokee,
    /// which Unicode folds to uppercase, and the old Cyrillic letter variants U+1C80–U+1C88.
    private static func casefold(_ value: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.folding(options: .caseInsensitive, locale: nil).unicodeScalars {
            switch scalar.value {
            case 0xAB70...0xABBF: scalars.append(Unicode.Scalar(scalar.value - 0xAB70 + 0x13A0)!)
            case 0x13F8...0x13FD: scalars.append(Unicode.Scalar(scalar.value - 8)!)
            case 0x1C80...0x1C88: scalars.append(oldCyrillic[Int(scalar.value - 0x1C80)])
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// Case folding of U+1C80…U+1C88 (CaseFolding.txt).
    private static let oldCyrillic: [Unicode.Scalar] = [
        "\u{0432}", "\u{0434}", "\u{043E}", "\u{0441}", "\u{0442}", "\u{0442}", "\u{044A}", "\u{0463}", "\u{A64B}",
    ]

    /// Apostrophes, punctuation and symbols, Latin accents, then Python's `" ".join(text.split())`.
    private static func tidy(_ value: String) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in value.unicodeScalars {
            if apostrophes.contains(scalar) {
                scalars.append("'")
            } else if isPunctuationOrSymbol(scalar) {
                scalars.append(" ")
            } else if scalar.properties.name?.contains("LATIN") == true {
                let decomposed = String(scalar).decomposedStringWithCompatibilityMapping.unicodeScalars
                scalars.append(contentsOf: decomposed.filter { !isMark($0) })
            } else {
                scalars.append(scalar)
            }
        }
        // Split on scalars, not Characters: a space followed by a combining mark is one Character.
        return scalars
            .split(whereSeparator: isPythonSpace)
            .map { String(String.UnicodeScalarView($0)) }
            .joined(separator: " ")
    }

    private static func isPunctuationOrSymbol(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation,
             .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            true
        default:
            false
        }
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }

    /// The characters Python's `str.split()` splits on (`str.isspace()`).
    private static func isPythonSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09...0x0D, 0x1C...0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            true
        default:
            false
        }
    }
}
