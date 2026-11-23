"""Pilot analysis (TODO 4.7-4.9) on ml/fixtures/pilot_export_example.json, the synthetic export
also checked by the app (PilotExportTests). Expected values computed by hand."""

import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pilot_analysis as P                                       # noqa: E402

FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "pilot_export_example.json"


class PilotAnalysisTest(unittest.TestCase):
    def setUp(self):
        self.data = P.load(FIXTURE)
        self.result = P.summary(self.data)

    def test_by_kind_drawn(self):
        table = self.result["by_kind"]
        body, time_only = table["body"], table["timeOnly"]
        # Body: days 1 and 4, queues 1, 2, 5: 4 skips out of 8 decided songs.
        self.assertEqual((body["days"], body["queues"], body["decided"]), (2, 3, 8))
        self.assertAlmostEqual(body["skip_rate"], 4 / 8)
        self.assertAlmostEqual(body["answer_rate"], 1.0)
        self.assertAlmostEqual(body["fit_rate"], 1 / 3)
        # Time only: days 2 and 3: 1 skip out of 6; one answer out of two, "yes".
        self.assertEqual((time_only["days"], time_only["queues"], time_only["decided"]), (2, 2, 6))
        self.assertAlmostEqual(time_only["skip_rate"], 1 / 6)
        self.assertAlmostEqual(time_only["answer_rate"], 0.5)
        self.assertAlmostEqual(time_only["fit_rate"], 1.0)
        self.assertAlmostEqual(table["skip_diff"], 4 / 8 - 1 / 6)

    def test_by_estimate_used(self):
        # Queue 5 is a body day started from the time of day: it moves to the time-only column.
        table = self.result["by_mode"]
        self.assertEqual((table["body"]["queues"], table["timeOnly"]["queues"]), (2, 3))
        self.assertAlmostEqual(table["body"]["skip_rate"], 3 / 6)
        self.assertAlmostEqual(table["timeOnly"]["skip_rate"], 2 / 8)

    def test_intervals_hold_the_difference_and_repeat(self):
        table = self.result["by_kind"]
        for key in ("skip", "fit"):
            low, high = table[f"{key}_ci"]
            self.assertLessEqual(low, table[f"{key}_diff"] + 1e-12)
            self.assertGreaterEqual(high, table[f"{key}_diff"] - 1e-12)
        self.assertEqual(P.bootstrap(self.data["queues"], "kind", P.skip_rate),
                         P.bootstrap(self.data["queues"], "kind", P.skip_rate))

    def test_a_kind_without_days_gives_no_interval(self):
        body_only = [q for q in self.data["queues"] if q["kind"] == "body"]
        self.assertTrue(all(math.isnan(v) for v in P.bootstrap(body_only, "kind", P.skip_rate)))
        self.assertTrue(math.isnan(P.summary({**self.data, "queues": body_only})["by_kind"]["skip_diff"]))

    def test_muse_fallback(self):
        self.assertEqual(self.result["muse"], {
            "queues_with_suggestion": (2, 5),
            "suggested_songs": (2, 15),
            "skip_suggestions": (1, 2),
            "skip_library": (4, 12),
        })

    def test_watch_coverage(self):
        self.assertEqual(self.result["watch"], {
            "nights_known": (2, 4),
            "hours_with_hr": (60, 92),
            "body_fallback": (1, 3),
        })

    def test_markdown_tables(self):
        text = P.markdown(self.result)
        for title in ("TODO 4.7", "TODO 4.8", "TODO 4.9"):
            self.assertIn(title, text)
        self.assertIn("| Skip rate (< 30 s) | 0.50 | 0.17 |", text)
        self.assertIn("| Hours with a heart rate | 60/92 | 0.65 |", text)

    def test_other_formats_are_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "old.json"
            path.write_text(json.dumps({**self.data, "format": "harmony-pilot-0"}), encoding="utf-8")
            with self.assertRaises(ValueError):
                P.load(path)


if __name__ == "__main__":
    unittest.main()
