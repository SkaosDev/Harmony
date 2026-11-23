"""Step 4: Harmony features v1 at each LifeSnaps mood answer, with ml/features.py unchanged.

Input: DERIVED/labels.csv (from s03), DERIVED/heart_rate.npz, DERIVED/steps.npz.
Times are local wall clock; they are shifted by -9 h so that features.py (which adds Korea's
+9 h) sees the right local hour (common.local_naive_to_ms).
Output: DERIVED/v1_features.csv (one row per answer; private) and aggregate coverage in OUT.
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

F = C.F
labels = pd.read_csv(C.DERIVED / "labels.csv")
hr = np.load(C.DERIVED / "heart_rate.npz")
st = np.load(C.DERIVED / "steps.npz")


def by_user(a):
    order = np.lexsort((a["t_local_ms"], a["u"]))
    u, t, v = a["u"][order], a["t_local_ms"][order] - F.KST_MS, a["v"][order].astype(float)
    cuts = np.flatnonzero(np.diff(u)) + 1
    return {int(uu[0]): (tt, vv) for uu, tt, vv in zip(np.split(u, cuts), np.split(t, cuts),
                                                       np.split(v, cuts))}


HR, ST = by_user(hr), by_user(st)
rows, t0 = [], time.time()
for u, g in labels.groupby("u"):
    if u not in HR:
        continue  # no heart rate at all for this participant: features unknown, skipped
    hr_ts, hr_v = HR[u]
    st_ts, st_v = ST.get(u, (np.zeros(0, np.int64), np.zeros(0)))
    t = g["t_local_ms"].to_numpy(np.int64) - F.KST_MS
    feats = F.participant_features(t, hr_ts, hr_v, st_ts, st_v, F.sleep_threshold(hr_ts, hr_v))
    out = pd.DataFrame(feats, index=g.index)
    rows.append(out)
v1 = pd.concat(rows).reindex(labels.index)
v1.insert(0, "label_id", labels["label_id"])
v1.to_csv(C.DERIVED / "v1_features.csv", index=False)
cov = {"answers": int(len(labels)), "answers_with_hr_participant": int(v1["hour_sin"].notna().sum()),
       "unknown_share": {c: round(float(v1[c].isna().mean()), 3) for c in F.FEATURES},
       "sleep_unknown_share": round(float((v1["sleep_unknown"] == 1).mean()), 3),
       "seconds": round(time.time() - t0)}
json.dump(cov, open(C.OUT / "v1_coverage.json", "w"), indent=1)
print(json.dumps(cov, indent=1))
