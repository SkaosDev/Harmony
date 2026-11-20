"""Export the final state model to the app (TODO 2.15, 2.16).

Usage:
    python ml/export.py --model data/models/state_model.joblib
    python ml/export.py --model data/models/state_model.joblib --coreml

Writes app/Harmony/Resources/model_params.json: feature order, imputation medians,
standardization means / scales, logistic coefficients and intercept (docs/PROJECT.md §6.7).
The Swift app reads this file; `predict` below is the reference it must match.
--coreml also writes StateModel.mlmodel and checks it against scikit-learn on 100 rows.
Publishing the coefficients is allowed by the EmoPhone authors (TODO 2.14b).
"""
import argparse
import json
from pathlib import Path

import joblib
import numpy as np

from features import FEATURES

VERSION = 1
APP_RESOURCES = Path(__file__).resolve().parents[1] / "app" / "Harmony" / "Resources"
MAX_BYTES = 5 * 1024
COREML_TOLERANCE = 1e-6


def build_params(saved):
    """model_params dict from the joblib saved by `train.py --final`."""
    columns = list(saved["features"])
    if columns != list(FEATURES):
        raise ValueError("the saved model does not use the 13 features of features.FEATURES")
    imputer, scaler, logistic = (saved["model"].named_steps[k] for k in
                                 ("simpleimputer", "standardscaler", "logisticregression"))
    return {
        "version": VERSION,
        "label": saved["label"],
        "features": columns,
        "medians": imputer.statistics_.tolist(),
        "means": scaler.mean_.tolist(),
        "scales": scaler.scale_.tolist(),
        "coefficients": logistic.coef_[0].tolist(),
        "intercept": float(logistic.intercept_[0]),
    }


def predict(params, row):
    """P(arousal_high) of one row (13 values in `features` order, NaN = unknown)."""
    x = np.asarray(row, dtype=float)
    x = np.where(np.isnan(x), params["medians"], x)
    z = (x - params["means"]) / params["scales"]
    return float(1 / (1 + np.exp(-(z @ params["coefficients"] + params["intercept"]))))


def write_params(params, path):
    text = json.dumps(params, indent=2) + "\n"
    if len(text.encode()) >= MAX_BYTES:
        raise ValueError(f"model_params.json would be {len(text.encode())} bytes (limit {MAX_BYTES})")
    Path(path).write_text(text)
    return len(text.encode())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, required=True, help="joblib of train.py --final")
    ap.add_argument("--out", type=Path, default=APP_RESOURCES, help="folder of the app resources")
    ap.add_argument("--coreml", action="store_true", help="also write StateModel.mlmodel")
    args = ap.parse_args()
    saved = joblib.load(args.model)   # our own file from train.py --final: never load an unknown joblib
    params = build_params(saved)
    args.out.mkdir(parents=True, exist_ok=True)
    size = write_params(params, args.out / "model_params.json")
    print(f"model_params.json: {size} bytes, {len(params['features'])} features")
    if args.coreml:
        from export_coreml import convert_and_check
        convert_and_check(saved, args.out / "StateModel.mlmodel")


if __name__ == "__main__":
    main()
