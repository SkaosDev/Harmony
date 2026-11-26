"""Pilot analysis (TODO 4.7-4.9, 6.15) on ml/fixtures/pilot_export_example.json, the synthetic export
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

    def test_answer_rate(self):
        # 9 answered, 1 "Not now", 2 ignored, 1 still waiting (counted apart); 9 answers, of which
        # 3 have a label and both probabilities (the last one waits for its state).
        table = self.result["checkins"]
        self.assertEqual(table["prompts"], {"answered": 9, "notNow": 1, "ignored": 2, "waiting": 1})
        self.assertAlmostEqual(table["answer_rate"], 9 / 12)
        self.assertEqual((table["answers"], table["labelled"]), (9, 3))

    def test_chronological_auroc_by_days_of_use(self):
        rows = {row["bin"]: row for row in self.result["checkins"]["auroc"]}
        self.assertEqual(list(rows), ["Days 1–3", "Days 4–7", "Whole week"])
        # Days 1-3: one labelled answer, a single class, so no AUROC.
        early = rows["Days 1–3"]
        self.assertEqual((early["n"], early["above"]), (1, 1))
        self.assertTrue(math.isnan(early["common"]) and math.isnan(early["personal"]))
        # Days 4-7: below (common 0.52, personal 0.50), above (0.49, 0.61).
        late = rows["Days 4–7"]
        self.assertEqual((late["n"], late["above"]), (2, 1))
        self.assertAlmostEqual(late["common"], 0.0)
        self.assertAlmostEqual(late["personal"], 1.0)
        self.assertAlmostEqual(late["difference"], 1.0)
        # Week: above 0.53 / 0.53 and 0.49 / 0.61, below 0.52 / 0.50.
        week = rows["Whole week"]
        self.assertEqual((week["n"], week["above"]), (3, 2))
        self.assertAlmostEqual(week["common"], 0.5)
        self.assertAlmostEqual(week["personal"], 1.0)
        self.assertAlmostEqual(week["difference"], 0.5)

    def test_auroc_intervals_repeat_and_stay_in_range(self):
        week = self.result["checkins"]["auroc"][-1]
        self.assertEqual(week, P.summary(self.data)["checkins"]["auroc"][-1])
        for key, low_bound in (("common", 0), ("personal", 0), ("difference", -1)):
            low, high = week[f"{key}_ci"]
            self.assertTrue(low_bound <= low <= high <= 1, key)

    def test_reward(self):
        def queue(events, fit=None):
            return {"events": [{"event": e, "position": 0} for e in events], **({"fit": fit} if fit else {})}
        self.assertEqual(P.reward(queue(["skip"], "yes")), 1)
        self.assertEqual(P.reward(queue(["like"], "no")), 0.2)
        self.assertAlmostEqual(P.reward(queue(["skip", "finish", "finish"])), 2 / 3)
        self.assertAlmostEqual(P.reward(queue(["skip", "like", "like", "like"])), 0.6)
        self.assertEqual(P.reward(queue(["finish", "like", "like"], "yes")), 1)
        self.assertIsNone(P.reward(queue(["like"])))

    def test_reward_by_strategy(self):
        # S1 queues: yes + like (1), no (0), yes (1), no (0); the day-2 queue has no strategy.
        rows = self.result["strategies"]
        self.assertEqual([(r["strategy"], r["n"]) for r in rows], [("s1", 4)])
        self.assertAlmostEqual(rows[0]["mean"], 0.5)
        low, high = rows[0]["ci"]
        self.assertTrue(0 <= low <= 0.5 <= high <= 1)

    def test_check_in_tables(self):
        text = P.markdown(self.result)
        self.assertIn("TODO 6.15", text)
        self.assertIn("| Answered | 9/12 | 0.75 |", text)
        self.assertIn("| Days 1–3 | 1 | 1 | – | – | – |", text)
        self.assertIn("| Whole week | 3 | 2 | 0.50 [", text)
        self.assertIn("| s1 | 4 | 0.50 [", text)

    def test_other_formats_are_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "old.json"
            path.write_text(json.dumps({**self.data, "format": "harmony-pilot-0"}), encoding="utf-8")
            with self.assertRaises(ValueError):
                P.load(path)


if __name__ == "__main__":
    unittest.main()
