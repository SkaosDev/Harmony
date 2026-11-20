"""Core ML conversion of the final state model (TODO 2.16), called by `export.py --coreml`.

The whole sklearn Pipeline (median imputation, standardization, logistic regression) becomes
one StateModel.mlmodel: 13 double inputs in `features.FEATURES` order (NaN = unknown), output
P(arousal_high = 1). Needs macOS (to run the check) and coremltools 8.x.
"""
import copy
import warnings
from pathlib import Path

import coremltools as ct
import numpy as np
import pandas as pd
from coremltools.converters import sklearn as ct_sklearn

from export import COREML_TOLERANCE

CHECK_ROWS = 100


def convert(saved):
    model = copy.deepcopy(saved["model"])
    # coremltools only knows "ovr"; for two classes it is the same logistic regression.
    model.named_steps["logisticregression"].multi_class = "ovr"
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return ct_sklearn.convert(model, input_features=list(saved["features"]),
                                  output_feature_names=saved["label"])


def max_gap(mlmodel, saved, rows):
    """Largest |Core ML - scikit-learn| probability gap over `rows` (DataFrame of features)."""
    columns = list(saved["features"])
    expected = saved["model"].predict_proba(rows[columns].to_numpy(dtype=float))[:, 1]
    gaps = []
    for (_, row), want in zip(rows[columns].iterrows(), expected):
        out = mlmodel.predict({c: float(row[c]) for c in columns})
        gaps.append(abs(out["classProbability"][1] - want))
    return max(gaps)


def check_rows(saved, features_folder):
    """100 rows of the local tables (D-1 first rows), NaN kept; only the gap is printed."""
    table = pd.read_csv(Path(features_folder) / "v1_D1.csv")
    nan_rows = table[table[list(saved["features"])].isna().any(axis=1)].head(CHECK_ROWS // 2)
    full_rows = table.dropna(subset=list(saved["features"])).head(CHECK_ROWS - len(nan_rows))
    return pd.concat([nan_rows, full_rows])


def convert_and_check(saved, path, features_folder="data/features"):
    mlmodel = convert(saved)
    mlmodel.save(str(path))
    loaded = ct.models.MLModel(str(path), compute_units=ct.ComputeUnit.CPU_ONLY)
    rows = check_rows(saved, features_folder)
    gap = max_gap(loaded, saved, rows)
    print(f"{Path(path).name}: {len(rows)} rows, max gap vs scikit-learn {gap:.2e}")
    if gap >= COREML_TOLERANCE:
        raise SystemExit(f"Core ML gap {gap:.2e} >= {COREML_TOLERANCE}")
