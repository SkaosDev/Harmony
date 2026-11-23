"""Extra checks (aggregate only): why the frozen model fails, time-of-day profile, coefficient
signs, sampling noise of per-person correlations, repeated grouped CV of the key differences."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy.stats import spearmanr  # noqa: E402
from sklearn.metrics import roc_auc_score  # noqa: E402

F = C.F
lab = pd.read_csv(C.DERIVED / "labels.csv")
ext = pd.read_csv(C.DERIVED / "ext_features.csv")
v1 = pd.read_csv(C.DERIVED / "v1_features.csv")
df = lab.merge(ext, on="label_id").merge(v1, on="label_id")
hr_people = df.loc[df["z_hr_30"].notna(), "u"].unique()
d = df[df["u"].isin(hr_people)].reset_index(drop=True)
y = d["act_high"].to_numpy().astype(int)
res = {}

# 1. time-of-day profile of the labels (SEMA windows)
win = pd.cut(d["hour"], [-1, 4, 12, 17, 24], labels=["night 0-4", "morning 5-12", "afternoon 13-17", "evening 18-23"])
prof = d.groupby(win, observed=True).agg(n=("act_high", "size"), act_high=("act_high", "mean"),
                                         val_high=("val_high", "mean"))
cat = pd.crosstab(win, d["mood"], normalize="index").round(3)
res["time_profile"] = {str(k): {"n": int(r.n), "act_high_share": round(r.act_high, 3),
                                "val_high_share": round(r.val_high, 3),
                                "mood_shares": cat.loc[k].to_dict()} for k, r in prof.iterrows()}

# 2. frozen EmoPhone model with the time block neutralised (time features at training means)
params = json.load(open(C.PARAMS))
x = d[list(F.FEATURES)].to_numpy(float)
xt = x.copy()
for i, f in enumerate(F.FEATURES):
    if f in ("hour_sin", "hour_cos", "weekend"):
        xt[:, i] = params["means"][i]
p_full = C.predict_params(params, x)
p_notime = C.predict_params(params, xt)
res["frozen_emophone"] = {"full_auroc": round(float(roc_auc_score(y, p_full)), 3),
                          "time_neutralised_auroc": round(float(roc_auc_score(y, p_notime)), 3)}
for f in ("z_hr_15", "z_hr_30", "z_hr_60", "zb_hr_30", "z_log_steps_30", "z_sleep_min", "hours_since_wake"):
    dd = d[[f, "act_high"]].dropna()
    res["frozen_emophone"][f"single feature AUROC {f}"] = round(float(roc_auc_score(dd["act_high"], dd[f])), 3)

# 3. coefficients of the 13-feature model fitted on all LifeSnaps answers (standardised scale)
m = C.make_model().fit(x, y)
coef = m.named_steps["logisticregression"].coef_[0]
res["lifesnaps_13_coefficients_vs_emophone"] = {
    f: {"lifesnaps": round(float(c), 3), "emophone": round(float(e), 3)}
    for f, c, e in zip(F.FEATURES, coef, params["coefficients"])}

# 4. sampling noise of per-person day-level correlations (is heterogeneity real?)
NIGHT = ["z_rmssd", "z_nremhr", "z_rhr_prev", "z_deep_share", "z_rem_share", "z_efficiency",
         "z_temp", "z_br", "z_spo2", "z_sleep_min_meas"]
day = df.groupby(["u", "date"]).agg(arousal=("arousal", "mean"), valence=("valence", "mean"),
                                     **{s: (s, "first") for s in NIGHT}).reset_index()
het = {}
for tgt in ("arousal", "valence"):
    day[tgt + "_c"] = day[tgt] - day.groupby("u")[tgt].transform("mean")
    for s in NIGHT:
        rhos, ns = [], []
        for _, g in day[[s, tgt + "_c", "u"]].dropna().groupby("u"):
            if len(g) >= 10 and g[s].std() > 0 and g[tgt + "_c"].std() > 0:
                rhos.append(spearmanr(g[s], g[tgt + "_c"]).statistic); ns.append(len(g))
        if rhos:
            het[f"{tgt} ~ {s}"] = {"persons": len(rhos), "observed_sd": round(float(np.std(rhos)), 3),
                                   "expected_sd_if_no_true_variation": round(float(np.sqrt(np.mean(1.06 / (np.array(ns) - 3)))), 3),
                                   "median_days": float(np.median(ns))}
res["per_person_correlation_heterogeneity"] = het

# 5. repeated grouped 5-fold CV (10 random assignments of whole participants to folds)
TIME = ["hour_sin", "hour_cos", "weekend"]
HRST = ["z_hr_15", "z_hr_30", "z_hr_60", "zb_hr_30", "z_log_steps_15", "z_log_steps_30", "z_log_steps_60"]
SM = ["z_sleep_min_meas", "hours_since_wake_meas", "sleep_unknown_meas"]
NI = ["z_rmssd", "z_nremhr", "z_rhr_prev", "z_deep_share", "z_rem_share", "z_efficiency", "z_temp", "z_br", "z_spo2"]
sets = {"time": TIME, "time+HR+steps": TIME + HRST, "v1_13": list(F.FEATURES),
        "v1_measured_sleep": TIME + HRST + SM, "v1_measured+night": TIME + HRST + SM + NI}
rng = np.random.default_rng(1)
rep = {}
for tgt in ("act_high", "val_high"):
    yy = d[tgt].to_numpy().astype(int)
    people = d["u"].unique()
    aucs = {k: [] for k in sets}
    for r in range(10):
        fold_of = dict(zip(people, rng.permutation(np.arange(len(people)) % 5)))
        f = d["u"].map(fold_of).to_numpy()
        for k in range(5):
            tr, te = f != k, f == k
            for name, cols in sets.items():
                xx = d[cols].to_numpy(float)
                mm = C.make_model().fit(xx[tr], yy[tr])
                aucs[name].append(roc_auc_score(yy[te], mm.predict_proba(xx[te])[:, 1]))
    a = {k: np.array(v) for k, v in aucs.items()}
    out = {k: f"{v.mean():.3f} ± {v.std():.3f}" for k, v in a.items()}
    for x1, x0 in (("time+HR+steps", "time"), ("v1_13", "time"), ("v1_measured_sleep", "v1_13"),
                   ("v1_measured+night", "v1_measured_sleep")):
        dif = a[x1] - a[x0]
        out[f"{x1} - {x0}"] = f"{dif.mean():+.4f} ± {dif.std():.4f}; folds > 0: {(dif > 0).sum()}/50"
    rep[tgt] = out
res["repeated_grouped_cv_10x5"] = rep
json.dump(res, open(C.OUT / "extra_checks.json", "w"), indent=1)
lines = []
for k, v in res.items():
    lines.append(f"== {k}")
    if isinstance(v, dict):
        for a, b in v.items():
            lines.append(f"  {a}: {b}")
open(C.OUT / "extra_compact.txt", "w").write("\n".join(lines) + "\n")
print(len(lines))
