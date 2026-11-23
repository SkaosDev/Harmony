"""Q4: multiple outputs on the 13 v1 features, D-1 + D-2 only.

(a) separate models per target (LR C=1; single-task MLP, tuned per target)
(b) multi-task MLP (one network, 3 sigmoid outputs: arousal, valence, stress), tuned on the
    mean inner AUROC of the 3 targets
(c) classifier chains A -> V -> S and cross-target stacking (each target gets the inner
    out-of-fold logits of the other two), with LR and with a fixed HGB; plus an upper bound
    where the true arousal_high answer is an input (what an in-app question would give)
(d) person-centred continuous targets (value - person mean): Ridge (alpha tuned in inner folds)
    and a fixed HGB regressor; AUROC on the binary label, Spearman and R^2 on the centred value
Outer: the 5 splits of ml/train.py; inner: GroupKFold(4) on training participants only.
Aggregates only.
"""
import itertools
import os

os.environ.setdefault("OMP_NUM_THREADS", "1")
import numpy as np
from joblib import Parallel, delayed
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.model_selection import GroupKFold
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from common import (F13, TARGETS, auc, bal, brier, ece, load_table, logit, ms, paired, pct,
                    spearman, splits_of, train)

GRID = [dict(hidden_layer_sizes=h, alpha=a) for h, a in
        itertools.product([(16,), (32,), (32, 16)], [1e-2, 1e-1, 1.0, 3.0])]
SEEDS = (0, 1, 2)


def prep():
    return make_pipeline(SimpleImputer(strategy="median"), StandardScaler())


def mlp(seed, **k):
    return make_pipeline(prep(), MLPClassifier(max_iter=300, random_state=seed, **k))


def proba(m, x):
    p = m.predict_proba(x)
    return p if p.ndim == 2 and p.shape[1] != 2 else p[:, 1]


def tune_mlp(x, Y, g):
    """Y: (n,) single target or (n, 3) multi-task. Score = mean inner AUROC over outputs."""
    inner = list(GroupKFold(n_splits=4).split(x, Y, g))
    best = None
    for params in GRID:
        sc = []
        for a, b in inner:
            p = proba(mlp(0, **params).fit(x[a], Y[a]), x[b])
            if Y.ndim == 1:
                sc.append(auc(Y[b], p))
            else:
                sc.append(np.mean([auc(Y[b][:, j], p[:, j]) for j in range(Y.shape[1])]))
        if best is None or np.mean(sc) > best[0]:
            best = (np.mean(sc), params)
    preds = [mlp(s, **best[1]).fit(x, Y) for s in SEEDS]
    return preds, best[1]


def hgb_c():
    return make_pipeline(prep(), HistGradientBoostingClassifier(
        learning_rate=0.05, max_depth=3, max_iter=150, min_samples_leaf=100,
        l2_regularization=1.0, early_stopping=False, random_state=0))


def lr_c():
    return train.make_model()


def inner_oof(make, x, y, g):
    oof = np.zeros(len(y))
    for a, b in GroupKFold(n_splits=4).split(x, y, g):
        oof[b] = make().fit(x[a], y[a]).predict_proba(x[b])[:, 1]
    return oof


def run_fold(fi, tr, te, X, YB, YC, G):
    out, chosen = {}, {}
    ks = list(TARGETS)
    Ymat = np.column_stack([YB[k] for k in ks])
    # (a) separate models
    for k in ks:
        out[("LR C=1 separate", k)] = lr_c().fit(X[tr], YB[k][tr]).predict_proba(X[te])[:, 1]
        out[("HGB fixed separate", k)] = hgb_c().fit(X[tr], YB[k][tr]).predict_proba(X[te])[:, 1]
        models, params = tune_mlp(X[tr], YB[k][tr], G[tr])
        out[("MLP single-task", k)] = np.mean([m.predict_proba(X[te])[:, 1] for m in models], 0)
        chosen[("MLP single-task", k)] = params
    # (b) multi-task MLP
    models, params = tune_mlp(X[tr], Ymat[tr], G[tr])
    pm = np.mean([m.predict_proba(X[te]) for m in models], 0)
    chosen[("MLP multi-task", "all")] = params
    for j, k in enumerate(ks):
        out[("MLP multi-task", k)] = pm[:, j]
    # (c) chains and cross-target stacking
    for fam, make in (("LR", lr_c), ("HGB", hgb_c)):
        oof = {k: inner_oof(make, X[tr], YB[k][tr], G[tr]) for k in ks}
        full = {k: make().fit(X[tr], YB[k][tr]).predict_proba(X[te])[:, 1] for k in ks}
        # chain A -> V -> S (A unchanged)
        for k, ups in (("valence", ["arousal"]), ("stress", ["arousal", "valence"])):
            xa = np.column_stack([X[tr]] + [logit(oof[u]) for u in ups])
            xb = np.column_stack([X[te]] + [logit(full[u]) for u in ups])
            out[(f"{fam} chain A->V->S", k)] = make().fit(xa, YB[k][tr]).predict_proba(xb)[:, 1]
        out[(f"{fam} chain A->V->S", "arousal")] = full["arousal"]
        # cross-target stacking: each target gets the two others
        for k in ks:
            others = [u for u in ks if u != k]
            xa = np.column_stack([X[tr]] + [logit(oof[u]) for u in others])
            xb = np.column_stack([X[te]] + [logit(full[u]) for u in others])
            out[(f"{fam} cross-target stack", k)] = make().fit(xa, YB[k][tr]).predict_proba(xb)[:, 1]
    # upper bound: true arousal_high answer as an input (in-app question)
    for k in ("valence", "stress"):
        xa = np.column_stack([X[tr], YB["arousal"][tr]])
        xb = np.column_stack([X[te], YB["arousal"][te]])
        out[("LR + true arousal_high (question)", k)] = lr_c().fit(xa, YB[k][tr]).predict_proba(xb)[:, 1]
    # (d) person-centred continuous targets
    for k in ks:
        inner = list(GroupKFold(n_splits=4).split(X[tr], YC[k][tr], G[tr]))
        best = None
        for alpha in (1.0, 10.0, 100.0, 1000.0, 1e4, 1e5):
            sc = []
            for a, b in inner:
                ia, ib = tr[a], tr[b]
                r = make_pipeline(prep(), Ridge(alpha=alpha)).fit(X[ia], YC[k][ia])
                sc.append(auc(YB[k][ib], r.predict(X[ib])))
            if best is None or np.mean(sc) > best[0]:
                best = (np.mean(sc), alpha)
        chosen[("Ridge centred", k)] = best[1]
        out[("Ridge centred (regression)", k)] = make_pipeline(prep(), Ridge(alpha=best[1])).fit(
            X[tr], YC[k][tr]).predict(X[te])
        out[("HGB regressor centred (fixed)", k)] = make_pipeline(
            prep(), HistGradientBoostingRegressor(
                learning_rate=0.05, max_depth=3, max_iter=150, min_samples_leaf=100,
                l2_regularization=1.0, early_stopping=False, random_state=0)).fit(
            X[tr], YC[k][tr]).predict(X[te])
    return fi, te, out, chosen


def main():
    table = load_table()
    splits = splits_of(table)
    X = table[F13].to_numpy(float)
    YB = {k: table[f"{k}_high"].to_numpy() for k in TARGETS}
    YC = {k: table[f"{k}_c"].to_numpy() for k in TARGETS}
    G = table.participant.to_numpy()
    res = Parallel(n_jobs=5)(delayed(run_fold)(fi, tr, te, X, YB, YC, G)
                             for fi, (tr, te) in enumerate(splits))
    res.sort(key=lambda r: r[0])
    keys = list(res[0][2].keys())
    print(f"D-1 + D-2: {len(table)} answers; outer 5 folds (ml/train.py), inner GroupKFold(4)")
    print("MLP predictions = mean of 3 seeds of the tuned config; HGB fixed: depth 3, 150 iter,"
          " lr 0.05, min leaf 100, l2 1")
    for k in TARGETS:
        print(f"\n=== [{k}] ===")
        rows = [kk for kk in keys if kk[1] == k]
        F = {}
        for name, _ in rows:
            f = []
            for fi, te, out, _c in res:
                y, s, yc = YB[k][te], out[(name, k)], YC[k][te]
                is_prob = "centred" not in name
                f.append((auc(y, s), bal(y, s, 0.5 if is_prob else 0.0), spearman(s, yc),
                          brier(y, s) if is_prob else np.nan, ece(y, s) if is_prob else np.nan,
                          1 - np.mean((yc - s) ** 2) / np.mean(yc ** 2)))
            F[name] = np.array(f)
        ref = F["LR C=1 separate"]
        for name in F:
            f = F[name]
            pooled = np.concatenate([out[(name, k)] for _, _, out, _ in res])
            line = (f"  {name:<34} AUROC {ms(f[:, 0])}  BA {ms(f[:, 1])}  Spearman(centred) "
                    f"{ms(f[:, 2])}")
            if "centred" in name:
                line += f"  R2(centred) {ms(f[:, 5])}  pred pct {' / '.join(f'{v:+.3f}' for v in pct(pooled))}"
            else:
                line += (f"  Brier {ms(f[:, 3])}  ECE {ms(f[:, 4])}  p pct "
                         f"{' / '.join(f'{v:.3f}' for v in pct(pooled))}")
            print(line)
            if name != "LR C=1 separate":
                print(f"      paired AUROC vs LR C=1 separate {paired(f[:, 0], ref[:, 0])}")
        if "MLP single-task" in F and "MLP multi-task" in F:
            print(f"      paired AUROC multi-task - single-task MLP "
                  f"{paired(F['MLP multi-task'][:, 0], F['MLP single-task'][:, 0])}")
        for fam in ("LR", "HGB"):
            base = F["LR C=1 separate"] if fam == "LR" else F["HGB fixed separate"]
            for v in (f"{fam} chain A->V->S", f"{fam} cross-target stack"):
                if v in F and k != "arousal" or v.endswith("stack"):
                    print(f"      paired AUROC {v} - {fam} separate {paired(F[v][:, 0], base[:, 0])}")
        if "LR + true arousal_high (question)" in F:
            print(f"      paired AUROC LR + true arousal_high - LR separate "
                  f"{paired(F['LR + true arousal_high (question)'][:, 0], ref[:, 0])}")
        if "Ridge centred (regression)" in F:
            print(f"      paired AUROC Ridge centred - LR separate "
                  f"{paired(F['Ridge centred (regression)'][:, 0], ref[:, 0])}; Spearman "
                  f"{paired(F['Ridge centred (regression)'][:, 2], ref[:, 2])}")
    print("\nchosen hyper-parameters per outer fold:")
    for c in res[0][3]:
        print(f"  {c}: {[r[3][c] for r in res]}")


if __name__ == "__main__":
    main()
