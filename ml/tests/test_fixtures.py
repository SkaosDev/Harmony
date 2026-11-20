"""Golden fixtures (TODO 2.17): synthetic, reproducible, consistent with the exported model."""

import json
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import export as E                                               # noqa: E402
import features as F                                             # noqa: E402
import make_fixtures as M                                        # noqa: E402

DATA = json.loads(M.OUT.read_text())
PARAMS = json.loads(M.PARAMS.read_text())


class FixtureTests(unittest.TestCase):
    def test_ten_cases_in_feature_order(self):
        self.assertEqual(len(DATA["cases"]), 10)
        self.assertEqual(DATA["features"], list(F.FEATURES))
        self.assertEqual(DATA["model_version"], PARAMS["version"])
        for case in DATA["cases"]:
            self.assertEqual(list(case["features"]), list(F.FEATURES))

    def test_probability_matches_the_shipped_model(self):
        for case in DATA["cases"]:
            row = [np.nan if v is None else v for v in case["features"].values()]
            self.assertAlmostEqual(case["probability"], E.predict(PARAMS, row), delta=1e-12)

    def test_features_recomputed_from_the_stored_series(self):
        for case in DATA["cases"]:
            origin = case["origin_ms"]
            hr = np.array(case["hr"], dtype=np.int64)
            st = np.array(case["steps"], dtype=np.int64)
            feats = F.participant_features(
                np.array([origin + case["answer_minute"] * F.MIN_MS]),
                origin + hr[:, 0] * F.MIN_MS, hr[:, 1],
                origin + st[:, 0] * F.MIN_MS, st[:, 1], case["sleep_threshold"])
            for name in F.FEATURES:
                want = case["features"][name]
                if want is None:
                    self.assertTrue(np.isnan(feats[name][0]), (case["name"], name))
                else:
                    self.assertAlmostEqual(float(feats[name][0]), want, delta=1e-9, msg=(case["name"], name))

    def test_cases_cover_the_unknown_paths(self):
        by_name = {c["name"]: c for c in DATA["cases"]}
        self.assertIsNone(by_name["night_unknown"]["features"]["z_sleep_min"])
        self.assertEqual(by_name["night_unknown"]["features"]["sleep_unknown"], 1)
        self.assertIsNone(by_name["short_history"]["features"]["z_hr_30"])
        self.assertIsNone(by_name["constant_heart_rate"]["features"]["z_hr_30"])
        self.assertEqual(by_name["no_steps_worn"]["features"]["z_log_steps_60"] is None, False)

    def test_regenerating_gives_the_same_file(self):
        rng = np.random.default_rng(M.SEED)
        again = [M.build_case(*c, rng, PARAMS) for c in M.cases()]
        self.assertEqual(json.loads(json.dumps(again)), DATA["cases"])


if __name__ == "__main__":
    unittest.main()
