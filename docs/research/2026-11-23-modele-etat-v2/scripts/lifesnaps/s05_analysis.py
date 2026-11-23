"""Step 5-6: associations, grouped cross-validation, frozen EmoPhone model, personalisation check.

Inputs (private, DERIVED): labels.csv, ext_features.csv (s03), v1_features.csv (s04).
Output: OUT/results.json and a printed summary - aggregate numbers only.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy.stats import spearmanr  # noqa: E402
from sklearn.linear_model import LogisticRegression  # noqa: E402
from sklearn.metrics import roc_auc_score  # noqa: E402

F = C.F
RNG = np.random.default_rng(0)
B = 1000  # participant bootstrap replicates

lab = pd.read_csv(C.DERIVED / "labels.csv")
ext = pd.read_csv(C.DERIVED / "ext_features.csv")
v1 = pd.read_csv(C.DERIVED / "v1_features.csv")
df = lab.merge(ext, on="label_id", how="left").merge(v1, on="label_id", how="left")
res = {}

TIME = ["hour_sin", "hour_cos", "weekend"]
HRST = ["z_hr_15", "z_hr_30", "z_hr_60", "zb_hr_30", "z_log_steps_15", "z_log_steps_30",
        "z_log_steps_60"]
SLEEP_EST = ["z_sleep_min", "hours_since_wake", "sleep_unknown"]
SLEEP_MEAS = ["z_sleep_min_meas", "hours_since_wake_meas", "sleep_unknown_meas"]
NIGHT = ["z_rmssd", "z_nremhr", "z_rhr_prev", "z_deep_share", "z_rem_share", "z_efficiency",
         "z_temp", "z_br", "z_spo2"]
SETS = {
    "(i) time only": TIME,
    "(ii) time + HR + steps": TIME + HRST,
    "(ii) Harmony v1, 13 (estimated sleep)": TIME + HRST + SLEEP_EST,
    "(ii') Harmony v1, measured sleep": TIME + HRST + SLEEP_MEAS,
    "(iii) (ii') + extended night signals": TIME + HRST + SLEEP_MEAS + NIGHT,
    "(iv) time + extended night signals": TIME + SLEEP_MEAS + NIGHT,
}


def boot_ci(stat_fn, groups, B=B):
    """Participant (cluster) bootstrap 95% interval of stat_fn(index array)."""
    ids = np.unique(groups)
    pos = {g: np.flatnonzero(groups == g) for g in ids}
    vals = []
    for _ in range(B):
        pick = RNG.choice(ids, len(ids), replace=True)
        idx = np.concatenate([pos[g] for g in pick])
        try:
            vals.append(stat_fn(idx))
        except ValueError:
            pass
    return [round(float(np.nanpercentile(vals, 2.5)), 3), round(float(np.nanpercentile(vals, 97.5)), 3)]


# ---------- inventory at the answers ----------
res["coverage_at_answers"] = {
    c: {"participants_with_known_value": int(df.loc[df[c].notna(), "u"].nunique()),
        "known_share_of_answers": round(float(df[c].notna().mean()), 3)}
    for c in NIGHT + ["z_sleep_min_meas", "z_hr_30", "z_log_steps_30", "z_sleep_min", "hours_since_wake"]}

# estimated sleep (Harmony's Fitbit HR estimator) vs Fitbit's measured sleep, at the answers
agree = {}
for a, b in (("z_sleep_min", "z_sleep_min_meas"), ("hours_since_wake", "hours_since_wake_meas")):
    d = df[[a, b]].dropna()
    agree[f"{a} vs {b}"] = {"answers": int(len(d)), "spearman": round(float(spearmanr(d[a], d[b]).statistic), 3)}
d = df[["sleep_unknown", "sleep_unknown_meas"]]
agree["unknown night agreement"] = round(float((d["sleep_unknown"] == d["sleep_unknown_meas"]).mean()), 3)
res["estimated_vs_measured_sleep"] = agree

# ---------- 5a. associations: previous-night signal -> mood (within person) ----------
assoc = {}
for target in ("act_high", "val_high"):
    for s in NIGHT + ["z_sleep_min_meas"]:
        d = df[[s, target, "u"]].dropna()
        if d["u"].nunique() < 10:
            continue
        y, x, g = d[target].to_numpy(), d[s].to_numpy(), d["u"].to_numpy()
        auc = roc_auc_score(y, x)
        ci = boot_ci(lambda i: roc_auc_score(y[i], x[i]), g)
        assoc[f"{target} ~ {s}"] = {"labels": int(len(d)), "participants": int(d["u"].nunique()),
                                    "auroc_signal_alone": round(float(auc), 3), "ci95": ci}
res["label_level_auroc_of_single_night_signal"] = assoc

# day level: daily mean of mapped scores vs night z (Spearman), pooled and per person
day = df.groupby(["u", "date"]).agg(arousal=("arousal", "mean"), valence=("valence", "mean"),
                                     n=("arousal", "size"),
                                     **{s: (s, "first") for s in NIGHT + ["z_sleep_min_meas"]}
                                     ).reset_index()
for c in ("arousal", "valence"):
    day[c + "_c"] = day[c] - day.groupby("u")[c].transform("mean")
dayres = {}
for target in ("arousal_c", "valence_c"):
    for s in NIGHT + ["z_sleep_min_meas"]:
        d = day[[s, target, "u"]].dropna()
        if d["u"].nunique() < 10:
            continue
        rho = spearmanr(d[s], d[target]).statistic
        per = []
        for _, g in d.groupby("u"):
            if len(g) >= 10 and g[s].std() > 0 and g[target].std() > 0:
                per.append(np.arctanh(np.clip(spearmanr(g[s], g[target]).statistic, -0.99, 0.99)))
        x, yv, gg = d[s].to_numpy(), d[target].to_numpy(), d["u"].to_numpy()
        ci = boot_ci(lambda i: spearmanr(x[i], yv[i]).statistic, gg)
        dayres[f"{target} ~ {s}"] = {
            "days": int(len(d)), "participants": int(d["u"].nunique()),
            "pooled_within_spearman": round(float(rho), 3), "ci95": ci,
            "persons_with_10_days": len(per),
            "mean_person_rho": round(float(np.tanh(np.mean(per))), 3) if per else None,
            "sd_person_rho": round(float(np.std(np.tanh(per))), 3) if per else None}
res["day_level_spearman"] = dayres

# ---------- 5b. grouped 5-fold CV ----------
hr_people = df.loc[df["z_hr_30"].notna(), "u"].unique()
cvres = {}
for target in ("act_high", "val_high", "act_strict", "val_strict"):
    d = df[df["u"].isin(hr_people) & df[target].notna()].reset_index(drop=True)
    y = d[target].to_numpy().astype(int)
    splits = C.folds(d["u"])
    per_set = {}
    for name, cols in SETS.items():
        x = d[cols].to_numpy(float)
        fold = []
        for tr, te in splits:
            m = C.make_model().fit(x[tr], y[tr])
            fold.append(C.scores(y[te], m.predict_proba(x[te])[:, 1]))
        per_set[name] = np.array(fold)
    base = per_set["(i) time only"][:, 0]
    out = {"labels": int(len(d)), "participants": int(d["u"].nunique()),
           "positive_share": round(float(y.mean()), 3)}
    for name, f in per_set.items():
        out[name] = {"auroc": f"{f[:, 0].mean():.3f} ± {f[:, 0].std():.3f}",
                     "bal_acc": f"{f[:, 1].mean():.3f} ± {f[:, 1].std():.3f}"}
    for a, b in [("(ii) time + HR + steps", "(i) time only"),
                 ("(ii) Harmony v1, 13 (estimated sleep)", "(i) time only"),
                 ("(ii') Harmony v1, measured sleep", "(ii) Harmony v1, 13 (estimated sleep)"),
                 ("(iii) (ii') + extended night signals", "(ii') Harmony v1, measured sleep"),
                 ("(iv) time + extended night signals", "(i) time only")]:
        diff = per_set[a][:, 0] - per_set[b][:, 0]
        out[f"diff {a} - {b}"] = f"{diff.mean():+.3f} ± {diff.std():.3f} (folds > 0: {(diff > 0).sum()}/5)"
    cvres[target] = out
res["grouped_cv"] = cvres

# ---------- 6. frozen EmoPhone model as an external test ----------
params = json.load(open(C.PARAMS))
assert params["features"] == list(F.FEATURES)
d = df[df["u"].isin(hr_people)].reset_index(drop=True)
y = d["act_high"].to_numpy().astype(int)
g = d["u"].to_numpy()
ext_test = {"labels": int(len(d)), "participants": int(d["u"].nunique())}
variants = {
    "frozen 13-feature model (estimated sleep, as trained)": (params, list(F.FEATURES)),
    "frozen 13-feature model, measured Fitbit sleep in the 3 sleep slots": (
        params, TIME + HRST + SLEEP_MEAS),
    "frozen time_only block": (params["time_only"], TIME),
}
for name, (p, cols) in variants.items():
    prob = C.predict_params(p, d[cols].to_numpy(float))
    auc, bacc = C.scores(y, prob)
    ci = boot_ci(lambda i: roc_auc_score(y[i], prob[i]), g)
    fold_auc = [roc_auc_score(y[te], prob[te]) for _, te in C.folds(d["u"])]
    ext_test[name] = {"auroc": round(float(auc), 3), "ci95": ci, "bal_acc": round(float(bacc), 3),
                      "auroc_same_5_folds": f"{np.mean(fold_auc):.3f} ± {np.std(fold_auc):.3f}"}
res["frozen_emophone_external_test"] = ext_test

# ---------- (c) personalisation check: population prior vs personal data ----------
cols = TIME + HRST + SLEEP_MEAS + NIGHT
pers = {}
for target in ("act_high", "val_high"):
    d = df[df["u"].isin(hr_people) & df[target].notna()].sort_values(["u", "t_local_ms"])
    d = d.reset_index(drop=True)
    y, x = d[target].to_numpy().astype(int), d[cols].to_numpy(float)
    rows = {k: [] for k in ("population", "personal only", "blend k=30")}
    pooled = {k: ([], []) for k in rows}
    for tr, te in C.folds(d["u"]):
        pop = C.make_model().fit(x[tr], y[tr])
        te_df = d.iloc[te]
        for u, gi in te_df.groupby("u").groups.items():
            gi = np.asarray(sorted(gi))
            if len(gi) < 40:
                continue
            half = len(gi) // 2
            a, b = gi[:half], gi[half:]
            if len(np.unique(y[b])) < 2 or len(np.unique(y[a])) < 2:
                continue
            p_pop = pop.predict_proba(x[b])[:, 1]
            own = C.make_model().set_params(logisticregression__C=0.1).fit(x[a], y[a])
            p_own = own.predict_proba(x[b])[:, 1]
            n, k = len(a), 30
            lo = lambda p: np.log(np.clip(p, 1e-6, 1 - 1e-6) / (1 - np.clip(p, 1e-6, 1 - 1e-6)))
            p_blend = 1 / (1 + np.exp(-((k * lo(p_pop) + n * lo(p_own)) / (n + k))))
            for name, p in (("population", p_pop), ("personal only", p_own),
                            ("blend k=30", p_blend)):
                rows[name].append(roc_auc_score(y[b], p))
                pooled[name][0].append(y[b]); pooled[name][1].append(p)
    pers[target] = {"participants_with_40_labels": len(rows["population"])}
    for name in rows:
        r = np.array(rows[name])
        pers[target][name] = {
            "mean_person_auroc": f"{r.mean():.3f} ± {r.std():.3f}",
            "pooled_auroc": round(float(roc_auc_score(np.concatenate(pooled[name][0]),
                                                      np.concatenate(pooled[name][1]))), 3)}
res["personalisation_second_half"] = pers

json.dump(res, open(C.OUT / "results.json", "w"), indent=1, ensure_ascii=False)
print(json.dumps(res, indent=1, ensure_ascii=False))
