"""Q3 (model families, nested tuning), Q5 (probability spread, calibration, per-person rank)
and Q6 (2-D arousal x valence quadrants), on the 13 v1 features, D-1 + D-2 only.

Outer: the 5 GroupKFold splits of ml/train.py. Inner (tuning, stacking): GroupKFold(4) on the
training participants of each outer fold only. Every model = median imputation + scaler + model,
fitted on training rows only. Out-of-fold predictions stay in memory; only aggregates are printed.
"""
import itertools
import os

os.environ.setdefault("OMP_NUM_THREADS", "1")
import numpy as np
from joblib import Parallel, delayed
from sklearn.base import clone
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GroupKFold
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import FunctionTransformer, PolynomialFeatures, StandardScaler

from common import (F13, TARGETS, TIME, auc, bal, brier, ece, load_table, logit, ms, paired,
                    pct, spearman, splits_of, train)

IDX = {f: i for i, f in enumerate(F13)}
PAIRS = [("hour_sin", "z_hr_30"), ("hour_cos", "z_hr_30"), ("hour_sin", "z_log_steps_30"),
         ("hour_cos", "z_log_steps_30"), ("z_hr_30", "z_log_steps_30"),
         ("hours_since_wake", "z_hr_30"), ("weekend", "hour_sin"), ("weekend", "hour_cos")]


def add_pairs(x):
    return np.hstack([x] + [x[:, [IDX[a]]] * x[:, [IDX[b]]] for a, b in PAIRS])


def base(*steps):
    return make_pipeline(SimpleImputer(strategy="median"), StandardScaler(), *steps)


LR_C = [1e-3, 3e-3, 1e-2, 3e-2, 0.1, 0.3, 1.0, 3.0]
FAMILIES = {
    "LR tuned C": (lambda C: base(LogisticRegression(C=C, max_iter=2000)), [dict(C=c) for c in LR_C]),
    "LR + 8 interactions": (lambda C: base(FunctionTransformer(add_pairs), StandardScaler(),
                                           LogisticRegression(C=C, max_iter=2000)),
                            [dict(C=c) for c in LR_C]),
    "LR + all pairwise (deg 2)": (lambda C: base(PolynomialFeatures(2, include_bias=False),
                                                 StandardScaler(),
                                                 LogisticRegression(C=C, max_iter=3000)),
                                  [dict(C=c) for c in [1e-3, 3e-3, 1e-2, 3e-2, 0.1, 1.0]]),
    "HistGradientBoosting": (lambda **k: base(HistGradientBoostingClassifier(
        learning_rate=0.05, min_samples_leaf=100, l2_regularization=1.0, early_stopping=False,
        random_state=0, **k)),
        [dict(max_depth=d, max_iter=n) for d, n in itertools.product([2, 3, 5], [50, 150, 400])]),
    "MLP": (lambda **k: base(MLPClassifier(max_iter=300, random_state=0, **k)),
            [dict(hidden_layer_sizes=h, alpha=a) for h, a in
             itertools.product([(8,), (16,), (32, 16)], [1e-2, 1e-1, 1.0, 3.0])]),
}
STACK_BASES = ["LR tuned C", "HistGradientBoosting", "MLP"]


def tune(name, x, y, g):
    """Pick the config with the best mean inner-fold AUROC; return refit model, OOF of best."""
    build, grid = FAMILIES[name]
    inner = list(GroupKFold(n_splits=4).split(x, y, g))
    best = None
    for params in grid:
        oof = np.zeros(len(y))
        aucs = []
        for a, b in inner:
            m = build(**params).fit(x[a], y[a])
            oof[b] = m.predict_proba(x[b])[:, 1]
            aucs.append(auc(y[b], oof[b]))
        if best is None or np.mean(aucs) > best[0]:
            best = (np.mean(aucs), params, oof)
    model = build(**best[1]).fit(x, y)
    return model, best[1], best[2]


def run_fold(k, fi, tr, te, X13, XT, Y, G):
    y = Y[k]
    out, chosen = {}, {}
    out["time only (LR C=1)"] = train.make_model().fit(XT[tr], y[tr]).predict_proba(XT[te])[:, 1]
    out["LR C=1 (current)"] = train.make_model().fit(X13[tr], y[tr]).predict_proba(X13[te])[:, 1]
    oofs = {}
    for name in FAMILIES:
        m, params, oof = tune(name, X13[tr], y[tr], G[tr])
        out[name] = m.predict_proba(X13[te])[:, 1]
        chosen[name] = params
        oofs[name] = oof
    out["Ensemble mean (LR, HGB, MLP)"] = np.mean([out[n] for n in STACK_BASES], axis=0)
    meta = LogisticRegression(max_iter=1000).fit(
        np.column_stack([logit(oofs[n]) for n in STACK_BASES]), y[tr])
    out["Stack (meta-LR on LR, HGB, MLP)"] = meta.predict_proba(
        np.column_stack([logit(out[n]) for n in STACK_BASES]))[:, 1]
    return k, fi, te, out, chosen, float(y[tr].mean())


def past_rank(p, part, t, min_hist):
    """Rank of each prediction among the same person's strictly earlier predictions (0..1).
    NaN when fewer than min_hist earlier predictions exist."""
    r = np.full(len(p), np.nan)
    for q in np.unique(part):
        idx = np.where(part == q)[0]
        idx = idx[np.argsort(t[idx], kind="stable")]
        pp, tt = p[idx], t[idx]
        past = tt[None, :] < tt[:, None]               # [j, i]: answer i is before answer j
        n = past.sum(1)
        below = (past & (pp[None, :] < pp[:, None])).sum(1)
        tie = (past & (pp[None, :] == pp[:, None])).sum(1)
        with np.errstate(invalid="ignore", divide="ignore"):
            rr = (below + 0.5 * tie) / n
        r[idx] = np.where(n >= min_hist, rr, np.nan)
    return r


def within_auc(y, s, part):
    """Mean over participants of the within-person AUROC (participants with both classes)."""
    vals = [auc(y[part == q], s[part == q]) for q in np.unique(part)
            if len(np.unique(y[part == q])) == 2]
    return float(np.mean(vals)), len(vals)


def main():
    table = load_table()
    splits = splits_of(table)
    X13 = table[F13].to_numpy(float)
    XT = table[TIME].to_numpy(float)
    Y = {k: table[f"{k}_high"].to_numpy() for k in TARGETS}
    YC = {k: table[f"{k}_c"].to_numpy() for k in TARGETS}
    G = table.participant.to_numpy()
    T = table.t.to_numpy()
    fold_of = np.empty(len(table), int)
    for fi, (_, te) in enumerate(splits):
        fold_of[te] = fi

    jobs = [(k, fi, tr, te) for k in TARGETS for fi, (tr, te) in enumerate(splits)]
    res = Parallel(n_jobs=8)(delayed(run_fold)(k, fi, tr, te, X13, XT, Y, G) for k, fi, tr, te in jobs)

    names = list(res[0][3].keys())
    OOF = {k: {n: np.zeros(len(table)) for n in names} for k in TARGETS}
    FOLD = {k: {n: [] for n in names} for k in TARGETS}   # per-fold (auc, ba, brier, ece)
    CHOSEN = {k: {n: [] for n in FAMILIES} for k in TARGETS}
    PRIOR = {k: [None] * 5 for k in TARGETS}
    for k, fi, te, out, chosen, prior in sorted(res, key=lambda r: (r[0], r[1])):
        y = Y[k][te]
        PRIOR[k][fi] = prior
        for n in names:
            OOF[k][n][te] = out[n]
            FOLD[k][n].append((auc(y, out[n]), bal(y, out[n]), brier(y, out[n]), ece(y, out[n]),
                               brier(y, np.full(len(y), prior))))
        for n in FAMILIES:
            CHOSEN[k][n].append(chosen[n])

    print(f"D-1 + D-2: {len(table)} answers, {table.participant.nunique()} participants; "
          "outer 5 folds (ml/train.py), inner GroupKFold(4) for tuning/stacking")
    print("\n=== Q3: model families on the 13 v1 features (fold mean +/- sd; paired vs LR C=1"
          " and vs time only) ===")
    for k in TARGETS:
        print(f"\n[{k}_high]")
        ref = np.array(FOLD[k]["LR C=1 (current)"])
        tim = np.array(FOLD[k]["time only (LR C=1)"])
        for n in names:
            f = np.array(FOLD[k][n])
            line = f"  {n:<34} AUROC {ms(f[:, 0])}  BA {ms(f[:, 1])}"
            if n not in ("LR C=1 (current)", "time only (LR C=1)"):
                line += f"\n      vs LR C=1: AUROC {paired(f[:, 0], ref[:, 0])}; vs time: {paired(f[:, 0], tim[:, 0])}"
            elif n == "LR C=1 (current)":
                line += f"\n      vs time: {paired(f[:, 0], tim[:, 0])}"
            print(line)
        print("  chosen hyper-parameters per outer fold:")
        for n in FAMILIES:
            print(f"    {n}: {CHOSEN[k][n]}")

    print("\n=== Q5: spread and calibration of out-of-fold probabilities ===")
    print("  percentiles 5/25/50/75/95 pooled over test folds; Brier / ECE(10 bins) fold mean +/- sd;"
          " Brier of the training base rate as reference")
    for k in TARGETS:
        f0 = np.array(FOLD[k]["LR C=1 (current)"])
        print(f"\n[{k}_high]  base-rate Brier {ms(f0[:, 4])}")
        for n in names:
            f = np.array(FOLD[k][n])
            q = pct(OOF[k][n])
            print(f"  {n:<34} p {' / '.join(f'{v:.3f}' for v in q)}  Brier {ms(f[:, 2])}  "
                  f"ECE {ms(f[:, 3])}")

    print("\n=== Q5: per-person past-only rank of the predictions (e0 spread) ===")
    for k in TARGETS:
        y = Y[k]
        print(f"\n[{k}_high]")
        for n in ["time only (LR C=1)", "LR C=1 (current)", "LR tuned C", "HistGradientBoosting",
                  "Stack (meta-LR on LR, HGB, MLP)"]:
            p = OOF[k][n]
            for h in (7, 20):
                r = past_rank(p, G, T, h)
                ok = ~np.isnan(r)
                fa_raw, fa_rank = [], []
                for fi in range(5):
                    m = ok & (fold_of == fi)
                    fa_raw.append(auc(y[m], p[m]))
                    fa_rank.append(auc(y[m], r[m]))
                wa_raw, npp = within_auc(y[ok], p[ok], G[ok])
                wa_rank, _ = within_auc(y[ok], r[ok], G[ok])
                print(f"  {n:<32} min history {h:>2}: rows with rank {ok.mean():.3f}; "
                      f"rank pct {' / '.join(f'{v:.2f}' for v in pct(r[ok]))}; "
                      f"raw p pct on same rows {' / '.join(f'{v:.3f}' for v in pct(p[ok]))}")
                print(f"      pooled AUROC raw {ms(fa_raw)}  rank {ms(fa_rank)}  "
                      f"paired rank-raw {paired(fa_rank, fa_raw)}; "
                      f"within-person AUROC raw {wa_raw:.3f} rank {wa_rank:.3f} ({npp} persons)")

    print("\n=== Q6: 2-D state (arousal = energy, valence = positivity) quadrants ===")
    qname = ["lowA-lowV", "lowA-highV", "highA-lowV", "highA-highV"]
    true_q = 2 * Y["arousal"] + Y["valence"]
    tq = np.bincount(true_q, minlength=4) / len(true_q)
    print("  true quadrant shares: " + ", ".join(f"{qname[i]} {tq[i]:.3f}" for i in range(4)))
    for n in ["LR C=1 (current)", "LR tuned C", "HistGradientBoosting",
              "Stack (meta-LR on LR, HGB, MLP)"]:
        pa, pv = OOF["arousal"][n], OOF["valence"][n]
        thr_a = np.array([PRIOR["arousal"][f] for f in fold_of])
        thr_v = np.array([PRIOR["valence"][f] for f in fold_of])
        ra, rv = past_rank(pa, G, T, 20), past_rank(pv, G, T, 20)
        variants = {"threshold 0.5": (pa > 0.5, pv > 0.5, np.ones(len(pa), bool)),
                    "threshold = training base rate": (pa > thr_a, pv > thr_v, np.ones(len(pa), bool)),
                    "per-person past rank > 0.5 (>=20 past)": (ra > 0.5, rv > 0.5,
                                                              ~np.isnan(ra) & ~np.isnan(rv))}
        print(f"\n  model: {n}")
        rho_a = spearman(pa, YC["arousal"])
        rho_v = spearman(pv, YC["valence"])
        print(f"    Spearman pooled: p_arousal vs centred arousal {rho_a:.3f}; "
              f"p_valence vs centred valence {rho_v:.3f}; p_arousal vs p_valence "
              f"{spearman(pa, pv):.3f}")
        for vn, (ha, hv, m) in variants.items():
            pq = (2 * ha + hv).astype(int)[m]
            tqm = true_q[m]
            cm = np.zeros((4, 4))
            for a_, b_ in zip(tqm, pq):
                cm[a_, b_] += 1
            acc = np.trace(cm) / cm.sum()
            pt = cm.sum(1) / cm.sum()
            pp = cm.sum(0) / cm.sum()
            chance = float((pt * pp).sum())
            kappa = (acc - chance) / (1 - chance)
            opp = (cm[0, 3] + cm[3, 0] + cm[1, 2] + cm[2, 1]) / cm.sum()
            opp_chance = pt[0] * pp[3] + pt[3] * pp[0] + pt[1] * pp[2] + pt[2] * pp[1]
            facc = []
            for fi in range(5):
                mm = fold_of[m] == fi
                facc.append((tqm[mm] == pq[mm]).mean())
            print(f"    [{vn}] rows {m.mean():.3f}; accuracy {acc:.3f} (fold {ms(facc)}), "
                  f"chance {chance:.3f}, kappa {kappa:.3f}; opposite-quadrant rate {opp:.3f} "
                  f"(chance {opp_chance:.3f})")
            print("      predicted shares: " + ", ".join(f"{qname[i]} {pp[i]:.3f}" for i in range(4)))
            print("      P(pred | true), rows = true " + " | ".join(qname))
            for i in range(4):
                row = cm[i] / max(cm[i].sum(), 1)
                print(f"        {qname[i]:<12} " + "  ".join(f"{v:.3f}" for v in row))


if __name__ == "__main__":
    main()
