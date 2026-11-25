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

    def test_week(self):
        table = self.result["week"]
        # 5 queues on days 1-4 (the queue before day 1 is not exported): 5 skips out of 14 decided
        # songs; 4 answers out of 5, 2 "yes".
        self.assertEqual((table["days"], table["queues"], table["decided"]), (4, 5, 14))
        self.assertAlmostEqual(table["skip_rate"], 5 / 14)
        self.assertAlmostEqual(table["answer_rate"], 4 / 5)
        self.assertAlmostEqual(table["fit_rate"], 2 / 4)

    def test_intervals_hold_the_rate_and_repeat(self):
        table = self.result["week"]
        for key in ("skip", "fit"):
            low, high = table[f"{key}_ci"]
            self.assertLessEqual(low, table[f"{key}_rate"] + 1e-12)
            self.assertGreaterEqual(high, table[f"{key}_rate"] - 1e-12)
        self.assertEqual(P.bootstrap(self.data["queues"], P.skip_rate),
                         P.bootstrap(self.data["queues"], P.skip_rate))

    def test_no_queue_gives_no_interval(self):
        self.assertTrue(all(math.isnan(v) for v in P.bootstrap([], P.skip_rate)))
        self.assertTrue(math.isnan(P.summary({**self.data, "queues": []})["week"]["skip_rate"]))

    def test_no_kind_column(self):
        # TODO 4.4: no daily draw, so no table by kind of queue.
        self.assertNotIn("kind", json.dumps(self.data))
        self.assertNotIn("Time only |", P.markdown(self.result))

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
            "time_fallback": (3, 5),
        })

    def test_markdown_tables(self):
        text = P.markdown(self.result)
        for title in ("TODO 4.7", "TODO 4.8", "TODO 4.9"):
            self.assertIn(title, text)
        self.assertIn("| Skip rate (< 30 s) | 0.36 [", text)
        self.assertIn("| Hours with a heart rate | 60/92 | 0.65 |", text)

    def test_other_formats_are_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "old.json"
            path.write_text(json.dumps({**self.data, "format": "harmony-pilot-0"}), encoding="utf-8")
            with self.assertRaises(ValueError):
                P.load(path)


if __name__ == "__main__":
    unittest.main()
