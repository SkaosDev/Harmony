"""Normalize public song titles and artists for MuSe lookup (TODO 1.40).

Normalization order (also used by the shared Swift fixtures): NFKC; casefold;
cut at the first feat./ft./featuring marker and everything after it; remove
version phrases only when parenthesized/bracketed or at the end after a dash or
space: Remaster/Remastered with an optional four-digit year before or after,
Radio Edit, Single Version, Album Version, Mono, Stereo. Map curly apostrophe
variants to ASCII apostrophe and other punctuation/symbols to spaces. For each
character whose Unicode name contains LATIN, apply NFKD and drop combining
marks; leave all other scripts undecomposed. Collapse whitespace. If the result
is empty, normalize the NFKC/casefolded input before feature/version removal.
"""

import re
import unicodedata

_FEAT = re.compile(r"\b(?:feat\.?|ft\.?|featuring)\b", re.IGNORECASE)
_VERSION_LABEL = (
    r"(?:\d{4}\s+remaster(?:ed)?|remaster(?:ed)?(?:\s+\d{4})?|"
    r"radio\s+edit|single\s+version|album\s+version|mono|stereo)"
)
_VERSIONS = re.compile(
    rf"(?:\s*[\[(]\s*{_VERSION_LABEL}\s*[\])]|"
    rf"\s*[-–—]\s*{_VERSION_LABEL}|\s+{_VERSION_LABEL})\s*$",
    re.IGNORECASE,
)
_APOSTROPHES = {"\u2018", "\u2019", "\u02bc", "\uff07", "\u0060", "\u00b4"}


def first_artist(value: str) -> str:
    """Return the first MuSe artist, cutting only at a feat. marker."""
    value = unicodedata.normalize("NFKC", value or "")
    match = _FEAT.search(value)
    return value[:match.start()] if match else value


def _remove_latin_accents(value: str) -> str:
    result = []
    for char in value:
        if "LATIN" in unicodedata.name(char, ""):
            result.extend(c for c in unicodedata.normalize("NFKD", char)
                          if not unicodedata.category(c).startswith("M"))
        else:
            result.append(char)
    return "".join(result)


def _normalize(value: str, *, title: bool) -> str:
    original = unicodedata.normalize("NFKC", value or "").casefold()
    def tidy(text):
        text = "".join("'" if char in _APOSTROPHES else
                       " " if unicodedata.category(char).startswith(("P", "S")) else char
                       for char in text)
        return " ".join(_remove_latin_accents(text).split())

    match = _FEAT.search(original)
    cleaned = original[:match.start()] if match else original
    while True:
        updated = _VERSIONS.sub(" ", cleaned)
        if updated == cleaned:
            break
        cleaned = updated
    result = tidy(cleaned)
    if title and not result:
        return tidy(original)
    return result


def normalize_title(value: str) -> str:
    """Normalize a title, removing feat. and non-distinguishing version labels.

    Live, Remix, Acoustic, Instrumental, and Demo remain because they identify
    distinct recordings. Punctuation becomes spacing; apostrophes are unified.
    """
    return _normalize(value, title=True)


def normalize_artist(value: str) -> str:
    """Normalize an artist string without splitting groups or comma names."""
    return _normalize(first_artist(value), title=False)


def match_key(title: str, artist: str) -> str:
    """Return normalized title, a tab, and the first normalized artist."""
    return f"{normalize_title(title)}\t{normalize_artist(first_artist(artist))}"
