"""Reproduce the first results on EmoPhone wave D-1 (Table VII of Submission B).

Usage:
    python ml/explore_d1.py --data /path/to/dataverse_files/D1

The folder must contain EsmResponse.csv and Sensor/D1_Sensor_Pxxx.tar.gz.
The EmoPhone files are never copied into this repository (NFR9).

What it does, for every mood answer (ESM) of every participant:
  1. heart rate (Fitbit) and steps in the 15, 30 and 60 minutes before the answer;
  2. last night's sleep, estimated from the Fitbit (EmoPhone has no measured sleep);
  3. z-scores against the participant's own values;
  4. label = 1 when the answer is above the participant's own mean;
  5. 5-fold cross-validation grouped by participant (people kept apart).
"""
import argparse
import os
import tarfile

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import balanced_accuracy_score, roc_auc_score
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

KST_MS = 9 * 3600 * 1000  # timestamps are UTC; Korea is UTC+9
MIN_MS = 60_000
WINDOWS = (15, 30, 60)    # minutes before the mood answer
NEEDED = {"Fitbit-HeartRate.csv", "Fitbit-StepCount.csv"}


def read_participant(path):
    """Return the Fitbit heart-rate and step tables of one participant archive."""
    tables = {}
    with tarfile.open(path, "r:gz") as tf:
        for member in tf:
            name = os.path.basename(member.name)
            if name in NEEDED:
                tables[name] = pd.read_csv(tf.extractfile(member)).sort_values("timestamp")
    return tables.get("Fitbit-HeartRate.csv"), tables.get("Fitbit-StepCount.csv")


def window(ts, values, t, minutes):
    lo = np.searchsorted(ts, t - minutes * MIN_MS, "left")
    hi = np.searchsorted(ts, t, "right")
    return values[lo:hi]


def answer_features(pcode, answers, hr, st):
    """Heart rate and steps before each answer; also a sparse heart rate (1 reading / 5 min)."""
    hr_ts, hr_v = hr.timestamp.values, hr.value.values
    st_ts = st.timestamp.values if st is not None else np.array([], dtype=np.int64)
    st_v = st.value.values if st is not None else np.array([])
    sparse = hr.assign(bin=hr.timestamp // (5 * MIN_MS)).groupby("bin").first()
    sp_ts, sp_v = sparse.timestamp.values, sparse.value.values
    rows = []
    for t, arousal, stress in answers[["actualTriggerTime", "arousal", "stress"]].values:
        r = {"pcode": pcode, "t": t, "arousal": arousal, "stress": stress}
        for w in WINDOWS:
            v = window(hr_ts, hr_v, t, w)
            r[f"hr_n_{w}"] = len(v)
            r[f"hr_mean_{w}"] = v.mean() if len(v) else np.nan
            if w == 30:
                r["hr_std_30"] = v.std() if len(v) > 2 else np.nan
            s = window(st_ts, st_v, t, w)
            r[f"steps_{w}"] = s.sum() if len(s) else np.nan
            sv = window(sp_ts, sp_v, t, w)
            r[f"s_hr_{w}"] = sv.mean() if len(sv) else np.nan
        rows.append(r)
    return rows


def night_sleep(pcode, days, hr, st):
    """Estimate last night's sleep the way watches do.

    Window 21:00 (previous day) -> 12:00, local time. A minute counts as asleep when the
    watch is worn (heart rate present), there are no steps and the heart rate is in the
    participant's lowest 30% (+5%). The night is the longest run of such minutes, gaps of
    up to 30 min merged, lasting at least 2 h. If heart rate covers less than 60% of the
    window, the watch was not worn and sleep is unknown (never zero).
    """
    hm = hr.assign(m=(hr.timestamp + KST_MS) // MIN_MS).groupby("m").value.mean()
    threshold = hm.quantile(0.30)
    if st is not None:
        sm = st.assign(m=(st.timestamp + KST_MS) // MIN_MS).groupby("m").value.sum()
    else:
        sm = pd.Series(dtype=float)
    rows = []
    for d in days:
        d0 = int(pd.Timestamp(d).value // 10**6 // MIN_MS)       # local midnight, in minutes
        minutes = np.arange(d0 - 3 * 60, d0 + 12 * 60)
        h = hm.reindex(minutes).values
        s = sm.reindex(minutes).fillna(0).values
        worn = ~np.isnan(h)
        asleep = worn & (s == 0) & (np.nan_to_num(h, nan=999) <= threshold * 1.05)
        r = {"pcode": pcode, "day": str(pd.Timestamp(d).date()), "night_worn": worn.mean()}
        best, start, last = (0, None, None), None, None
        for i, a in enumerate(asleep):
            if a:
                if start is None or i - last > 30:
                    start = i
                last = i
                if last - start + 1 > best[0]:
                    best = (last - start + 1, start, last)
        if r["night_worn"] >= 0.6 and best[0] >= 120:
            r["sleep_min"] = int(asleep[best[1]:best[2] + 1].sum())
            r["wake_min"] = int(minutes[best[2]])
        rows.append(r)
    return rows


def build_table(data_dir):
    esm = pd.read_csv(os.path.join(data_dir, "EsmResponse.csv"))
    answers, nights = [], []
    for fn in sorted(os.listdir(os.path.join(data_dir, "Sensor"))):
        pcode = fn.split("_")[2].split(".")[0]
        e = esm[esm.pcode == pcode]
        if e.empty:
            continue
        hr, st = read_participant(os.path.join(data_dir, "Sensor", fn))
        if hr is None:
            continue
        answers += answer_features(pcode, e, hr, st)
        days = pd.to_datetime(e.actualTriggerTime + KST_MS, unit="ms").dt.normalize().unique()
        nights += night_sleep(pcode, days, hr, st)
    f = pd.DataFrame(answers)
    local = pd.to_datetime(f.t + KST_MS, unit="ms")
    f["day"] = local.dt.normalize().dt.date.astype(str)
    f = f.merge(pd.DataFrame(nights), on=["pcode", "day"], how="left")
    return f.sort_values(["pcode", "t"]).reset_index(drop=True)


def add_model_inputs(f):
    local = pd.to_datetime(f.t + KST_MS, unit="ms")
    hour = local.dt.hour + local.dt.minute / 60
    f["hour_sin"], f["hour_cos"] = np.sin(2 * np.pi * hour / 24), np.cos(2 * np.pi * hour / 24)
    f["weekend"] = (local.dt.dayofweek >= 5).astype(int)
    f["block"] = local.dt.hour // 3
    f["date"] = local.dt.date.astype(str)
    # watch worn but no step rows = 0 steps; watch not worn = unknown
    worn = f.hr_n_30 > 0
    for w in WINDOWS:
        f.loc[worn & f[f"steps_{w}"].isna(), f"steps_{w}"] = 0
        f[f"log_steps_{w}"] = np.log1p(f[f"steps_{w}"])
    f.loc[f.hr_n_15 < 5, "hr_mean_15"] = np.nan
    f.loc[f.hr_n_30 < 10, ["hr_mean_30", "hr_std_30"]] = np.nan
    g = f.groupby("pcode")
    z = lambda c: (f[c] - g[c].transform("mean")) / g[c].transform("std")
    for c in ["hr_mean_15", "hr_mean_30", "hr_mean_60", "hr_std_30",
              "log_steps_15", "log_steps_30", "log_steps_60",
              "s_hr_15", "s_hr_30", "s_hr_60", "sleep_min"]:
        f["z_" + c] = z(c)
    for c in ["hr_mean_30", "s_hr_30"]:   # heart rate against the same 3-hour block
        f["zb_" + c] = (f[c] - f.groupby(["pcode", "block"])[c].transform("mean")) / g[c].transform("std")
    minute = (f.t + KST_MS) // MIN_MS
    f["hours_since_wake"] = ((minute - f.wake_min) / 60).where(lambda x: x >= 0)
    f["sleep_unknown"] = f.sleep_min.isna().astype(int)
    for label in ["arousal", "stress"]:
        f[label + "_high"] = (f[label] > g[label].transform("mean")).astype(int)
    return f


TIME = ["hour_sin", "hour_cos", "weekend"]
HR = ["z_hr_mean_15", "z_hr_mean_30", "z_hr_mean_60", "z_hr_std_30", "zb_hr_mean_30"]
STEPS = ["z_log_steps_15", "z_log_steps_30", "z_log_steps_60"]
SLEEP = ["z_sleep_min", "hours_since_wake", "sleep_unknown"]
HR_SPARSE = ["z_s_hr_15", "z_s_hr_30", "z_s_hr_60", "zb_s_hr_30"]


def evaluate(f, cols, label, kind="LR"):
    y, x = f[label + "_high"].values, f[cols].values
    auc, bal = [], []
    for tr, te in GroupKFold(n_splits=5).split(x, y, f.pcode):
        if kind == "LR":
            m = make_pipeline(SimpleImputer(strategy="median"), StandardScaler(),
                              LogisticRegression(max_iter=1000))
        else:
            m = HistGradientBoostingClassifier(max_iter=200, learning_rate=0.05,
                                               max_leaf_nodes=15, min_samples_leaf=50)
        m.fit(x[tr], y[tr])
        p = m.predict_proba(x[te])[:, 1]
        auc.append(roc_auc_score(y[te], p))
        bal.append(balanced_accuracy_score(y[te], p > 0.5))
    return np.mean(auc), np.std(auc), np.mean(bal)


def others_same_time(f, label):
    """Mood of the other participants at the same date and 3-hour block (shared effects)."""
    y, auc = f[label + "_high"].values, []
    for tr, te in GroupKFold(n_splits=5).split(f, y, f.pcode):
        enc = f.iloc[tr].groupby(["date", "block"])[label + "_high"].mean().to_dict()
        keys = list(zip(f.iloc[te].date, f.iloc[te].block))
        p = np.array([enc.get(k, y[tr].mean()) for k in keys])
        auc.append(roc_auc_score(y[te], p))
    return np.mean(auc), np.std(auc)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="folder with EsmResponse.csv and Sensor/")
    args = ap.parse_args()
    f = add_model_inputs(build_table(args.data))
    print(f"{len(f)} answers, {f.pcode.nunique()} participants, "
          f"nights with sleep: {1 - f.sleep_unknown.mean():.2f}")
    runs = [("arousal", "time of day only", TIME, "LR"),
            ("arousal", "time + sleep", TIME + SLEEP, "LR"),
            ("arousal", "time + heart rate", TIME + HR, "LR"),
            ("arousal", "time + heart rate + steps", TIME + HR + STEPS, "LR"),
            ("arousal", "time + heart rate + steps + sleep (our model)", TIME + HR + STEPS + SLEEP, "LR"),
            ("arousal", "same, gradient-boosted trees", TIME + HR + STEPS + SLEEP, "HGB"),
            ("arousal", "time + heart rate, one reading every 5 min", TIME + HR_SPARSE, "LR"),
            ("stress", "our model", TIME + HR + STEPS + SLEEP, "LR")]
    for label, name, cols, kind in runs:
        a, s, b = evaluate(f, cols, label, kind)
        print(f"{label:8s} {name:48s} AUROC {a:.3f} ± {s:.3f}  bal.acc {b:.3f}")
    a, s = others_same_time(f, "arousal")
    print(f"{'arousal':8s} {'other participants at same date and time':48s} AUROC {a:.3f} ± {s:.3f}")


if __name__ == "__main__":
    main()
