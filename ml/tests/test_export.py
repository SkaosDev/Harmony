"""Export to the app (TODO 2.15). Synthetic data only: no EmoPhone data here."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import export as E                                               # noqa: E402
import train as T                                                # noqa: E402
from test_train import synthetic_table                           # noqa: E402


def saved_model():
    table = synthetic_table()
    x = table[list(T.FEATURES)].to_numpy(dtype=float)
    model = T.make_model().fit(x, table[T.LABEL])
    return {"features": list(T.FEATURES), "label": T.LABEL, "model": model}, x


class ParamsTests(unittest.TestCase):
    def test_predict_matches_sklearn(self):
        saved, x = saved_model()
        params = E.build_params(saved)
        expected = saved["model"].predict_proba(x)[:, 1]
        got = np.array([E.predict(params, row) for row in x])
        self.assertLess(np.abs(got - expected).max(), 1e-9)   # NaN rows included (imputed)

    def test_json_is_small_and_ordered(self):
        saved, _ = saved_model()
        params = E.build_params(saved)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "model_params.json"
            size = E.write_params(params, path)
            self.assertLess(size, 5 * 1024)
            back = json.loads(path.read_text())
        self.assertEqual(back["features"], list(T.FEATURES))
        for key in ("medians", "means", "scales", "coefficients"):
            self.assertEqual(len(back[key]), len(T.FEATURES))

    def test_wrong_feature_order_is_refused(self):
        saved, _ = saved_model()
        saved["features"] = saved["features"][::-1]
        with self.assertRaises(ValueError):
            E.build_params(saved)


if __name__ == "__main__":
    unittest.main()
