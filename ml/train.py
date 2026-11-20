"""Train and evaluate the state model on the v1 tables (TODO 2.8).

Usage:
    python ml/train.py --features data/features

Reads the local tables of ml/build_features.py (data/features/v1_D1.csv ...; data/ is ignored
by Git) and prints aggregates only. The model is the one of docs/PROJECT.md §6.3: median
imputation, standardization and logistic regression in one sklearn Pipeline, so every fold
fits them on its training participants only. Label: arousal_high (§6.2).

Cross-validation: 5 folds grouped by participant (wave + pcode) on D-1 + D-2; whole
participants are kept apart, never a random split. Every variant uses the same folds,
next to the "time only" baseline (TODO 2.9).
"""
import argparse
import warnings
from pathlib import Path

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
N_FOLDS = 5
# Model inputs compared, all taken from FEATURES in its fixed order.
VARIANTS = {
    "time only": FEATURES[:3],                     # hour_sin, hour_cos, weekend
    "time + HR": FEATURES[:7],                     # ... z_hr_15/30/60, zb_hr_30
    "time + HR + steps + sleep": FEATURES,
}

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


def load(folder, waves):
    return pd.concat([pd.read_csv(folder / f"v1_{w}.csv") for w in waves], ignore_index=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--features", type=Path, required=True, help="folder of v1_D1.csv ...")
    args = ap.parse_args()
    cv = load(args.features, CV_WAVES)
    splits = folds(cv.participant)
    print(f"Cross-validation on {' + '.join(CV_WAVES)}: {len(cv)} answers, "
          f"{cv.participant.nunique()} participants, {N_FOLDS} folds by participant")
    for name, columns in VARIANTS.items():
        r = cross_validate(cv, columns, splits)                     # same folds for all
        print(f"  {name:<26} AUROC {r[:, 0].mean():.3f} +/- {r[:, 0].std():.3f}, "
              f"balanced accuracy {r[:, 1].mean():.3f} +/- {r[:, 1].std():.3f}")


if __name__ == "__main__":
    main()
