"""Aggregate-only probe of ActivityEvent / Fitbit-Calorie / ActivityTransition format and cadence
on a few archives of D1 and D2 (no raw rows printed)."""
import sys, tarfile, os, time, glob
import numpy as np, pandas as pd
BASE = "/Users/clement/Hanyang/Harmony/data/emophone_data"
WANT = {"ActivityEvent.csv", "Fitbit-Calorie.csv", "ActivityTransition.csv", "Fitbit-HeartRate.csv"}
for w in ("D1", "D2"):
    arcs = sorted(glob.glob(f"{BASE}/{w}/Sensor/*.tar.gz"))
    for a in arcs[3:6]:
        t0 = time.time(); tabs = {}
        with tarfile.open(a, "r:gz") as tf:
            for m in tf:
                n = os.path.basename(m.name)
                if n in WANT:
                    try:
                        tabs[n] = pd.read_csv(tf.extractfile(m))
                    except Exception as e:
                        tabs[n] = str(e)
        print(w, "read s", round(time.time() - t0, 1))
        for n, df in tabs.items():
            if isinstance(df, str):
                print("  ", n, "ERR", df); continue
            print("  ", n, "rows", len(df), "cols", list(df.columns))
            if len(df) < 2: continue
            ts = np.sort(df.timestamp.to_numpy(dtype=np.int64))
            d = np.diff(ts) / 1000
            print("     interval s q10/50/90:", np.round(np.quantile(d, [.1, .5, .9]), 1))
            if n == "ActivityEvent.csv":
                c = [x for x in df.columns if x != "timestamp"]
                print("     conf range", df[c].min().min(), df[c].max().max(), "row sum q50", df[c].sum(1).median())
                print("     argmax shares", (df[c].idxmax(axis=1).value_counts(normalize=True).round(3)).to_dict())
            if n == "Fitbit-Calorie.csv":
                print("     value q", np.round(df.value.quantile([.05, .5, .95]).values, 3),
                      "mets q", np.round(df.mets.quantile([.05, .5, .95]).values, 2),
                      "level shares", df.level.value_counts(normalize=True).round(3).to_dict())
            if n == "ActivityTransition.csv":
                print("     enter", df.typeEnter.value_counts(normalize=True).round(3).to_dict())
