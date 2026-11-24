"""Synthetic checks for WP-B0 and the v2 feature contract."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import features as F
from export import MAX_BYTES, build_params, predict, write_params
from personal_layer import Observation, estimate, past_label
from simulate_wp_b0 import chronological, rank, rank_rows
import evaluate_v2
from evaluate_v2 import TIME, decision, fit, mixed_logits


class WPB0Tests(unittest.TestCase):
    def test_rank_handles_numeric_strings_from_sensor_csv(self):
        t = 21 * F.DAY_MS
        hr = pd.DataFrame({"timestamp": [t - 5 * F.MIN_MS], "value": ["60"]})
        steps = pd.DataFrame({"timestamp": [t - 3 * F.MIN_MS], "value": ["25"]})
        person = pd.DataFrame({"participant": ["D1_synthetic"], "t": [t],
                               "energy_z": [0.], "time_z": [0.]})
        with patch("simulate_wp_b0.read_participant", return_value=(hr, steps)):
            self.assertEqual(list(rank_rows(person, Path("unused"), (None, None), F.FEATURES)),
                             [(0.5, 0.5)])

    def test_v3_staging_schema_and_valence_probability(self):
        rng = np.random.default_rng(2)
        table = pd.DataFrame(rng.normal(size=(64, 17)), columns=F.FEATURES_V2)
        table["arousal_high"] = (table["hour_sin"] > 0).astype(int)
        table["valence_high"] = (table["raw_hr_30"] > 0).astype(int)
        table.loc[0, "raw_hr_30"] = np.nan
        valence = fit(table, F.FEATURES_V2, "valence")
        valence_time = fit(table, TIME, "valence")
        params = build_params({"features": list(F.FEATURES_V2), "label": "arousal_high",
                               "model": fit(table, F.FEATURES_V2, "arousal"),
                               "time_only_features": list(TIME), "time_only": fit(table, TIME, "arousal"),
                               "valence": valence, "valence_time_only": valence_time})
        self.assertEqual(params["version"], 3)
        self.assertEqual(params["features"], list(F.FEATURES_V2))
        self.assertEqual(params["valence_time_only"]["features"], list(TIME))
        row = table.loc[[0], list(F.FEATURES_V2)].to_numpy()
        self.assertAlmostEqual(predict(params["valence"], row[0]),
                               valence.predict_proba(row)[0, 1], places=12)
        self.assertAlmostEqual(predict(params["valence_time_only"], row[0, :3]),
                               valence_time.predict_proba(row[:, :3])[0, 1], places=12)
        with tempfile.TemporaryDirectory() as folder:   # the v3 file stays under the size limit
            self.assertLess(write_params(params, Path(folder) / "model_params.json"), MAX_BYTES)

    def test_v2_uses_raw_hr_even_without_baseline(self):
        class Constant:
            def __init__(self, value):
                self.value = value

            def decision_function(self, inputs):
                return np.full(len(inputs), self.value)

        table = pd.DataFrame({name: [np.nan, np.nan] for name in F.FEATURES_V2})
        table["raw_hr_30"] = [70., np.nan]
        for name in TIME:
            table[name] = 0.
        np.testing.assert_array_equal(mixed_logits(Constant(1), Constant(-1), table, F.FEATURES_V2), [1, -1])
        np.testing.assert_array_equal(mixed_logits(Constant(1), Constant(-1), table, list(F.FEATURES_V2)),
                                      [1, -1])                    # a list selects the v2 gate too
        np.testing.assert_array_equal(mixed_logits(Constant(1), Constant(-1), table, F.FEATURES), [-1, -1])

    def test_failed_d3_run_leaves_no_proof_file(self):
        rng = np.random.default_rng(3)
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            for wave in ("D1", "D2"):
                table = pd.DataFrame(rng.normal(size=(60, 17)), columns=F.FEATURES_V2)
                table["participant"] = [f"{wave}_P{i % 6}" for i in range(60)]
                table["arousal_high"] = rng.integers(0, 2, 60)
                table["valence_high"] = rng.integers(0, 2, 60)
                table.to_csv(folder / f"v2_{wave}.csv", index=False)
            proof = folder / "results" / "wp-a1.json"
            proof.parent.mkdir()
            argv = ["evaluate_v2.py", "--features", str(folder), "--confirm-d3", str(proof)]
            with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(FileNotFoundError):          # v2_D3.csv not built yet
                    evaluate_v2.main()
            self.assertFalse(proof.exists())

    def test_adoption_requires_both_cv_and_holdout(self):
        cv = {"arousal_v1_app": (.56, .5), "arousal_v2_app": (.559, .5),
              "valence_v2_app": (.56, .5), "valence_time": (.54, .5)}
        holdout = {**cv, "arousal_v2_app": (.572, .5), "arousal_time": (.54, .5)}
        self.assertEqual(decision([cv] * 5, holdout), {"energy_v2": True, "valence_model": True})
        holdout["arousal_v2_app"] = (.559, .5)
        holdout["valence_v2_app"] = (.545, .5)
        self.assertEqual(decision([cv] * 5, holdout), {"energy_v2": False, "valence_model": False})

    def test_scalar_and_simulator_agree_including_simultaneous_answers(self):
        days = [0, 1, 2, 3, 4, 5, 5, 6, 19, 20]
        answers = np.array([-2, 0, 2, 0, -2, 2, -2, 0, 0, 2])
        logits = np.linspace(-.5, .5, len(days))
        labels, adjusted, counts = chronological(np.array(days) * F.DAY_MS, answers, logits, 1., 2.)
        origin = datetime(2026, 1, 1, tzinfo=timezone.utc)
        past = []
        for day, answer, z, label, after, count in zip(days, answers, logits, labels, adjusted, counts):
            now = origin + timedelta(days=day)
            expected = past_label(now, int(answer), past)
            self.assertEqual(None if np.isnan(label) else bool(label), expected)
            offset, _, eligible = estimate(now, z, past)
            self.assertAlmostEqual(after, z + offset, places=10)
            self.assertEqual(eligible, count)
            past.append(Observation(now, int(answer), z, expected))

    def test_rank_threshold_and_ties(self):
        fixture = Path(__file__).resolve().parents[1] / "fixtures" / "rank_cases.json"
        for case in json.loads(fixture.read_text(encoding="utf-8"))["cases"]:
            grid = np.array([p for p, count in case["grid"] for _ in range(count)])
            self.assertEqual(rank(case["probability"], grid), case["expected"], case["name"])

    def test_grid_points_share_the_reference_at_prediction_time(self):
        minute = F.MIN_MS
        t = 21 * F.DAY_MS
        times = t - np.arange(7, 0, -1) * F.DAY_MS + 8 * 60 * minute - F.KST_MS
        values = np.arange(60., 67.)
        grid = {name: values for name in F.QUANTITIES}
        result = F.rank_reference(t, times, grid, {}, columns=F.FEATURES_V2)
        np.testing.assert_allclose(result["z_hr_30"], (values - values.mean()) / values.std(ddof=1))
        np.testing.assert_array_equal(result["raw_hr_30"], values)

    def test_raw_windows_keep_feature_prefix_and_distinguish_unknown_from_zero(self):
        t = np.array([12 * 60 * F.MIN_MS, 14 * 60 * F.MIN_MS])
        ht = np.array([t[0] - 30 * F.MIN_MS, t[0] - 5 * F.MIN_MS])
        empty = np.array([], dtype=np.int64)
        values = F.participant_features(t, ht, [80., 60.], empty, [], np.nan, raw_windows=True)
        self.assertEqual(tuple(values), F.FEATURES_V2)
        self.assertEqual(len(values), 17)
        np.testing.assert_array_equal(values["raw_hr_30"], [60., np.nan])
        np.testing.assert_array_equal(values["raw_hr_60"], [70., np.nan])
        np.testing.assert_array_equal(values["raw_log_steps_30"], [0., np.nan])
