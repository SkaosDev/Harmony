"""Shared Python/Swift song-normalization cases (TODO 1.40)."""

import json
import unittest
from pathlib import Path

from ml.normalize import match_key


FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "normalize_cases.json"


class NormalizeTests(unittest.TestCase):
    def test_shared_cases(self):
        cases = json.loads(FIXTURES.read_text(encoding="utf-8"))
        for case in cases:
            with self.subTest(title=case["title"], artist=case["artist"]):
                self.assertEqual(match_key(case["title"], case["artist"]), case["key"])


if __name__ == "__main__":
    unittest.main()
