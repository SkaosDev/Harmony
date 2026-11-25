"""Export the final state model to the app (TODO 2.15, 2.16).

Usage:
    python ml/export.py --model data/models/state_v3.joblib
    python ml/export.py --model data/models/state_v3.joblib --coreml

Writes app/Harmony/Resources/model_params.json: feature order, imputation medians,
standardization means / scales, logistic coefficients and intercept (docs/PROJECT.md §6.7), and
the same fields for the "time only" model under `time_only` (TODO 2.21). Version 3 (17 features)
adds `valence` and `valence_time_only` when the valence model is adopted (TODO 6.3).
The Swift app reads this file; `predict` below is the reference it must match.
--coreml also writes StateModel.mlmodel and checks it against scikit-learn on 100 rows.
Publishing the coefficients is allowed by the EmoPhone authors (TODO 2.14b).
"""
import argparse
import json
from pathlib import Path

import joblib
import numpy as np

from features import FEATURES, FEATURES_V2

VERSION = 2                         # 2: adds the "time only" model (same 13-feature model as 1)
APP = Path(__file__).resolve().parents[1] / "app"
APP_RESOURCES = APP / "Harmony" / "Resources"
MAX_BYTES = 8 * 1024                # v2: 2.2 KB (TODO 2.15: < 5 KB); v3 with both valence blocks: ~5.5 KB
COREML_TOLERANCE = 1e-6


def build_params(saved):
    """model_params dict from the joblib saved by `train.py --final`."""
    columns = list(saved["features"])
    if columns not in (list(FEATURES), list(FEATURES_V2)):
        raise ValueError("the saved model does not use a supported feature order")
    if saved["time_only_features"] != columns[:3]:
        raise ValueError("the time only model does not use hour_sin, hour_cos, weekend")
    params = {"version": 3 if columns == list(FEATURES_V2) else VERSION, "label": saved["label"],
              **_logistic(saved["model"], columns),
              "time_only": _logistic(saved["time_only"], saved["time_only_features"])}
    if "valence" in saved:
        if params["version"] != 3:
            raise ValueError("valence requires the v3 contract")
        params["valence"] = _logistic(saved["valence"], columns)
        params["valence_time_only"] = _logistic(saved["valence_time_only"], saved["time_only_features"])
    return params


def _logistic(model, columns):
    """Feature order, medians, means, scales, coefficients and intercept of one Pipeline."""
    imputer, scaler, logistic = (model.named_steps[k] for k in
                                 ("simpleimputer", "standardscaler", "logisticregression"))
    return {
        "features": list(columns),
        "medians": imputer.statistics_.tolist(),
        "means": scaler.mean_.tolist(),
        "scales": scaler.scale_.tolist(),
        "coefficients": logistic.coef_[0].tolist(),
        "intercept": float(logistic.intercept_[0]),
    }


def predict(params, row):
    """P(arousal_high) of one row (values in `features` order, NaN = unknown). Works for the
    13-feature model and for its `time_only` block."""
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
