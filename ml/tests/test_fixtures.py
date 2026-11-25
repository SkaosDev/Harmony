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
V3 = PARAMS["version"] == 3                                      # 17 features + valence (TODO 6.4)


class FixtureTests(unittest.TestCase):
    def test_ten_cases_in_feature_order(self):
        self.assertEqual(len(DATA["cases"]), 10)
        self.assertEqual(DATA["features"], list(F.FEATURES_V2 if V3 else F.FEATURES))
        self.assertEqual(DATA["features"], PARAMS["features"])
        self.assertEqual(DATA["model_version"], PARAMS["version"])
        for case in DATA["cases"]:
            self.assertEqual(list(case["features"]), DATA["features"])

    def test_probability_matches_the_shipped_model(self):
        for case in DATA["cases"]:
            row = [np.nan if v is None else v for v in case["features"].values()]
            self.assertAlmostEqual(case["probability"], E.predict(PARAMS, row), delta=1e-12)

    def test_time_only_probability_matches_the_shipped_model(self):
        time_only = PARAMS["time_only"]
        for case in DATA["cases"]:
            row = [case["features"][name] for name in time_only["features"]]   # never unknown
            self.assertAlmostEqual(case["time_only_probability"], E.predict(time_only, row),
                                   delta=1e-12)

    @unittest.skipUnless(V3, "valence blocks only in the v3 model")
    def test_valence_probabilities_match_the_shipped_model(self):
        for case in DATA["cases"]:
            row = [np.nan if v is None else v for v in case["features"].values()]
            self.assertAlmostEqual(case["valence_probability"], E.predict(PARAMS["valence"], row),
                                   delta=1e-12)
            self.assertAlmostEqual(case["valence_time_only_probability"],
                                   E.predict(PARAMS["valence_time_only"], row[:3]), delta=1e-12)

    def test_features_recomputed_from_the_stored_series(self):
        for case in DATA["cases"]:
            origin = case["origin_ms"]
            hr = np.array(case["hr"], dtype=np.int64)
            st = np.array(case["steps"], dtype=np.int64)
            feats = F.participant_features(
                np.array([origin + case["answer_minute"] * F.MIN_MS]),
                origin + hr[:, 0] * F.MIN_MS, hr[:, 1],
                origin + st[:, 0] * F.MIN_MS, st[:, 1], case["sleep_threshold"], raw_windows=V3)
            for name in DATA["features"]:
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
        if V3:  # v3 body mode needs raw_hr_30 only: these two cases have a heart rate
            self.assertIsNotNone(by_name["short_history"]["features"]["raw_hr_30"])
            self.assertIsNotNone(by_name["constant_heart_rate"]["features"]["raw_hr_30"])
            self.assertIsNone(by_name["watch_off_last_hour"]["features"]["raw_hr_30"])

    def test_regenerating_gives_the_same_file(self):
        rng = np.random.default_rng(M.SEED)
        again = [M.build_case(*c, rng, PARAMS) for c in M.cases()]
        again = json.loads(json.dumps(again))
        for actual, expected in zip(again, DATA["cases"]):
            self.assertEqual(actual.keys(), expected.keys())
            self.assertEqual(actual["name"], expected["name"])
            for key in actual.keys() - {"features", "probability", "name"}:
                if isinstance(expected[key], float):
                    self.assertAlmostEqual(actual[key], expected[key], delta=1e-14,
                                           msg=(expected["name"], key))
                else:
                    self.assertEqual(actual[key], expected[key], (expected["name"], key))
            self.assertEqual(actual["features"].keys(), expected["features"].keys())
            for name in DATA["features"]:
                want, got = expected["features"][name], actual["features"][name]
                if want is None:
                    self.assertIsNone(got, (expected["name"], name))
                else:
                    self.assertAlmostEqual(got, want, delta=1e-14,
                                           msg=(expected["name"], name))
            self.assertAlmostEqual(actual["probability"], expected["probability"],
                                   delta=1e-14, msg=expected["name"])


if __name__ == "__main__":
    unittest.main()
