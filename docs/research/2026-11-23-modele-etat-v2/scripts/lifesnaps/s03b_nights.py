"""Step 3b: one row per participant x night (wake date) from the raw Fitbit types, then the
extended night features at each mood answer (past-only 14-night baselines, unknown != 0).

Inputs: DERIVED/types/fitbit__*.csv (s02), DERIVED/labels.csv (s03a), DERIVED/heart_rate.npz.
Outputs: DERIVED/nights.csv, DERIVED/ext_features.csv (private); OUT/nights_inventory.json.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

T = C.DERIVED / "types"
DAY = pd.Timedelta(days=1)


def load(name):
    p = T / f"fitbit__{name}.csv"
    return pd.read_csv(p, low_memory=False) if p.exists() else None


def naive(s):
    d = pd.to_datetime(s, format="mixed")
    return d.dt.tz_localize(None) if d.dt.tz is not None else d  # "Z" dates are labels, not UTC


def day_of(s):
    return naive(s).dt.normalize()


inv = {}
# --- sleep: main sleep of each night, keyed by its wake date (dateOfSleep) ---
sl = load("sleep")
sl = sl[sl["mainSleep"].astype(str).str.lower() == "true"].copy()
sl["date"] = day_of(sl["dateOfSleep"])
sl["start"] = naive(sl["startTime"])
sl["end"] = naive(sl["endTime"])
stages = sl["type"].astype(str) == "stages"
for st in ("deep", "light", "rem", "wake"):
    c = f"levels.summary.{st}.minutes"
    sl[st] = np.where(stages, pd.to_numeric(sl.get(c), errors="coerce"), np.nan)
asleep_stage = sl[["deep", "light", "rem"]].sum(axis=1, min_count=3)
sl["deep_share"] = sl["deep"] / asleep_stage
sl["rem_share"] = sl["rem"] / asleep_stage
sl["sleep_min"] = pd.to_numeric(sl["minutesAsleep"], errors="coerce")
sl["efficiency"] = pd.to_numeric(sl["efficiency"], errors="coerce")
sl = sl.sort_values("sleep_min").drop_duplicates(["_u", "date"], keep="last")
nights = sl[["_u", "date", "start", "end", "sleep_min", "efficiency", "deep_share", "rem_share"]]
inv["sleep_logs_main"] = int(len(sl))
inv["sleep_logs_with_stages_share"] = round(float(stages.mean()), 3)


def nightly(name, date_col, cols, rename):
    d = load(name)
    if d is None:
        inv[f"missing type {name}"] = True
        return None
    d = d.copy()
    d["date"] = day_of(d[date_col])
    for c in cols:
        d[c] = pd.to_numeric(d[c], errors="coerce")
    d = d.groupby(["_u", "date"])[cols].mean().reset_index().rename(columns=rename)
    return d


parts = [
    nightly("Daily_Heart_Rate_Variability_Summary", "timestamp", ["rmssd", "nremhr"], {}),
    nightly("Respiratory_Rate_Summary", "timestamp", ["full_sleep_breathing_rate"],
            {"full_sleep_breathing_rate": "br"}),
    nightly("Daily_SpO2", "timestamp", ["average_value"], {"average_value": "spo2"}),
]
temp = load("Computed_Temperature")
if temp is not None:
    temp = temp[temp["type"].astype(str) == "SKIN"].copy()
    temp["date"] = day_of(temp["sleep_end"])
    temp["temp"] = pd.to_numeric(temp["nightly_temperature"], errors="coerce")
    parts.append(temp.groupby(["_u", "date"])[["temp"]].mean().reset_index())
rhr = load("resting_heart_rate")
if rhr is not None:
    rhr = rhr.copy()
    rhr["date"] = day_of(rhr["value.date"] if "value.date" in rhr else rhr["dateTime"])
    rhr["rhr"] = pd.to_numeric(rhr["value.value"], errors="coerce")
    rhr.loc[rhr["rhr"] <= 0, "rhr"] = np.nan  # 0 = not computed: unknown, never a value
    rhr = rhr.groupby(["_u", "date"])[["rhr"]].mean().reset_index()
    rhr["date"] = rhr["date"] + DAY  # yesterday's resting HR is known at today's answers
    parts.append(rhr.rename(columns={"rhr": "rhr_prev"}))
for p in parts:
    if p is not None:
        nights = nights.merge(p, on=["_u", "date"], how="outer")
nights = nights.rename(columns={"_u": "u"}).sort_values(["u", "date"]).reset_index(drop=True)
nights.to_csv(C.DERIVED / "nights.csv", index=False)

SIG = {"sleep_min": "z_sleep_min_meas", "rmssd": "z_rmssd", "nremhr": "z_nremhr",
       "rhr_prev": "z_rhr_prev", "deep_share": "z_deep_share", "rem_share": "z_rem_share",
       "efficiency": "z_efficiency", "temp": "z_temp", "br": "z_br", "spo2": "z_spo2"}
cov = {}
for s in SIG:
    g = nights.loc[nights[s].notna()].groupby("u").size()
    cov[s] = {"participants": int(g.size), "nights_total": int(g.sum()),
              "nights_per_participant_median": float(g.median()) if g.size else None}
inv["night_signal_coverage"] = cov

# --- features at each answer ---
lab = pd.read_csv(C.DERIVED / "labels.csv")
lab["t"] = pd.to_datetime(lab["t_local_ms"], unit="ms")
lab["day"] = lab["t"].dt.normalize()
N = {u: g.set_index("date") for u, g in nights.groupby("u")}
out = []
for r in lab.itertuples():
    rec = {"label_id": r.label_id}
    g = N.get(r.u)
    night = r.day
    if g is not None and night in g.index and pd.notna(g.at[night, "end"]):
        if r.t < g.at[night, "end"]:
            night = night - DAY  # answered before getting up from this night: use the previous one
    elif r.t.hour < 6:
        night = night - DAY
    for s, z in SIG.items():
        rec[z] = np.nan
        if g is None:
            continue
        past = g.loc[(g.index >= night - 14 * DAY) & (g.index < night), s].dropna()
        val = g.at[night, s] if night in g.index else np.nan
        if len(past) >= C.F.MIN_KNOWN_NIGHTS and pd.notna(val) and past.std(ddof=1) > 0:
            rec[z] = (val - past.mean()) / past.std(ddof=1)
    # measured-sleep versions of Harmony's three sleep slots (as the app reads Apple sleep)
    end = g.at[night, "end"] if (g is not None and night in g.index) else pd.NaT
    known = g is not None and night in g.index and pd.notna(g.at[night, "sleep_min"])
    rec["sleep_unknown_meas"] = 0 if known else 1
    rec["hours_since_wake_meas"] = ((r.t - end).total_seconds() / 3600
                                    if known and pd.notna(end) and r.t >= end else np.nan)
    out.append(rec)
ext = pd.DataFrame(out)
ext.to_csv(C.DERIVED / "ext_features.csv", index=False)
inv["answers"] = int(len(ext))
inv["unknown_share_at_answers"] = {c: round(float(ext[c].isna().mean()), 3)
                                   for c in ext.columns if c != "label_id"}
json.dump(inv, open(C.OUT / "nights_inventory.json", "w"), indent=1, default=str)
print(json.dumps(inv, indent=1, default=str))
