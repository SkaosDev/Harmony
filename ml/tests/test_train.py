"""Training protocol (TODO 2.8-2.11). Synthetic tables only: no EmoPhone data here."""

import sys
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))   # train.py imports `features`
import train as T                                                # noqa: E402


def synthetic_table(n_participants=23, rows=40, seed=0):
    rng = np.random.default_rng(seed)
    n = n_participants * rows
    table = pd.DataFrame(rng.normal(size=(n, len(T.FEATURES))), columns=list(T.FEATURES))
    table.loc[rng.random(n) < 0.3, "z_hr_30"] = np.nan
    table["participant"] = np.repeat([f"D1_P{i:03d}" for i in range(n_participants)], rows)
    table[T.LABEL] = (table.z_hr_15 + rng.normal(size=n) > 0).astype(int)
    return table


class FoldTests(unittest.TestCase):
    def test_folds_keep_whole_participants_apart(self):
        table = synthetic_table()
        splits = T.folds(table.participant)
        self.assertEqual(len(splits), 5)
        tested = np.concatenate([test for _, test in splits])
        self.assertEqual(sorted(tested), list(range(len(table))))   # every row tested once
        for train, test in splits:
            self.assertFalse(set(table.participant[train]) & set(table.participant[test]))

    def test_imputation_and_scaling_use_training_rows_only(self):
        table = synthetic_table()
        train, test = T.folds(table.participant)[0]
        table.loc[test, "z_hr_30"] = 1e6                # extreme values in the test fold only
        x = table[list(T.FEATURES)].to_numpy(dtype=float)
        model = T.make_model().fit(x[train], table[T.LABEL][train])
        imputer, scaler = model.named_steps["simpleimputer"], model.named_steps["standardscaler"]
        np.testing.assert_allclose(imputer.statistics_, np.nanmedian(x[train], axis=0))
        self.assertLess(scaler.mean_.max(), 10)         # the 1e6 never reached the scaler

    def test_cross_validation_returns_one_score_pair_per_fold(self):
        table = synthetic_table()
        r = T.cross_validate(table, T.FEATURES, T.folds(table.participant))
        self.assertEqual(r.shape, (5, 2))
        self.assertGreater(r[:, 0].mean(), 0.6)         # z_hr_15 carries the synthetic label

    def test_holdout_fits_on_train_only(self):
        table = synthetic_table()
        train, test = table.iloc[:600], table.iloc[600:].copy()
        before = T.holdout(train, test, T.FEATURES)
        test[T.LABEL] = 1 - test[T.LABEL]              # changing the test labels ...
        after = T.holdout(train, test, T.FEATURES)
        self.assertAlmostEqual(after[0], 1 - before[0])  # ... only flips the score, same model


class VariantTests(unittest.TestCase):
    def test_variants_keep_the_feature_order(self):
        self.assertEqual(T.VARIANTS["time only"], ("hour_sin", "hour_cos", "weekend"))
        for columns in T.VARIANTS.values():
            self.assertEqual(columns, T.FEATURES[:len(columns)])


if __name__ == "__main__":
    unittest.main()
