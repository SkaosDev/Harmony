"""Step 3a: mood labels from SEMA3 (Context and Mood Survey), mapped to activation / pleasantness.

Usage: python -I -B s03a_labels.py <sema.bson>
Output: DERIVED/labels.csv (private) and OUT/labels_summary.json (aggregate only).
"""
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import bson  # noqa: E402

F = C.F
user_index = json.load(open(C.DERIVED / "user_index.json")) if (C.DERIVED / "user_index.json").exists() else None
C.DERIVED.mkdir(parents=True, exist_ok=True)
C.OUT.mkdir(parents=True, exist_ok=True)

rows, ts_shapes = [], collections.Counter()
for d in bson.decode_file_iter(open(sys.argv[1], "rb")):
    data = d.get("data") or {}
    if data.get("SURVEY_NAME") != "Context and Mood Survey":
        continue
    ts = data.get("COMPLETED_TS")
    if ts:
        ts_shapes[re.sub(r"\d", "9", ts)] += 1
    rows.append({"user": str(d.get("user_id")), "mood": data.get("MOOD"),
                 "scheduled": data.get("SCHEDULED_TS"), "completed": ts,
                 "study_version": data.get("STUDY_VERSION")})
s = pd.DataFrame(rows)
summary = {"context_mood_scheduled": int(len(s)), "participants_scheduled": int(s["user"].nunique()),
           "timestamp_patterns": dict(ts_shapes.most_common(3))}
s = s[s["completed"].notna()]
summary["completed"] = int(len(s))
summary["mood_counts_completed"] = s["mood"].astype(str).value_counts().to_dict()
s = s[s["mood"].isin(C.AROUSAL)].copy()
summary["usable_mood_answers"] = int(len(s))
t = pd.to_datetime(s["completed"].str.replace(r"\.\d+$", "", regex=True), format="mixed")
s["t_local_ms"] = t.astype("datetime64[ms]").astype("int64").to_numpy()
s["date"] = t.dt.strftime("%Y-%m-%d").to_numpy()
s["hour"] = t.dt.hour.to_numpy()
if user_index is not None:
    s["u"] = s["user"].map(user_index)
s["arousal"] = s["mood"].map(C.AROUSAL)
s["valence"] = s["mood"].map(C.VALENCE)
s["act_high"] = F.label_high(s["arousal"], s["user"])
s["val_high"] = F.label_high(s["valence"], s["user"])
s["act_strict"] = s["mood"].map(C.AROUSAL_STRICT)
s["val_strict"] = s["mood"].map(C.VALENCE_STRICT)
s = s.sort_values(["user", "t_local_ms"]).reset_index(drop=True)
s["label_id"] = np.arange(len(s))
# a participant whose answers are all the same category has no "above own mean" label
n_per = s.groupby("user").size()
summary.update({
    "participants_with_usable_answers": int(s["user"].nunique()),
    "answers_per_participant": {k: round(float(v), 1) for k, v in n_per.describe(
        percentiles=[.1, .25, .5, .75, .9]).items()},
    "participants_with_>=40_answers": int((n_per >= 40).sum()),
    "participants_with_>=100_answers": int((n_per >= 100).sum()),
    "answers_per_participant_day": round(float(s.groupby(["user", "date"]).size().mean()), 2),
    "distinct_days_per_participant_median": float(s.groupby("user")["date"].nunique().median()),
    "hour_of_day_counts": s["hour"].value_counts().sort_index().to_dict(),
    "act_high_share": round(float(s["act_high"].mean()), 3),
    "val_high_share": round(float(s["val_high"].mean()), 3),
    "act_strict_n_and_share": [int(s["act_strict"].notna().sum()), round(float(s["act_strict"].mean()), 3)],
    "val_strict_n_and_share": [int(s["val_strict"].notna().sum()), round(float(s["val_strict"].mean()), 3)],
    "participants_single_category": int((s.groupby("user")["mood"].nunique() == 1).sum()),
    "distinct_categories_per_participant_median": float(s.groupby("user")["mood"].nunique().median()),
    "date_range_months": sorted(s["date"].str[:7].unique().tolist()),
})
# within-person category shares (mean over participants), a hint of personal response styles
share = pd.crosstab(s["user"], s["mood"], normalize="index")
summary["mean_within_person_share"] = share.mean().round(3).to_dict()
summary["sd_between_person_share"] = share.std().round(3).to_dict()
cols = ["label_id", "user", "t_local_ms", "date", "hour", "mood", "arousal", "valence",
        "act_high", "val_high", "act_strict", "val_strict"] + (["u"] if user_index else [])
s[cols].to_csv(C.DERIVED / "labels.csv", index=False)
json.dump(summary, open(C.OUT / "labels_summary.json", "w"), indent=1)
print(json.dumps(summary, indent=1))
