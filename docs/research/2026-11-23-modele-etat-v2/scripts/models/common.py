"""Shared helpers for the v2 model experiments (D-1 + D-2 only; aggregates only).

Reads data/features/v1_D1.csv and v1_D2.csv (row order as ml/train.py) and joins valence from
each wave's EsmResponse.csv on (participant = wave_pcode, t = actualTriggerTime, arousal, stress).
Nothing is written to disk except aggregate text by the calling scripts.
"""
import os
import sys
import warnings

os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
sys.dont_write_bytecode = True
REPO = "/Users/clement/Hanyang/Harmony"
sys.path.insert(0, f"{REPO}/ml")

import numpy as np
import pandas as pd
from scipy.stats import spearmanr
from sklearn.metrics import balanced_accuracy_score, roc_auc_score

import train  # read-only import: folds(), make_model(), VARIANTS
from features import FEATURES, label_high

warnings.filterwarnings("ignore", message="Unknown solver options: iprint")
warnings.filterwarnings("ignore", category=UserWarning)

TIME = list(FEATURES[:3])
F13 = list(FEATURES)
TARGETS = ("arousal", "valence", "stress")
WAVES = ("D1", "D2")


def load_table():
    """v1_D1 + v1_D2 in ml/train.py order, with valence and valence_high added."""
    parts = []
    for w in WAVES:
        v = pd.read_csv(f"{REPO}/data/features/v1_{w}.csv")
        e = pd.read_csv(f"{REPO}/data/emophone_data/{w}/EsmResponse.csv",
                        usecols=["pcode", "actualTriggerTime", "valence", "arousal", "stress"])
        e = e.rename(columns={"actualTriggerTime": "t"})
        e["participant"] = w + "_" + e.pcode
        keys = ["participant", "t", "arousal", "stress"]
        # duplicates of (participant, t, arousal, stress) have identical features, so pairing
        # them by occurrence order is harmless
        v["_k"] = v.groupby(keys).cumcount()
        e["_k"] = e.groupby(keys).cumcount()
        m = v.merge(e[keys + ["_k", "valence"]], on=keys + ["_k"], how="left", validate="1:1")
        assert len(m) == len(v) and m.valence.notna().all()
        parts.append(m.drop(columns="_k"))
    table = pd.concat(parts, ignore_index=True)
    table["valence_high"] = label_high(table.valence, table.participant)
    # sanity: labels recomputed on the joined table match the stored ones
    assert (label_high(table.arousal, table.participant) == table.arousal_high).all()
    for k in TARGETS:  # person-centred continuous target (same person mean as the label)
        table[f"{k}_c"] = table[k] - table.groupby("participant")[k].transform("mean")
    return table


def splits_of(table):
    return train.folds(table.participant)


def auc(y, p):
    return roc_auc_score(y, p)


def bal(y, p, thr=0.5):
    return balanced_accuracy_score(y, p > thr)


def brier(y, p):
    return float(np.mean((p - y) ** 2))


def ece(y, p, bins=10):
    """Expected calibration error, 10 equal-width bins."""
    idx = np.clip((p * bins).astype(int), 0, bins - 1)
    tot = 0.0
    for b in range(bins):
        m = idx == b
        if m.any():
            tot += m.sum() * abs(p[m].mean() - y[m].mean())
    return tot / len(p)


def pct(p, q=(5, 25, 50, 75, 95)):
    return np.percentile(p, q)


def ms(a):
    a = np.asarray(a, dtype=float)
    return f"{a.mean():.3f} +/- {a.std():.3f}"


def paired(a, b):
    """Fold-wise paired difference a - b: mean +/- sd, and number of folds with a > b."""
    d = np.asarray(a) - np.asarray(b)
    return f"{d.mean():+.3f} +/- {d.std():.3f} ({(d > 0).sum()}/{len(d)} folds >0)"


def spearman(x, y):
    return spearmanr(x, y).correlation


def logit(p, eps=1e-4):
    p = np.clip(p, eps, 1 - eps)
    return np.log(p / (1 - p))
