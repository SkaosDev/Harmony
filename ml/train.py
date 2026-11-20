"""Train and evaluate the state model on the v1 tables (TODO 2.8).

Usage:
    python ml/train.py --features data/features [--test-d3]
    python ml/train.py --features data/features --final data/models/state_model.joblib

Reads the local tables of ml/build_features.py (data/features/v1_D1.csv ...; data/ is ignored
by Git) and prints aggregates only. The model is the one of docs/PROJECT.md §6.3: median
imputation, standardization and logistic regression in one sklearn Pipeline, so every fold
fits them on its training participants only. Label: arousal_high (§6.2).

Cross-validation: 5 folds grouped by participant (wave + pcode) on D-1 + D-2; whole
participants are kept apart, never a random split. Every variant uses the same folds,
next to the "time only" baseline (TODO 2.9).

--test-d3: single test on the held-out wave D-3 (TODO 2.11). Each variant is fitted once on all
of D-1 + D-2 with the same fixed model (no setting is chosen on D-3) and scored on D-3.

--final PATH: fits the chosen variant (FINAL, team decision TODO 2.13) on D-1 + D-2 + D-3 and
saves the Pipeline (TODO 2.14). Keep PATH inside data/ (ignored by Git): the coefficients are
not published until the EmoPhone authors agree (TODO 2.14b).
"""
import argparse
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import balanced_accuracy_score, roc_auc_score
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from features import FEATURES

LABEL = "arousal_high"
CV_WAVES = ("D1", "D2")
TEST_WAVE = "D3"
N_FOLDS = 5
# Model inputs compared, all taken from FEATURES in its fixed order.
VARIANTS = {
    "time only": FEATURES[:3],                     # hour_sin, hour_cos, weekend
    "time + HR": FEATURES[:7],                     # ... z_hr_15/30/60, zb_hr_30
    "time + HR + steps + sleep": FEATURES,
}
FINAL = "time + HR + steps + sleep"                # TODO 2.13, PROJECT.md section 3

# Newer SciPy warns about an lbfgs option sklearn 1.5.2 still passes; results are unchanged.
warnings.filterwarnings("ignore", message="Unknown solver options: iprint")


def make_model():
    """§6.3: median imputation + standardization + logistic regression, fitted together."""
    return make_pipeline(SimpleImputer(strategy="median"), StandardScaler(),
                         LogisticRegression(max_iter=1000))


def scores(y, p):
    """AUROC and balanced accuracy (threshold 0.5) of probabilities p."""
    return roc_auc_score(y, p), balanced_accuracy_score(y, p > 0.5)


def folds(participant):
    """5 folds of whole participants: (train index, test index) pairs."""
    participant = np.asarray(participant)
    return list(GroupKFold(n_splits=N_FOLDS).split(participant, groups=participant))


def cross_validate(table, columns, splits):
    """AUROC and balanced accuracy of each fold, model fitted on the other folds only."""
    x, y = table[list(columns)].to_numpy(dtype=float), table[LABEL].to_numpy()
    out = []
    for train, test in splits:
        model = make_model().fit(x[train], y[train])
        out.append(scores(y[test], model.predict_proba(x[test])[:, 1]))
    return np.array(out)


def holdout(train, test, columns):
    """Fit on all of `train`, score once on `test` (held-out wave)."""
    columns = list(columns)
    model = make_model().fit(train[columns].to_numpy(dtype=float), train[LABEL].to_numpy())
    return scores(test[LABEL].to_numpy(),
                  model.predict_proba(test[columns].to_numpy(dtype=float))[:, 1])


def load(folder, waves):
    return pd.concat([pd.read_csv(folder / f"v1_{w}.csv") for w in waves], ignore_index=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", type=Path, required=True, help="folder of v1_D1.csv ...")
    ap.add_argument("--test-d3", action="store_true", help="single test on the held-out D-3")
    ap.add_argument("--final", type=Path, help="fit FINAL on all waves, save it here (in data/)")
    args = ap.parse_args()
    if args.final:
        table = load(args.features, (*CV_WAVES, TEST_WAVE))
        columns = list(VARIANTS[FINAL])
        model = make_model().fit(table[columns].to_numpy(dtype=float), table[LABEL].to_numpy())
        args.final.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump({"features": columns, "label": LABEL, "model": model}, args.final)
        print(f"Final model ({FINAL}, {len(columns)} features) fitted on {len(table)} answers, "
              f"{table.participant.nunique()} participants -> {args.final} "
              f"({args.final.stat().st_size} bytes)")
        return
    cv = load(args.features, CV_WAVES)
    splits = folds(cv.participant)
    print(f"Cross-validation on {' + '.join(CV_WAVES)}: {len(cv)} answers, "
          f"{cv.participant.nunique()} participants, {N_FOLDS} folds by participant")
    for name, columns in VARIANTS.items():
        r = cross_validate(cv, columns, splits)                     # same folds for all
        print(f"  {name:<26} AUROC {r[:, 0].mean():.3f} +/- {r[:, 0].std():.3f}, "
              f"balanced accuracy {r[:, 1].mean():.3f} +/- {r[:, 1].std():.3f}")
    if args.test_d3:
        test = load(args.features, (TEST_WAVE,))
        assert not set(test.participant) & set(cv.participant)
        print(f"Single test on {TEST_WAVE} (held out): {len(test)} answers, "
              f"{test.participant.nunique()} participants, fitted on {' + '.join(CV_WAVES)}")
        for name, columns in VARIANTS.items():
            auc, bal = holdout(cv, test, columns)
            print(f"  {name:<26} AUROC {auc:.3f}, balanced accuracy {bal:.3f}")


if __name__ == "__main__":
    main()
