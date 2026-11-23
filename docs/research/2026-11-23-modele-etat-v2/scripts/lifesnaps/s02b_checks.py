"""Aggregate checks of resolution and date conventions (no raw rows printed)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

T = C.DERIVED / "types"
res = {}
for name in ("heart_rate", "steps"):
    a = np.load(C.DERIVED / f"{name}.npz")
    o = np.lexsort((a["t_local_ms"], a["u"]))
    u, t, v = a["u"][o], a["t_local_ms"][o], a["v"][o]
    same = u[1:] == u[:-1]
    dt = np.diff(t)[same] / 1000
    days = pd.Series(t // 86_400_000).groupby(u).nunique()
    res[name] = {"rows": int(len(t)), "participants": int(len(np.unique(u))),
                 "interval_s_quantiles_10_50_90": [float(np.percentile(dt, q)) for q in (10, 50, 90)],
                 "days_with_data_per_participant_median_IQR": [float(days.median()), float(days.quantile(.25)), float(days.quantile(.75))],
                 "value_quantiles_1_50_99": [float(np.percentile(v, q)) for q in (1, 50, 99)],
                 "zero_share": round(float((v == 0).mean()), 3)}
    if name == "heart_rate":
        # resampled to Harmony's first reading per 5-min slot: readings per day worn
        slot = t // 300_000
        first = np.r_[True, (slot[1:] != slot[:-1]) | (u[1:] != u[:-1])]
        res[name]["slots_5min_with_reading_per_day_median"] = float(
            pd.Series(first.astype(int)).groupby([u, t // 86_400_000]).sum().median())


def dates(s):
    return pd.to_datetime(s, format="mixed").dt.normalize()


sl = pd.read_csv(T / "fitbit__sleep.csv", low_memory=False)
res["sleep"] = {"logs": int(len(sl)), "mainSleep_share": round(float((sl["mainSleep"].astype(str).str.lower() == "true").mean()), 3),
                "type_counts": sl["type"].astype(str).value_counts().to_dict(),
                "minutesAsleep_median": float(sl["minutesAsleep"].median())}
main = sl[sl["mainSleep"].astype(str).str.lower() == "true"].copy()
main["wake"] = dates(main["dateOfSleep"])
main["endday"] = dates(main["endTime"])
res["sleep"]["dateOfSleep_equals_end_date_share"] = round(float((main["wake"] == main["endday"]).mean()), 3)
keys = set(zip(main["_u"], main["wake"]))
for f, col in (("Daily_Heart_Rate_Variability_Summary", "timestamp"), ("Respiratory_Rate_Summary", "timestamp"),
               ("Daily_SpO2", "timestamp"), ("Computed_Temperature", "sleep_end"), ("Computed_Temperature", "sleep_start"),
               ("resting_heart_rate", "value.date")):
    d = pd.read_csv(T / f"fitbit__{f}.csv", low_memory=False)
    dd = dates(d[col])
    same = np.mean([(u, x) in keys for u, x in zip(d["_u"], dd)])
    prev = np.mean([(u, x + pd.Timedelta(days=1)) in keys for u, x in zip(d["_u"], dd)])
    res[f"{f}.{col}"] = {"rows": int(len(d)), "matches_main_sleep_wake_date": round(float(same), 3),
                         "matches_wake_date_minus_1": round(float(prev), 3),
                         "time_of_day_examples_hours": sorted(pd.to_datetime(d[col], format="mixed").dt.hour.value_counts().head(3).index.tolist())}
ct = pd.read_csv(T / "fitbit__Computed_Temperature.csv", low_memory=False)
res["Computed_Temperature"] = {"type_counts": ct["type"].astype(str).value_counts().to_dict(),
                               "nightly_temperature_quantiles_5_50_95": [round(float(ct["nightly_temperature"].quantile(q)), 2) for q in (.05, .5, .95)]}
rhr = pd.read_csv(T / "fitbit__resting_heart_rate.csv", low_memory=False)
res["resting_heart_rate"] = {"rows": int(len(rhr)), "zero_or_missing_share": round(float((pd.to_numeric(rhr["value.value"], errors="coerce").fillna(0) <= 0).mean()), 3),
                             "rows_per_participant_day": round(float(len(rhr) / rhr.groupby(["_u", "value.date"]).ngroups), 2)}
hrv = pd.read_csv(T / "fitbit__Heart_Rate_Variability_Details.csv", low_memory=False)
ht = pd.to_datetime(hrv["timestamp"], format="mixed")
res["HRV_details"] = {"rows": int(len(hrv)), "hour_counts_top": ht.dt.hour.value_counts().head(6).to_dict(),
                      "rows_per_night_median": float(hrv.groupby(["_u", ht.dt.normalize()]).size().median())}
json.dump(res, open(C.OUT / "resolution_checks.json", "w"), indent=1, default=str)
print(json.dumps(res, indent=1, default=str))
