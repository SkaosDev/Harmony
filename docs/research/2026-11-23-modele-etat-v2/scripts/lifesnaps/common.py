"""Shared helpers: paths, Harmony's features.py (read-only import), model, folds, label mapping."""
import sys

sys.dont_write_bytecode = True  # never write __pycache__ (in particular inside the repo)
from pathlib import Path  # noqa: E402

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.impute import SimpleImputer  # noqa: E402
from sklearn.linear_model import LogisticRegression  # noqa: E402
from sklearn.metrics import balanced_accuracy_score, roc_auc_score  # noqa: E402
from sklearn.model_selection import GroupKFold  # noqa: E402
from sklearn.pipeline import make_pipeline  # noqa: E402
from sklearn.preprocessing import StandardScaler  # noqa: E402

SCRATCH = Path("/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/"
               "c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad")
ZIP = SCRATCH / "ext/lifesnaps/rais_anonymized.zip"
DERIVED = SCRATCH / "ext/lifesnaps/derived"      # per-person derived data (never shared)
OUT = SCRATCH / "v2/lifesnaps/out"                # aggregate results only
REPO_ML = Path("/Users/clement/Hanyang/Harmony/ml")
PARAMS = Path("/Users/clement/Hanyang/Harmony/app/Harmony/Resources/model_params.json")
sys.path.insert(0, str(SCRATCH / "v2/lifesnaps/pylib"))
sys.path.append(str(REPO_ML))
import features as F  # noqa: E402  (Harmony's features v1, imported read-only)

N_FOLDS = 5

# Circumplex mapping of the SEMA3 mood categories (Russell 1980; Posner, Russell & Peterson 2005).
# activation: alert and tense/anxious are activated; tired and rested/relaxed deactivated; sad is
# mildly deactivated; happy is near the pleasure axis (slightly activated); neutral is the centre.
AROUSAL = {"ALERT": 1.0, "TENSE/ANXIOUS": 1.0, "HAPPY": 0.5, "NEUTRAL": 0.0,
           "SAD": -0.5, "RESTED/RELAXED": -1.0, "TIRED": -1.0}
# pleasantness: happy and rested/relaxed pleasant; alert mildly pleasant; tired mildly unpleasant.
VALENCE = {"HAPPY": 1.0, "RESTED/RELAXED": 1.0, "ALERT": 0.5, "NEUTRAL": 0.0,
           "TIRED": -0.5, "TENSE/ANXIOUS": -1.0, "SAD": -1.0}
# strict variants: only unambiguous categories (others excluded, not set to 0)
AROUSAL_STRICT = {"ALERT": 1, "TENSE/ANXIOUS": 1, "RESTED/RELAXED": 0, "TIRED": 0}
VALENCE_STRICT = {"HAPPY": 1, "RESTED/RELAXED": 1, "TENSE/ANXIOUS": 0, "SAD": 0}


def make_model():
    """Harmony §6.3: median imputation + standardization + logistic regression."""
    return make_pipeline(SimpleImputer(strategy="median"), StandardScaler(),
                         LogisticRegression(max_iter=1000))


def folds(participant):
    participant = np.asarray(participant)
    return list(GroupKFold(n_splits=N_FOLDS).split(participant, groups=participant))


def scores(y, p):
    return roc_auc_score(y, p), balanced_accuracy_score(y, p > 0.5)


def predict_params(params, x):
    """Same as Harmony ml/export.predict, vectorised (NaN = unknown -> training median)."""
    x = np.asarray(x, dtype=float)
    x = np.where(np.isnan(x), np.asarray(params["medians"]), x)
    z = (x - np.asarray(params["means"])) / np.asarray(params["scales"])
    return 1 / (1 + np.exp(-(z @ np.asarray(params["coefficients"]) + params["intercept"])))


def local_naive_to_ms(dt):
    """LifeSnaps times are local wall-clock times. features.py adds Korea's +9 h to UTC ms, so we
    pass (local wall clock as if UTC) - 9 h: features.local_minute() then gives the local time."""
    dt = pd.to_datetime(pd.Series(dt))
    return (dt.astype("datetime64[ms]").astype("int64").to_numpy() - F.KST_MS)
