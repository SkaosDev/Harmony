"""Export to the app (TODO 2.15). Synthetic data only: no EmoPhone data here."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))      # test_train, when run as ml.tests.*
import export as E                                               # noqa: E402
import train as T                                                # noqa: E402
from test_train import synthetic_table                           # noqa: E402


def saved_model():
    table = synthetic_table()
    x = table[list(T.FEATURES)].to_numpy(dtype=float)
    return T.fit_final(table), x


class ParamsTests(unittest.TestCase):
    def test_predict_matches_sklearn(self):
        saved, x = saved_model()
        params = E.build_params(saved)
        expected = saved["model"].predict_proba(x)[:, 1]
        got = np.array([E.predict(params, row) for row in x])
        self.assertLess(np.abs(got - expected).max(), 1e-9)   # NaN rows included (imputed)

    def test_time_only_block_predicts_like_sklearn(self):
        saved, x = saved_model()
        block = E.build_params(saved)["time_only"]
        self.assertEqual(block["features"], ["hour_sin", "hour_cos", "weekend"])
        expected = saved["time_only"].predict_proba(x[:, :3])[:, 1]
        got = np.array([E.predict(block, row[:3]) for row in x])
        self.assertLess(np.abs(got - expected).max(), 1e-9)

    def test_json_is_small_and_ordered(self):
        saved, _ = saved_model()
        params = E.build_params(saved)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "model_params.json"
            size = E.write_params(params, path)
            self.assertLess(size, 5 * 1024)
            back = json.loads(path.read_text())
        self.assertEqual(back["version"], 2)
        self.assertEqual(back["features"], list(T.FEATURES))
        for key in ("medians", "means", "scales", "coefficients"):
            self.assertEqual(len(back[key]), len(T.FEATURES))
            self.assertEqual(len(back["time_only"][key]), 3)

    def test_wrong_feature_order_is_refused(self):
        saved, _ = saved_model()
        saved["features"] = saved["features"][::-1]
        with self.assertRaises(ValueError):
            E.build_params(saved)


try:
    import coremltools                                           # noqa: F401
    HAS_COREML = sys.platform == "darwin"                        # predict() only runs on macOS
except ImportError:
    HAS_COREML = False


@unittest.skipUnless(HAS_COREML, "needs macOS and coremltools")
class CoreMLTests(unittest.TestCase):
    def test_core_ml_matches_sklearn(self):
        import export_coreml as C
        import pandas as pd
        saved, x = saved_model()
        rows = pd.DataFrame(x[:100], columns=list(T.FEATURES))
        gap = C.max_gap(C.convert(saved), saved, rows)           # NaN rows included
        self.assertLess(gap, 1e-6)


if __name__ == "__main__":
    unittest.main()
