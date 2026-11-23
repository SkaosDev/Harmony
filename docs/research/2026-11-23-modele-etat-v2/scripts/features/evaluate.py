"""Cross-validated value of the candidate feature families (D-1 + D-2 only, aggregates only).

Same 5 GroupKFold splits as ml/train.py (participant = wave + pcode), same model (median
imputation + StandardScaler + LogisticRegression, fitted inside each training fold).
Targets: arousal_high, valence_high (valence > the person's mean, ml/features.label_high),
stress_high. Every comparison is paired on the same folds: (v1 + family) - v1.

Usage: python evaluate.py [--part families|singles|q5|all]
"""
import argparse
import sys
import warnings

import numpy as np
import pandas as pd
from joblib import Parallel, delayed

sys.dont_write_bytecode = True
sys.path.insert(0, "/Users/clement/Hanyang/Harmony/ml")
from features import FEATURES, label_high, local_minute  # noqa: E402
from train import folds  # noqa: E402
from sklearn.impute import SimpleImputer  # noqa: E402
from sklearn.linear_model import LogisticRegression  # noqa: E402
from sklearn.metrics import balanced_accuracy_score, roc_auc_score  # noqa: E402
from sklearn.model_selection import GroupKFold  # noqa: E402
from sklearn.pipeline import make_pipeline  # noqa: E402
from sklearn.preprocessing import StandardScaler  # noqa: E402

warnings.filterwarnings("ignore")
V1 = "/Users/clement/Hanyang/Harmony/data/features"
OUT = "/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out"
TARGETS = ("arousal_high", "valence_high", "stress_high")
TIME = list(FEATURES[:3])
V1F = list(FEATURES)
FAM = {
    "A long windows 2-4 h": ["z_hr_120", "z_hr_240", "z_log_steps_120", "z_log_steps_240"],
    "B day so far (since 06:00)": ["z_steps_since6", "z_hr_since6", "z_sedhr_since6"],
    "C since wake / morning": ["z_steps_since_wake", "z_hr_since_wake", "z_hr_wake60", "z_steps_wake120"],
    "D yesterday / prev. evening": ["z_steps_yday", "z_hr_yday", "z_sedhr_yday", "z_hr_prev_evening",
                                    "z_steps_prev_evening"],
    "F min since walking": ["log_min_since_walk"],
    "E1 sedentary HR": ["z_sedhr_30", "z_sedhr_60", "z_sedhr_120"],
    "E2 HR residual after steps": ["zres_hr_30", "zres_hr_60"],
    "G intensity (METs, level)": ["z_mets_15", "z_mets_30", "z_mets_60", "lvl1_share_30", "lvl1_share_60",
                                  "z_lvl1_share_30", "z_lvl1_share_60"],
    "G1 intensity z-scored": ["z_mets_15", "z_mets_30", "z_mets_60", "z_lvl1_share_30", "z_lvl1_share_60"],
    "G2 intensity raw": ["lvl1_share_30", "lvl1_share_60", "raw_mets_30", "raw_mets_60"],
    "R1 raw steps (no reference)": ["raw_log_steps_30", "raw_log_steps_60"],
    "R2 raw HR (no reference)": ["raw_hr_30", "raw_hr_60"],
    "H1 activity type (ActivityEvent)": ["act_still_30", "act_foot_30", "act_vehicle_30", "act_still_60",
                                         "act_foot_60", "act_vehicle_60"],
    "H2 activity type (ActivityTransition)": ["tr_still_30", "tr_foot_30", "tr_vehicle_30", "tr_still_60",
                                              "tr_foot_60", "tr_vehicle_60"],
}
Q1 = sum((FAM[k] for k in FAM if k[0] in "ABCDF"), [])
ALLNEW = list(dict.fromkeys(sum(FAM.values(), [])))
CGRID = [1e-4, 3e-4, 1e-3, 3e-3, 0.01, 0.03, 0.1, 0.3, 1.0, 3.0]


def load():
    parts = []
    for w in ("D1", "D2"):
        v1 = pd.read_csv(f"{V1}/v1_{w}.csv")
        nw = pd.read_csv(f"{OUT}/new_{w}.csv")
        assert (v1.participant.values == nw.participant.values).all()
        assert (v1.t.values == nw.t.values).all()
        nw = nw.drop(columns=["participant", "t"])
        t = pd.concat([v1, nw], axis=1)
        t["valence_high"] = label_high(t.valence, t.participant)
        t["wave"] = w
        parts.append(t)
    cv = pd.concat(parts, ignore_index=True)
    cv["hour"] = (local_minute(cv.t.values) % 1440) // 60
    return cv


def model(C=1.0):
    return make_pipeline(SimpleImputer(strategy="median"), StandardScaler(),
                         LogisticRegression(C=C, max_iter=2000))


def fold_scores(cv, cols, target, splits, C=1.0, subset=None):
    """Per-fold AUROC and balanced accuracy; `subset` (bool mask) restricts the scored test rows."""
    x, y = cv[cols].to_numpy(dtype=float), cv[target].to_numpy()
    out = []
    for tr, te in splits:
        m = model(C).fit(x[tr], y[tr])
        if subset is not None:
            te = te[subset[te]]
        p = m.predict_proba(x[te])[:, 1]
        out.append((roc_auc_score(y[te], p), balanced_accuracy_score(y[te], p > 0.5)))
    return np.array(out)


def fmt(r):
    return f"{r[:, 0].mean():.3f} ± {r[:, 0].std():.3f}"


def paired(r, base):
    d = r[:, 0] - base[:, 0]
    db = r[:, 1] - base[:, 1]
    return f"{d.mean():+.4f} ± {d.std():.4f} ({(d > 0).sum()}/5 folds >0); BA {db.mean():+.4f} ± {db.std():.4f}"


def families(cv, splits, log):
    log("## Coverage: share unknown (NaN) per new feature — D-1 / D-2 / pooled")
    for k, cols in FAM.items():
        for c in cols:
            u = cv.groupby("wave")[c].apply(lambda s: s.isna().mean())
            log(f"  {c:<24} {u['D1']:.3f} / {u['D2']:.3f} / {cv[c].isna().mean():.3f}")
    for c in ("act_known_60", "tr_known_60", "cov_since6"):
        log(f"  {c:<24} mean {cv[c].mean():.3f}; share 0: {(cv[c] == 0).mean():.3f}")
    log("")
    log("## Redundancy: pooled Pearson r between new and v1 features (rows where both known)")
    pairs = [("z_mets_30", "z_log_steps_30"), ("z_mets_30", "z_hr_30"), ("lvl1_share_30", "z_log_steps_30"),
             ("act_foot_30", "z_log_steps_30"), ("act_vehicle_30", "z_log_steps_30"),
             ("act_vehicle_30", "z_hr_30"), ("z_sedhr_60", "z_hr_60"), ("zres_hr_30", "z_hr_30"),
             ("z_hr_120", "z_hr_60"), ("z_hr_since6", "z_hr_60"), ("z_steps_since6", "z_log_steps_60"),
             ("log_min_since_walk", "z_log_steps_60"), ("z_hr_yday", "z_hr_30"),
             ("tr_vehicle_60", "act_vehicle_60"), ("tr_foot_60", "act_foot_60")]
    for a, b in pairs:
        k = cv[a].notna() & cv[b].notna()
        log(f"  r({a}, {b}) = {np.corrcoef(cv.loc[k, a], cv.loc[k, b])[0, 1]:+.3f}  (n={k.sum()})")
    log("")
    morning = (cv.hour < 12).to_numpy()
    for target in TARGETS:
        log(f"## Target {target}: AUROC mean ± sd over 5 folds; paired Δ vs v1 (13)")
        t_only = fold_scores(cv, TIME, target, splits)
        base = fold_scores(cv, V1F, target, splits)
        log(f"  time only (3)            AUROC {fmt(t_only)}  BA {t_only[:, 1].mean():.3f}")
        log(f"  v1 (13)                  AUROC {fmt(base)}  BA {base[:, 1].mean():.3f} ± {base[:, 1].std():.3f}")
        sets = dict(FAM)
        sets["Q1 all day context (A+B+C+D+F)"] = Q1
        sets["E1+E2 sedentary + residual HR"] = FAM["E1 sedentary HR"] + FAM["E2 HR residual after steps"]
        sets["H1+H2 activity type"] = FAM["H1 activity type (ActivityEvent)"] + FAM["H2 activity type (ActivityTransition)"]
        for name, cols in sets.items():
            r = fold_scores(cv, V1F + cols, target, splits)
            log(f"  v1 + {name:<38} ({len(cols):>2}) AUROC {fmt(r)}  Δ {paired(r, base)}")
        # Q3: intensity instead of steps
        no_steps = [c for c in V1F if "steps" not in c]
        r0 = fold_scores(cv, no_steps, target, splits)
        r1 = fold_scores(cv, no_steps + ["z_mets_15", "z_mets_30", "z_mets_60"], target, splits)
        log(f"  [Q3] v1 without steps (10)                    AUROC {fmt(r0)}  Δ vs v1 {paired(r0, base)}")
        log(f"  [Q3] v1 with METs instead of steps (13)       AUROC {fmt(r1)}  Δ vs v1 {paired(r1, base)}")
        r3 = fold_scores(cv, V1F + FAM["R1 raw steps (no reference)"] + FAM["G2 intensity raw"], target, splits)
        r4 = fold_scores(cv, V1F + FAM["R1 raw steps (no reference)"], target, splits)
        log(f"  [Q3] v1 + R1 raw steps + G2 raw intensity      AUROC {fmt(r3)}  Δ vs v1+R1 {paired(r3, r4)}")
        # Q2: sedentary HR instead of all-readings HR
        no_hr = [c for c in V1F if "hr" not in c]
        r2 = fold_scores(cv, no_hr + ["z_sedhr_30", "z_sedhr_60", "z_sedhr_120"], target, splits)
        log(f"  [Q2] v1 with sedentary HR instead of HR (12)  AUROC {fmt(r2)}  Δ vs v1 {paired(r2, base)}")
        # morning subset (answers before 12:00), models fitted on all rows
        bm = fold_scores(cv, V1F, target, splits, subset=morning)
        tm = fold_scores(cv, TIME, target, splits, subset=morning)
        log(f"  [morning <12h, {morning.sum()} answers] time only AUROC {fmt(tm)}; v1 AUROC {fmt(bm)}")
        for name in ("B day so far (since 06:00)", "C since wake / morning", "D yesterday / prev. evening"):
            r = fold_scores(cv, V1F + FAM[name], target, splits, subset=morning)
            log(f"      v1 + {name:<34} AUROC {fmt(r)}  Δ {paired(r, bm)}")
        r = fold_scores(cv, V1F + Q1, target, splits, subset=morning)
        log(f"      v1 + Q1 all day context              AUROC {fmt(r)}  Δ {paired(r, bm)}")
        # activity type where the phone signal is known
        known = cv["act_still_30"].notna().to_numpy()
        bk = fold_scores(cv, V1F, target, splits, subset=known)
        rk = fold_scores(cv, V1F + FAM["H1 activity type (ActivityEvent)"], target, splits, subset=known)
        log(f"  [H1 rows with activity known, {known.sum()}] v1 {fmt(bk)}; v1+H1 {fmt(rk)}  Δ {paired(rk, bk)}")
        log("")


def singles(cv, splits, log):
    log("## Single new feature added to v1: paired Δ AUROC mean ± sd (folds > 0)")
    allnew = ALLNEW
    for target in TARGETS:
        base = fold_scores(cv, V1F, target, splits)
        res = Parallel(n_jobs=7)(delayed(fold_scores)(cv, V1F + [c], target, splits) for c in allnew)
        log(f"### {target} (v1 AUROC {fmt(base)})")
        rows = []
        for c, r in zip(allnew, res):
            d = r[:, 0] - base[:, 0]
            rows.append((d.mean(), c, d.std(), (d > 0).sum()))
        for m, c, s, k in sorted(rows, reverse=True):
            log(f"  {c:<24} {m:+.4f} ± {s:.4f} ({k}/5)")
        log("")


def inner_auc(cv, cols, target, idx, C):
    """Mean AUROC of a 4-fold GroupKFold inside the training rows idx."""
    g = cv.participant.to_numpy()[idx]
    x, y = cv[cols].to_numpy(dtype=float)[idx], cv[target].to_numpy()[idx]
    a = []
    for tr, te in GroupKFold(4).split(x, groups=g):
        m = model(C).fit(x[tr], y[tr])
        a.append(roc_auc_score(y[te], m.predict_proba(x[te])[:, 1]))
    return np.mean(a)


def nested_c(cv, cols, target, splits):
    """Outer folds as train.py; C chosen by inner GroupKFold(4) on the training participants."""
    out, chosen = [], []
    for tr, te in splits:
        aucs = Parallel(n_jobs=7)(delayed(inner_auc)(cv, cols, target, tr, C) for C in CGRID)
        C = CGRID[int(np.argmax(aucs))]
        chosen.append(C)
        x, y = cv[cols].to_numpy(dtype=float), cv[target].to_numpy()
        m = model(C).fit(x[tr], y[tr])
        p = m.predict_proba(x[te])[:, 1]
        out.append((roc_auc_score(y[te], p), balanced_accuracy_score(y[te], p > 0.5)))
    return np.array(out), chosen


def forward_families(cv, target, splits, log, min_gain=0.002):
    """Greedy family selection inside each training fold (inner 4-fold CV), scored on the outer fold."""
    out, picks = [], []
    names = list(FAM)
    for tr, te in splits:
        chosen, cur = [], inner_auc(cv, V1F, target, tr, 1.0)
        while True:
            left = [n for n in names if n not in chosen]
            if not left:
                break
            cand = Parallel(n_jobs=7)(delayed(inner_auc)(
                cv, V1F + sum((FAM[n] for n in chosen + [k]), []), target, tr, 1.0) for k in left)
            j = int(np.argmax(cand))
            if cand[j] - cur < min_gain:
                break
            chosen.append(left[j])
            cur = cand[j]
        cols = V1F + sum((FAM[n] for n in chosen), [])
        x, y = cv[cols].to_numpy(dtype=float), cv[target].to_numpy()
        p = model().fit(x[tr], y[tr]).predict_proba(x[te])[:, 1]
        out.append((roc_auc_score(y[te], p), balanced_accuracy_score(y[te], p > 0.5)))
        picks.append([n.split(" ")[0] for n in chosen])
    return np.array(out), picks


def q5(cv, splits, log, best, forward=True):
    log("## Q5 combined sets")
    allnew = V1F + ALLNEW
    for target in TARGETS:
        log(f"### {target}")
        base = fold_scores(cv, V1F, target, splits)
        log(f"  v1 (13), C=1                     AUROC {fmt(base)}  BA {base[:, 1].mean():.3f}")
        r = fold_scores(cv, allnew, target, splits)
        log(f"  v1 + ALL candidates ({len(allnew)}), C=1   AUROC {fmt(r)}  Δ {paired(r, base)}")
        cols = V1F + best[target]
        rb = fold_scores(cv, cols, target, splits)
        log(f"  proposed set ({len(cols)}), C=1          AUROC {fmt(rb)}  Δ {paired(rb, base)}  "
            f"[set chosen after looking at these folds: optimistic]")
        rv, cvv = nested_c(cv, V1F, target, splits)
        log(f"  v1 (13), nested C                AUROC {fmt(rv)}  chosen C per fold {cvv}")
        ra, cva = nested_c(cv, allnew, target, splits)
        log(f"  ALL ({len(allnew)}), nested C              AUROC {fmt(ra)}  Δ vs v1 nested {paired(ra, rv)}  C {cva}")
        rp, cvp = nested_c(cv, cols, target, splits)
        log(f"  proposed ({len(cols)}), nested C          AUROC {fmt(rp)}  Δ vs v1 nested {paired(rp, rv)}  C {cvp}")
        if forward:
            rf, picks = forward_families(cv, target, splits, log)
            log(f"  forward family selection inside training folds: AUROC {fmt(rf)}  Δ vs v1 {paired(rf, base)}")
            log(f"     families picked per fold: {picks}")
        # standardized coefficients of the proposed set, mean ± sd over the 5 fold models
        x, y = cv[cols].to_numpy(dtype=float), cv[target].to_numpy()
        coefs = np.array([model().fit(x[tr], y[tr])[-1].coef_[0] for tr, _ in splits])
        log("  standardized coefficients of the proposed set (mean ± sd over 5 fold models):")
        for c, m, s in sorted(zip(cols, coefs.mean(0), coefs.std(0)), key=lambda z: -abs(z[1])):
            log(f"     {c:<24} {m:+.3f} ± {s:.3f}")
        log("")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--part", default="families")
    ap.add_argument("--best", default="")   # target=fam1,fam2;target2=...
    ap.add_argument("--tag", default="")
    ap.add_argument("--no-forward", action="store_true")
    args = ap.parse_args()
    cv = load()
    splits = folds(cv.participant)
    lines = []

    def log(s):
        print(s, flush=True)
        lines.append(s)

    log(f"CV table: {len(cv)} answers, {cv.participant.nunique()} participants (D-1 + D-2), 5 folds")
    log("label base rates: " + ", ".join(f"{t} {cv[t].mean():.3f}" for t in TARGETS))
    if args.part in ("families", "all"):
        families(cv, splits, log)
    if args.part in ("singles", "all"):
        singles(cv, splits, log)
    if args.part in ("q5", "all"):
        best = {t: [] for t in TARGETS}
        for spec in filter(None, args.best.split(";")):
            t, fams = spec.split("=")
            for f in fams.split(","):
                best[t] += FAM[f] if f in FAM else [f]
        q5(cv, splits, log, best, forward=not args.no_forward)
    with open(f"{OUT}/eval_{args.part}{args.tag}.txt", "w") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
