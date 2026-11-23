"""Simulated in-app check-ins on EmoPhone D-1 + D-2: personalisation learning curves.

Run:  PYTHONDONTWRITEBYTECODE=1 OMP_NUM_THREADS=1 python sim.py --target arousal --label full --rate 2
Reads the repo tables read-only, keeps every row-level value in memory, and writes AGGREGATES
ONLY (curves averaged over participants / folds) to ../out/<config>.json.

Outer loop = the 5 GroupKFold splits of ml/train.py (folds()). Inside each outer training set,
4 inner GroupKFold splits simulate the same procedure to tune every prior std / weight by
log-loss (training participants only). Test participants: check-ins are a chronological
subsample of their ESM answers (`rate` per local day, random moments); every answer is
predicted with check-ins strictly before it (rolling).
"""
import argparse
import json
import sys
import time
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.model_selection import GroupKFold

sys.path.insert(0, "/Users/clement/Hanyang/Harmony/ml")
from features import FEATURES, KST_MS, label_high  # noqa: E402
from train import CV_WAVES, folds, make_model  # noqa: E402

warnings.filterwarnings("ignore")
ROOT = Path("/Users/clement/Hanyang/Harmony/data")
OUT = Path(__file__).resolve().parent.parent / "out"
HOUR = 3_600_000
DAY = 86_400_000

TB = np.array([0.05, 0.1, 0.2, 0.35, 0.5, 0.75, 1.0, 1.5])     # intercept prior std grid
TW = np.array([0.02, 0.05, 0.1, 0.2, 0.35])                     # slope prior std grid
GRID2 = np.array([(b, w) for b in TB for w in TW])
TDAYS = np.array([1, 2, 4, 7, 14, 28, np.inf])                 # m1d forgetting time constants
GRID1D = np.array([(b, d) for b in TB for d in TDAYS])
N0 = np.array([0, 2, 5, 10, 20, 40, 80, 160, np.inf])          # 4b: alpha_n = n / (n + n0)
H_NAMES = ["h_mean", "h_last", "h_recent", "h_ewm", "h_tod", "h_n"]

N_EDGES = [0, 1, 5, 10, 20, 40, 60, 10**9]
N_LABELS = ["0", "1-4", "5-9", "10-19", "20-39", "40-59", "60+"]
D_EDGES = [1, 2, 4, 8, 15, 22, 29, 10**9]
D_LABELS = ["1", "2-3", "4-7", "8-14", "15-21", "22-28", "29+"]
FROZEN_DAY = 21                                                 # design B: evaluate days >= 21
FROZEN_NMAX = {1: 15, 2: 30, 4: 60}
FROZEN_GRID = [0, 5, 10, 15, 20, 30, 40, 60]


# ----------------------------------------------------------------------------- data
def load_table():
    parts, bad = [], 0
    for w in CV_WAVES:
        f = pd.read_csv(ROOT / "features" / f"v1_{w}.csv")
        esm = pd.read_csv(ROOT / "emophone_data" / w / "EsmResponse.csv",
                          usecols=["pcode", "actualTriggerTime", "valence", "arousal", "stress"])
        val = np.full(len(f), np.nan)
        for p, idx in f.groupby("participant", sort=False).indices.items():
            e = esm[esm.pcode == p.split("_", 1)[1]].sort_values("actualTriggerTime")
            assert len(e) == len(idx)
            assert (e.actualTriggerTime.to_numpy() == f.t.to_numpy()[idx]).all()
            bad += int((e.arousal.to_numpy() != f.arousal.to_numpy()[idx]).sum()
                       + (e.stress.to_numpy() != f.stress.to_numpy()[idx]).sum())
            val[idx] = e.valence.to_numpy()
        f["valence"] = val
        parts.append(f)
    return pd.concat(parts, ignore_index=True), bad


def past_label(v, t, window_days=14, min_n=5):
    """1 if v > mean of this person's answers in the previous 14 days (strictly before), NaN if
    fewer than min_n such answers. v, t of ONE person, time-sorted."""
    dt = t[:, None] - t[None, :]
    m = (dt > 0) & (dt <= window_days * DAY)
    n = m.sum(1)
    mean = (m * v[None, :]).sum(1) / np.maximum(n, 1)
    y = (v > mean).astype(float)
    y[n < min_n] = np.nan
    return y


def build_persons(cv, target, label, null=False):
    raw = cv[target].to_numpy(dtype=float)
    if label == "full":
        y_all = label_high(raw, cv.participant).astype(float)
    persons = []
    fold_of = np.empty(len(cv), int)
    for i, (_, te) in enumerate(folds(cv.participant)):
        fold_of[te] = i
    for pid, (p, idx) in enumerate(cv.groupby("participant", sort=False).indices.items()):
        t = cv.t.to_numpy()[idx]
        order = np.argsort(t, kind="stable")
        idx, t = idx[order], t[order]
        y = y_all[idx] if label == "full" else past_label(raw[idx], t)
        lday = (t + KST_MS) // DAY
        dou = lday - lday.min() + 1
        keep = ~np.isnan(y)
        if keep.sum() < 10:
            continue
        idx, t, y, lday, dou = idx[keep], t[keep], y[keep], lday[keep], dou[keep]
        assert len(set(fold_of[idx])) == 1
        Xraw = cv.loc[idx, list(FEATURES)].to_numpy(dtype=float)
        if null:   # null check: (features, label) pairs shuffled across this person's time slots
            perm = np.random.default_rng([99, pid]).permutation(len(y))
            Xraw, y = Xraw[perm], y[perm]
        persons.append(dict(pid=pid, fold=int(fold_of[idx[0]]), t=t, y=y, day=lday, dou=dou,
                            tod=((t + KST_MS) % DAY) / HOUR, Xraw=Xraw))
    return persons


# ----------------------------------------------------------------------------- check-ins
def sample_checkins(day, rate, rng):
    """Random `rate` answers per local day (all of them if fewer); sorted row indices."""
    sel = []
    for d in np.unique(day):
        idx = np.flatnonzero(day == d)
        sel.append(rng.choice(idx, min(rate, len(idx)), replace=False))
    return np.sort(np.concatenate(sel))


def history(t, tod, ci, s, lag_h=0.0):
    """Label-history features at every row from check-ins ci (sorted) with answers s = +-1,
    using only check-ins strictly before the row. No check-in -> neutral 0 (an absent answer
    carries no evidence; every feature is a shrunk / decayed sum, not a missing measurement)."""
    n = len(t)
    H = np.zeros((n, len(H_NAMES)))
    if len(ci) == 0:
        return H
    c, ctod = t[ci], tod[ci]
    dt = (t[:, None] - c[None, :]) / HOUR
    before = dt > lag_h                                         # lag_h > 0: only answers older than lag
    nb = before.sum(1)
    H[:, 0] = (before @ s) / (nb + 2.0)                         # shrunk running mean
    has = nb > 0
    j = np.clip(nb - 1, 0, None)                                # last check-in strictly before
    dl = (t - c[j]) / HOUR
    H[:, 1] = np.where(has, s[j] * np.exp(-dl / 6), 0)          # last answer, 6 h decay
    H[:, 2] = np.where(has, np.exp(-dl / 24), 0)                # recency of last answer
    w = before * np.exp(-np.where(before, dt, 0) / 24)
    H[:, 3] = (w @ s) / (w.sum(1) + 1)                          # exp-weighted mean, 24 h
    d = np.abs(tod[:, None] - ctod[None, :])
    d = np.minimum(d, 24 - d)
    wt = (dt >= 12) * np.exp(-0.5 * (d / 1.5) ** 2)
    H[:, 4] = (wt @ s) / (wt.sum(1) + 1)                        # same clock time, past days
    H[:, 5] = np.log1p(nb)
    return H


# ----------------------------------------------------------------------------- models
def fit_models(persons, rate, seed):
    Xr, Hs, Y = [], [], []
    for P in persons:
        ci = sample_checkins(P["day"], rate, np.random.default_rng([seed, rate, P["pid"]]))
        Hs.append(history(P["t"], P["tod"], ci, 2 * P["y"][ci] - 1))
        Xr.append(P["Xraw"])
        Y.append(P["y"])
    Xr, H, Y = np.vstack(Xr), np.vstack(Hs), np.concatenate(Y)
    return {"pop": make_model().fit(Xr, Y),
            "time": make_model().fit(Xr[:, :3], Y),
            "hist": make_model().fit(np.hstack([Xr, H]), Y),
            "histonly": make_model().fit(H, Y),
            "histtime": make_model().fit(np.hstack([Xr[:, :3], H]), Y)}


def logit(m, X):
    return m.decision_function(X)


def inputs(P, M, ci, n_first=None):
    """Design + logits of every population model for person P given check-ins ci
    (optionally only the first n_first of them)."""
    c = ci if n_first is None else ci[:n_first]
    H = history(P["t"], P["tod"], c, 2 * P["y"][c] - 1)
    Xs = M["pop"][:-1].transform(P["Xraw"])
    nb = np.searchsorted(P["t"][c], P["t"], side="left")
    s_sum = np.r_[0, np.cumsum(P["y"][c])]
    return dict(X=np.hstack([np.ones((len(Xs), 1)), Xs]), nb=nb, H=H,
                zpop=M["pop"][-1].decision_function(Xs),
                ztime=logit(M["time"], P["Xraw"][:, :3]),
                z3=logit(M["hist"], np.hstack([P["Xraw"], H])),
                z5=logit(M["histonly"], H),
                z5t=logit(M["histtime"], np.hstack([P["Xraw"][:, :3], H])),
                zbase=np.log((s_sum[nb] + 1) / (nb - s_sum[nb] + 1)))   # Laplace mean of answers


def map_fit(X, off, y, prec, delta, w=None):
    """MAP of delta (G, d) for logit = off + X @ delta, prior N(0, 1/prec); batched Newton.
    w (G, k): optional likelihood weights (forgetting of old check-ins)."""
    delta = delta.copy()
    w = 1.0 if w is None else w
    for _ in range(30):
        z = off[None, :] + delta @ X.T
        p = 1.0 / (1.0 + np.exp(-z))
        g = ((p - y[None, :]) * w) @ X + prec * delta
        XW = (w * p * (1 - p))[:, :, None] * X[None, :, :]
        H = np.transpose(XW, (0, 2, 1)) @ X
        H[:, np.arange(X.shape[1]), np.arange(X.shape[1])] += prec
        step = np.linalg.solve(H, g[:, :, None])[:, :, 0]
        delta -= step
        if np.abs(step).max() < 1e-6:
            break
    return delta


def rolling(zoff, X, y, ci, nb, prec, t=None, decay_h=None):
    """Rolling MAP: model k (after k check-ins) predicts rows with exactly k check-ins strictly
    before them. Returns logits (G, n) and the stack of fitted deltas (K+1, G, d).
    decay_h (G,): optional forgetting time constant (hours) of the check-in likelihood,
    weights exp(-(c_k - c_i) / decay) relative to the latest check-in c_k."""
    G, d = prec.shape
    D = np.zeros((len(ci) + 1, G, d))
    delta = np.zeros((G, d))
    for k in range(1, len(ci) + 1):
        w = None
        if decay_h is not None:
            age = (t[ci[k - 1]] - t[ci[:k]]) / HOUR
            w = np.exp(-age[None, :] / np.asarray(decay_h, float)[:, None])
        delta = map_fit(X[ci[:k]], zoff[ci[:k]], y[ci[:k]], prec, delta, w)
        D[k] = delta
    return zoff[None, :] + np.einsum("ngd,nd->gn", D[nb], X), D


def prec1(tb):
    return 1.0 / np.asarray(tb, float).reshape(-1, 1) ** 2


def prec2(grid):
    grid = np.atleast_2d(grid)
    return np.hstack([1.0 / grid[:, :1] ** 2, np.repeat(1.0 / grid[:, 1:2] ** 2, 13, axis=1)])


def nll(z, y):
    return np.logaddexp(0, -z * (2 * y - 1))


# ----------------------------------------------------------------------------- tuning
def tune(train, rate, seed):
    pids = np.array([P["pid"] for P in train])
    L1, L2, L4 = np.zeros(len(TB)), np.zeros(len(GRID2)), np.zeros(len(GRID2))
    L1d = np.zeros(len(GRID1D))
    L4c = np.zeros(len(GRID1D))
    keep = []
    for tr, te in GroupKFold(4).split(pids, groups=pids):
        M = fit_models([train[i] for i in tr], rate, seed)
        for i in te:
            P = train[i]
            ci = sample_checkins(P["day"], rate, np.random.default_rng([seed + 1, rate, P["pid"]]))
            I = inputs(P, M, ci)
            m = I["nb"] >= 1
            if not m.any():
                continue
            y = P["y"]
            Z1, _ = rolling(I["zpop"], I["X"][:, :1], y, ci, I["nb"], prec1(TB))
            Z2, _ = rolling(I["zpop"], I["X"], y, ci, I["nb"], prec2(GRID2))
            Z1d, _ = rolling(I["zpop"], I["X"][:, :1], y, ci, I["nb"], prec1(GRID1D[:, 0]),
                             P["t"], GRID1D[:, 1] * 24)
            L1d += nll(Z1d[:, m], y[m]).sum(1)
            Z4c, _ = rolling(I["z3"], I["X"][:, :1], y, ci, I["nb"], prec1(GRID1D[:, 0]),
                             P["t"], GRID1D[:, 1] * 24)
            L4c += nll(Z4c[:, m], y[m]).sum(1)
            Z4, _ = rolling(I["z3"], I["X"], y, ci, I["nb"], prec2(GRID2))
            L1 += nll(Z1[:, m], y[m]).sum(1)
            L2 += nll(Z2[:, m], y[m]).sum(1)
            L4 += nll(Z4[:, m], y[m]).sum(1)
            keep.append((Z2[:, m], I["z3"][m], I["nb"][m], y[m]))
    b2 = int(np.argmin(L2))
    z2 = np.concatenate([k[0][b2] for k in keep])
    z3 = np.concatenate([k[1] for k in keep])
    nb = np.concatenate([k[2] for k in keep])
    y = np.concatenate([k[3] for k in keep])
    L4b = []
    for n0 in N0:
        a = np.zeros_like(z3) if np.isinf(n0) else nb / (nb + n0)
        L4b.append(nll((1 - a) * z3 + a * z2, y).sum())
    nrows = len(y)
    return {"tb1": float(TB[np.argmin(L1)]), "g1d": GRID1D[int(np.argmin(L1d))].tolist(),
            "ll1d": float(L1d.min() / nrows), "g4c": GRID1D[int(np.argmin(L4c))].tolist(),
            "ll4c": float(L4c.min() / nrows), "g2": GRID2[b2].tolist(),
            "g4": GRID2[int(np.argmin(L4))].tolist(), "n0": float(N0[int(np.argmin(L4b))]),
            "ll1": float(L1.min() / nrows), "ll2": float(L2.min() / nrows),
            "ll4": float(L4.min() / nrows), "ll4b": float(min(L4b) / nrows),
            "ll3": float(nll(z3, y).mean())}


# ----------------------------------------------------------------------------- evaluation
METHODS = ["pop", "time", "m1_intercept", "m1d_intercept_decay", "m2_bayes", "m3_hist", "m4a_bayes_on_hist",
           "m4b_logit_avg", "m4c_decay_on_hist", "m5_histonly", "m5t_hist_time", "base_rate"]


def predict_person(P, M, ci, prm, frozen):
    I = inputs(P, M, ci)
    y = P["y"]
    z1, D1 = rolling(I["zpop"], I["X"][:, :1], y, ci, I["nb"], prec1([prm["tb1"]]))
    z2, D2 = rolling(I["zpop"], I["X"], y, ci, I["nb"], prec2(prm["g2"]))
    z1d, D1d = rolling(I["zpop"], I["X"][:, :1], y, ci, I["nb"], prec1([prm["g1d"][0]]),
                       P["t"], [prm["g1d"][1] * 24])
    z4c, D4c = rolling(I["z3"], I["X"][:, :1], y, ci, I["nb"], prec1([prm["g4c"][0]]),
                       P["t"], [prm["g4c"][1] * 24])
    z4, D4 = rolling(I["z3"], I["X"], y, ci, I["nb"], prec2(prm["g4"]))
    nb = I["nb"]
    a = np.zeros(len(nb)) if np.isinf(prm["n0"]) else nb / (nb + prm["n0"]) if prm["n0"] > 0 \
        else (nb > 0).astype(float)
    Z = {"pop": I["zpop"], "time": I["ztime"], "m1_intercept": z1[0], "m1d_intercept_decay": z1d[0], "m2_bayes": z2[0],
         "m3_hist": I["z3"], "m4a_bayes_on_hist": z4[0], "m4c_decay_on_hist": z4c[0],
         "m4b_logit_avg": (1 - a) * I["z3"] + a * z2[0], "m5_histonly": I["z5"],
         "m5t_hist_time": I["z5t"], "base_rate": I["zbase"]}
    roll = pd.DataFrame({k: 1 / (1 + np.exp(-v)) for k, v in Z.items()})
    roll["y"], roll["nb"], roll["dou"], roll["pid"] = y, nb, P["dou"], P["pid"]
    # design B (frozen): first n check-ins only, evaluate rows on days >= FROZEN_DAY
    fr = []
    ev = P["dou"] >= FROZEN_DAY
    pre = ci[P["dou"][ci] < FROZEN_DAY]
    if frozen and ev.sum() >= 10 and len(pre) >= FROZEN_NMAX[prm["rate"]]:
        for n in [g for g in FROZEN_GRID if g <= FROZEN_NMAX[prm["rate"]]]:
            J = inputs(P, M, ci, n_first=n)
            X = J["X"][ev]
            an = 0.0 if np.isinf(prm["n0"]) else (n / (n + prm["n0"]) if prm["n0"] > 0 else float(n > 0))
            z2n = J["zpop"][ev] + X @ D2[n, 0]
            Zf = {"pop": J["zpop"][ev], "time": J["ztime"][ev],
                  "m1_intercept": J["zpop"][ev] + X[:, :1] @ D1[n, 0],
                  "m1d_intercept_decay": J["zpop"][ev] + X[:, :1] @ D1d[n, 0],
                  "m2_bayes": z2n, "m3_hist": J["z3"][ev],
                  "m4a_bayes_on_hist": J["z3"][ev] + X @ D4[n, 0],
                  "m4c_decay_on_hist": J["z3"][ev] + X[:, :1] @ D4c[n, 0],
                  "m4b_logit_avg": (1 - an) * J["z3"][ev] + an * z2n,
                  "m5_histonly": J["z5"][ev], "m5t_hist_time": J["z5t"][ev],
                  "base_rate": J["zbase"][ev]}
            f = pd.DataFrame({k: 1 / (1 + np.exp(-v)) for k, v in Zf.items()})
            f["y"], f["n"], f["pid"] = y[ev], n, P["pid"]
            fr.append(f)
    return roll, fr


# ----------------------------------------------------------------------------- metrics
def wauc(y, s, W):
    """AUROC of scores s for labels y under row weights W (B, n)."""
    o = np.argsort(s, kind="mergesort")
    s, y, W = s[o], y[o], W[:, o]
    starts = np.r_[0, np.flatnonzero(np.diff(s)) + 1]
    Pp = np.add.reduceat(W * y, starts, axis=1)
    Nn = np.add.reduceat(W * (1 - y), starts, axis=1)
    cumN = np.cumsum(Nn, axis=1) - Nn
    return (Pp * (cumN + 0.5 * Nn)).sum(1) / (Pp.sum(1) * Nn.sum(1))


def within_auc(df, col):
    """Mean over seeds of the AUROC of each (person, seed) with >= 10 rows and both classes."""
    keys = ["pid", "seed"] if "seed" in df else ["pid"]
    out = {}
    for key, g in df.groupby(keys):
        y = g.y.to_numpy()
        if len(y) >= 10 and 0 < y.sum() < len(y):
            out[key] = wauc(y, g[col].to_numpy(), np.ones((1, len(y))))[0]
    s = pd.Series(out, dtype=float)
    return s.groupby(level=0).mean() if len(keys) == 2 and len(s) else s


PAIRS = [("m1d_intercept_decay", "m3_hist"), ("m4c_decay_on_hist", "m3_hist"),
         ("m4c_decay_on_hist", "m1d_intercept_decay"), ("m4a_bayes_on_hist", "m3_hist"),
         ("m3_hist", "m5t_hist_time"), ("m2_bayes", "m1_intercept"),
         ("m1d_intercept_decay", "m1_intercept")]


def bucket_metrics(df, methods, rng, B=400):
    y = df.y.to_numpy().astype(float)
    res = {"rows": int(len(df)), "persons": int(df.pid.nunique()), "base_rate": float(y.mean())}
    if len(df) < 30 or y.min() == y.max():
        return res
    pids, gi = np.unique(df.pid.to_numpy(), return_inverse=True)
    W = []
    for _ in range(B // 100):
        cnt = rng.multinomial(len(pids), np.full(len(pids), 1 / len(pids)), size=100)
        W.append(cnt[:, gi].astype(np.float32))
    one = np.ones((1, len(y)))
    ref = df["pop"].to_numpy()
    ref_b = np.concatenate([wauc(y, ref, w) for w in W])
    ref_brier_b = np.concatenate([(w @ (ref - y) ** 2) / w.sum(1) for w in W])
    wp_ref = within_auc(df, "pop")
    boot = {}
    for m in methods:
        s = df[m].to_numpy()
        a_b = np.concatenate([wauc(y, s, w) for w in W])
        br_b = np.concatenate([(w @ (s - y) ** 2) / w.sum(1) for w in W])
        wp = within_auc(df, m)
        dwp = (wp - wp_ref).dropna()
        sd_within = df.groupby("pid")[m].std().mean()
        res[m] = {
            "auc": float(wauc(y, s, one)[0]),
            "d_auc": float(wauc(y, s, one)[0] - wauc(y, ref, one)[0]),
            "d_auc_ci": [float(np.quantile(a_b - ref_b, 0.025)), float(np.quantile(a_b - ref_b, 0.975))],
            "auc_within": float(wp.mean()) if len(wp) else None,
            "n_within": int(len(wp)),
            "d_auc_within": float(dwp.mean()) if len(dwp) else None,
            "d_auc_within_ci": ([float(dwp.mean() - 1.96 * dwp.std(ddof=1) / np.sqrt(len(dwp))),
                                 float(dwp.mean() + 1.96 * dwp.std(ddof=1) / np.sqrt(len(dwp)))]
                                if len(dwp) > 2 else None),
            "bal_acc": float(0.5 * ((s[y == 1] > 0.5).mean() + (s[y == 0] <= 0.5).mean())),
            "brier": float(((s - y) ** 2).mean()),
            "d_brier_ci": [float(np.quantile(br_b - ref_brier_b, 0.025)),
                           float(np.quantile(br_b - ref_brier_b, 0.975))],
            "p10": float(np.quantile(s, 0.1)), "p50": float(np.quantile(s, 0.5)),
            "p90": float(np.quantile(s, 0.9)), "sd": float(s.std()),
            "sd_within": float(sd_within),
        }
        boot[m] = (a_b, br_b, wp)
    res["pairs"] = {}
    for a, b in PAIRS:
        if a in boot and b in boot:
            d = boot[a][0] - boot[b][0]
            dw = (boot[a][2] - boot[b][2]).dropna()
            res["pairs"][f"{a} - {b}"] = {
                "d_auc": res[a]["auc"] - res[b]["auc"],
                "d_auc_ci": [float(np.quantile(d, 0.025)), float(np.quantile(d, 0.975))],
                "d_brier": res[a]["brier"] - res[b]["brier"],
                "d_brier_ci": [float(np.quantile(boot[a][1] - boot[b][1], 0.025)),
                               float(np.quantile(boot[a][1] - boot[b][1], 0.975))],
                "d_within": float(dw.mean()) if len(dw) > 2 else None,
                "d_within_ci": ([float(dw.mean() - 1.96 * dw.std(ddof=1) / np.sqrt(len(dw))),
                                 float(dw.mean() + 1.96 * dw.std(ddof=1) / np.sqrt(len(dw)))]
                                if len(dw) > 2 else None)}
    return res


def curves(df, col, edges, labels, methods, rng):
    out = {}
    cut = pd.cut(df[col], edges, right=False, labels=labels)
    for lab in labels:
        sub = df[cut == lab]
        if len(sub):
            out[lab] = bucket_metrics(sub, methods, rng)
    return out


# ----------------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="arousal", choices=["arousal", "valence", "stress"])
    ap.add_argument("--label", default="full", choices=["full", "past"])
    ap.add_argument("--rate", type=int, default=2)
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--folds", type=int, default=5)
    ap.add_argument("--null", action="store_true", help="shuffle (features, label) in time per person")
    args = ap.parse_args()
    t0 = time.time()
    cv, bad = load_table()
    persons = build_persons(cv, args.target, args.label, args.null)
    name = f"{args.target}_{args.label}_r{args.rate}" + ("_null" if args.null else "")
    info = {"config": name, "esm_mismatch_rows": bad, "persons": len(persons),
            "rows": int(sum(len(P["y"]) for P in persons)),
            "label_base_rate": float(np.mean(np.concatenate([P["y"] for P in persons])))}
    rolls, frozens, params = [], [], []
    for k in range(args.folds):
        train = [P for P in persons if P["fold"] != k]
        test = [P for P in persons if P["fold"] == k]
        prm = tune(train, args.rate, seed=1000 + 10 * k)
        prm["rate"] = args.rate
        params.append(prm)
        M = fit_models(train, args.rate, seed=2000 + 10 * k)
        for s in range(args.seeds):
            for P in test:
                ci = sample_checkins(P["day"], args.rate, np.random.default_rng([s, args.rate, P["pid"]]))
                r, fr = predict_person(P, M, ci, prm, frozen=True)
                r["fold"], r["seed"] = k, s
                rolls.append(r)
                for f in fr:
                    f["fold"], f["seed"] = k, s
                frozens.extend(fr)
        print(f"[{name}] fold {k} done {time.time() - t0:.0f}s params {prm}", flush=True)
    R = pd.concat(rolls, ignore_index=True)
    rng = np.random.default_rng(0)
    res = dict(info=info, params=params)
    # per-fold pooled AUROC on all rows (sanity vs train.py)
    res["per_fold_auc_all_rows"] = {
        m: [float(wauc(g.y.to_numpy(float), g[m].to_numpy(), np.ones((1, len(g))))[0])
            for _, g in R[R.seed == 0].groupby("fold")] for m in METHODS}
    res["all_rows"] = bucket_metrics(R, METHODS, rng)
    res["rows_with_checkins"] = bucket_metrics(R[R.nb >= 1], METHODS, rng)
    res["by_n"] = curves(R, "nb", N_EDGES, N_LABELS, METHODS, rng)
    res["by_day"] = curves(R, "dou", D_EDGES, D_LABELS, METHODS, rng)
    long = [P["pid"] for P in persons if P["dou"].max() >= 29]   # fixed cohort: present all 4 weeks
    res["by_day_cohort29"] = curves(R[R.pid.isin(long)], "dou", D_EDGES, D_LABELS, METHODS, rng)
    res["by_n_cohort29"] = curves(R[R.pid.isin(long)], "nb", N_EDGES, N_LABELS, METHODS, rng)
    if frozens:
        F = pd.concat(frozens, ignore_index=True)
        res["frozen"] = {"eval_days_from": FROZEN_DAY, "n_max_before": FROZEN_NMAX[args.rate],
                         "by_n": {str(n): bucket_metrics(F[F.n == n], METHODS, rng)
                                  for n in sorted(F.n.unique())}}
    res["seconds"] = time.time() - t0
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{name}.json").write_text(json.dumps(res, indent=1))
    print(f"[{name}] wrote {OUT / (name + '.json')} in {res['seconds']:.0f}s", flush=True)


if __name__ == "__main__":
    main()
