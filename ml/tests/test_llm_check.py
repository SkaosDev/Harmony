"""LLM song scores (TODO 2.29, 2.30): shared cases with the Worker, trial 3 samples and
reference songs. Synthetic titles only, except the check of the prompt against real MuSe data
(skipped when data/muse/ is absent)."""

import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import llm_anchors as A                                          # noqa: E402
import llm_check as L                                            # noqa: E402

MUSE = Path(__file__).resolve().parents[2] / "data" / "muse"

CASES = json.loads((Path(__file__).resolve().parents[1] / "fixtures" / "score_cases.json")
                   .read_text(encoding="utf-8"))


class SharedCasesTests(unittest.TestCase):
    def test_user_message(self):
        for case in CASES["messages"]:
            with self.subTest(case["name"]):
                self.assertEqual(L.user_message(case["songs"]), case["expected"])

    def test_parse_scores(self):
        for case in CASES["parses"]:
            with self.subTest(case["name"]):
                self.assertEqual(L.parse_scores(case["text"], case["count"]), case["expected"])


class RequestTests(unittest.TestCase):
    def test_request_uses_the_shared_prompt_and_schema(self):
        params = L.request_params([{"title": "T", "artists": ["A"]}])
        self.assertEqual(params["model"], "claude-haiku-5-5")
        self.assertEqual(params["output_config"]["effort"], "low")     # few thinking tokens
        self.assertEqual(params["system"], [{"type": "text", "text": L.load_prompt(),
                                             "cache_control": {"type": "ephemeral"}}])
        self.assertEqual(params["messages"], [{"role": "user", "content": "0\tT\tA"}])
        self.assertEqual(params["output_config"]["format"]["schema"], L.load_config()["output_schema"])
        self.assertNotIn("thinking", params)          # adaptive thinking (the default), set by effort
        self.assertNotIn("temperature", params)       # sampling parameters are refused on Haiku 5.5

    def test_effort_can_be_overridden_for_the_trial_3_comparison(self):
        params = L.request_params([{"title": "T", "artists": ["A"]}], effort="medium")
        self.assertEqual(params["output_config"]["effort"], "medium")


def synthetic_db(path: Path, n: int = 120) -> None:
    with sqlite3.connect(path) as con:
        con.execute("CREATE TABLE songs (match_key TEXT PRIMARY KEY, spotify_id TEXT, title TEXT, "
                    "artists TEXT, genre TEXT, energy REAL, positivity REAL)")
        con.executemany("INSERT INTO songs VALUES (?, NULL, ?, ?, NULL, ?, ?)",
                        [(f"k{i:03d}", f"Title {i}", f"Artist {i % 7}", i / n, 1 - i / n)
                         for i in range(n)])


class CheckTests(unittest.TestCase):
    def test_sample_is_seeded_and_sized(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "muse.sqlite"
            synthetic_db(db)
            a, b = L.sample_songs(db, 60, seed=0), L.sample_songs(db, 60, seed=0)
        pd.testing.assert_frame_equal(a, b)
        self.assertEqual(list(a.columns), ["title", "artists", "energy", "positivity", "match_key"])
        self.assertEqual(len(a), 60)

    def test_batch_requests_send_titles_and_artists_only(self):
        sample = pd.DataFrame({"title": [f"T{i}" for i in range(120)], "artists": ["A"] * 120,
                               "energy": 0.1, "positivity": 0.9})
        requests = L.batch_requests(sample)
        self.assertEqual([r["custom_id"] for r in requests], ["chunk-000", "chunk-001", "chunk-002"])
        last = requests[2]["params"]["messages"][0]["content"]
        self.assertEqual(last.splitlines()[0], "0\tT100\tA")
        self.assertEqual(len(last.splitlines()), 20)
        self.assertNotIn("0.1", json.dumps([r["params"]["messages"] for r in requests]))

    def test_llm_scores_handles_failed_and_cut_requests(self):
        results = [
            {"custom_id": "chunk-000", "type": "succeeded", "stop_reason": "end_turn",
             "text": json.dumps({"s": [[i, 10, 90] for i in range(50)]})},
            {"custom_id": "chunk-001", "type": "errored"},
            {"custom_id": "chunk-002", "type": "succeeded", "stop_reason": "max_tokens", "text": "{"},
        ]
        scores = L.llm_scores(110, results)
        self.assertTrue((scores.loc[:49, "energy"] == 0.1).all())
        self.assertTrue(scores.loc[50:].isna().all().all())

    def test_metrics_and_rule(self):
        muse = pd.Series(np.linspace(0, 1, 101))
        perfect = L.metrics(muse.copy(), muse)
        self.assertAlmostEqual(perfect["spearman"], 1.0)
        self.assertAlmostEqual(perfect["mae"], 0.0)
        self.assertTrue(L.use_llm(perfect))
        reversed_ = L.metrics(1 - muse, muse)
        self.assertAlmostEqual(reversed_["spearman"], -1.0)
        self.assertFalse(L.use_llm(reversed_))
        half_missing = muse.where(muse.index % 2 == 0)
        self.assertAlmostEqual(L.metrics(half_missing, muse)["share_null"], 50 / 101)
        # A good ranking on the wrong scale passes once converted to percentiles.
        squeezed = L.metrics(0.4 + muse / 5, muse)
        self.assertLess(squeezed["mae_pct"], 0.02)
        self.assertTrue(L.use_llm(squeezed))

    def test_shrink_toward_neutral(self):
        muse = pd.Series(np.linspace(0, 1, 101))
        self.assertAlmostEqual(L.shrunk_mae(muse, muse, 0), (muse - 0.5).abs().mean())
        self.assertEqual(L.best_shrink(muse.copy(), muse), 1.0)
        self.assertLess(L.best_shrink(pd.Series(np.random.default_rng(0).random(101)), muse), 0.5)


def synthetic_songs(n: int = 4000) -> pd.DataFrame:
    rng = np.random.default_rng(1)
    return pd.DataFrame({
        "match_key": [f"title {i}\tartist {i}" for i in range(n)], "title": [f"Title {i}" for i in range(n)],
        "artists": [f"Artist {i}" for i in range(n)], "genre": [f"g{i % 9}" for i in range(n)],
        "energy": rng.random(n), "positivity": rng.random(n), "tags": rng.integers(1, 30, n)})


class Trial3Tests(unittest.TestCase):
    def test_reference_songs_cover_the_grid(self):
        songs = synthetic_songs()
        anchors = A.select_anchors(songs)
        pd.testing.assert_frame_equal(anchors, A.select_anchors(songs))      # seeded
        self.assertEqual(len(anchors), 48)
        self.assertTrue((anchors["tags"] >= A.MIN_TAGS).all())
        self.assertEqual(anchors["artists"].nunique(), 48)
        self.assertTrue((anchors.groupby(["cell_e", "cell_p"])["genre"].nunique() == 3).all())
        self.assertTrue(anchors["energy"].is_monotonic_increasing)
        first = A.anchor_block(anchors).splitlines()[0].split("\t")
        self.assertEqual(first[2:], [str(round(anchors.energy[0] * 100)), str(round(anchors.positivity[0] * 100))])

    def test_dev_and_test_never_see_reference_or_earlier_songs(self):
        songs = synthetic_songs()
        anchors = A.select_anchors(songs)
        earlier = [songs.sample(300, random_state=seed) for seed in (0, 1)]
        dev, test = L.trial3_samples(songs, anchors, earlier)
        self.assertEqual((len(dev), len(test)), (1000, 2000))
        used = set(anchors.match_key) | set(earlier[0].match_key) | set(earlier[1].match_key)
        self.assertFalse(used & (set(dev.match_key) | set(test.match_key)))
        self.assertFalse(set(dev.match_key) & set(test.match_key))
        pd.testing.assert_frame_equal(dev, L.trial3_samples(songs, anchors, earlier)[0])   # seeded

    @unittest.skipUnless((MUSE / "muse_v3.csv").exists(), "MuSe data not on this machine")
    def test_prompt_holds_the_reference_songs_of_the_script(self):
        anchors = A.select_anchors(A.muse_with_tags(MUSE / "muse.sqlite", MUSE / "muse_v3.csv"))
        self.assertIn("\n" + A.anchor_block(anchors) + "\n", L.load_prompt())


if __name__ == "__main__":
    unittest.main()
