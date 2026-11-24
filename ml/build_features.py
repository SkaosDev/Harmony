"""Build the v1 feature table of each EmoPhone wave (TODO 2.7).

Usage:
    python ml/build_features.py --data data/emophone --out data/features [--check-v0]

Writes one local CSV per wave (data/features/v1_D1.csv ...; data/ is ignored by Git): one row
per mood answer with the participant id (wave + pcode, e.g. D1_P050), the answer time, arousal,
stress (D-3 brought back to -3..+3), the labels and the 13 features of ml/features.py.
Prints aggregates only: rows, participants and the share of missing values per feature.

--check-v0 also compares the nights with v0 (ml/explore_d1.py, TODO 2.5): with the v0 rules
(minute-by-minute coverage, whole window) the nights must be identical; with the v1 rules it
counts the answers whose night changes status and the share of known nights.
"""
import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from explore_d1 import night_sleep, read_participant
from features import (FEATURES, FEATURES_V2, KST_MS, label_high, local_minute, minute_hr, minute_steps,
                      night, participant_features, rescale_d3, sleep_threshold)

WAVES = ("D1", "D2", "D3")
EMPTY = pd.DataFrame({"timestamp": np.array([], dtype=np.int64), "value": np.array([])})


def compare_with_v0(pcode, answer_t, hr, st, f, counts):
    """Add this participant's night comparisons with v0 to `counts` (aggregates only)."""
    days = pd.to_datetime(pd.Series(answer_t) + KST_MS, unit="ms").dt.normalize().unique()
    v0 = night_sleep(pcode, days, hr, st if len(st) else None)
    mhr = minute_hr(hr.timestamp.values, hr.value.values)
    mst = minute_steps(st.timestamp.values, st.value.values)
    threshold = sleep_threshold(hr.timestamp.values, hr.value.values)
    v0_known = {}
    for r in v0:
        wake_day = local_minute(pd.Timestamp(r["day"]).value // 10**6 - KST_MS) // 1440
        sleep, wake, coverage = night(mhr, mst, threshold, wake_day, slot_min=1)
        same = (coverage == r["night_worn"]
                and (sleep, wake) == (r["sleep_min"], r["wake_min"]) if "sleep_min" in r
                else np.isnan(sleep))
        counts["nights"] += 1
        counts["differences"] += not same
        v0_known[wake_day] = "sleep_min" in r
    known_v0 = np.array([v0_known[d] for d in local_minute(answer_t) // 1440])
    known_v1 = f["sleep_unknown"] == 0
    counts["answers"] += len(answer_t)
    counts["known_v0"] += known_v0.sum()
    counts["known_v1"] += known_v1.sum()
    counts["to_unknown"] += (known_v0 & ~known_v1).sum()
    counts["to_known"] += (~known_v0 & known_v1).sum()


def build_wave(wave_dir, wave, check_v0, *, v2=False):
    targets = ["arousal", "stress"] + (["valence"] if v2 else [])
    features = FEATURES_V2 if v2 else FEATURES
    esm = pd.read_csv(wave_dir / "EsmResponse.csv",
                      usecols=["pcode", "actualTriggerTime", *targets])
    if wave == "D3":
        esm["stress"] = rescale_d3(esm.stress)       # 0..+6 -> -3..+3, before the label
    tables, counts = [], dict.fromkeys(
        ["nights", "differences", "answers", "known_v0", "known_v1", "to_unknown", "to_known"], 0)
    for archive in sorted((wave_dir / "Sensor").glob("*_Sensor_P*.tar.gz")):
        pcode = archive.name.split("_")[2].split(".")[0]
        e = esm[esm.pcode == pcode].sort_values("actualTriggerTime", kind="stable")
        if e.empty:
            continue
        hr, st = read_participant(archive)
        if hr is None:
            continue
        st = EMPTY if st is None else st
        t = e.actualTriggerTime.to_numpy(dtype=np.int64)
        f = participant_features(t, hr.timestamp.values, hr.value.values,
                                 st.timestamp.values, st.value.values,
                                 sleep_threshold(hr.timestamp.values, hr.value.values), raw_windows=v2)
        table = pd.DataFrame({"participant": f"{wave}_{pcode}", "t": t,
                              **{target: e[target].to_numpy() for target in targets}})
        tables.append(pd.concat([table, pd.DataFrame(f)[list(features)]], axis=1))
        if check_v0:
            compare_with_v0(pcode, t, hr, st, f, counts)
    table = pd.concat(tables, ignore_index=True)
    for label in targets:
        if v2 and table[label].isna().any():
            raise ValueError(f"{wave}: missing {label} responses")
        table[f"{label}_high"] = label_high(table[label], table.participant)
    columns = ["participant", "t", *targets, *(f"{label}_high" for label in targets), *features]
    return table[columns], counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=Path, required=True, help="folder holding D1, D2 and D3")
    ap.add_argument("--out", type=Path, required=True, help="output folder (inside data/)")
    ap.add_argument("--check-v0", action="store_true", help="compare the nights with v0")
    ap.add_argument("--v2", action="store_true", help="append raw windows and valence")
    ap.add_argument("--waves", nargs="+", choices=WAVES, default=WAVES)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for wave in args.waves:
        table, c = build_wave(args.data / wave, wave, args.check_v0, v2=args.v2)
        path = args.out / f"v{2 if args.v2 else 1}_{wave}.csv"
        table.to_csv(path, index=False)
        print(f"{wave}: {len(table)} rows, {table.participant.nunique()} participants "
              f"-> {path}")
        print("  missing share: " + ", ".join(f"{n} {table[n].isna().mean():.3f}"
                                             for n in (FEATURES_V2 if args.v2 else FEATURES)))
        if args.check_v0:
            print(f"  v0 rules: {c['nights']} nights (participant x day) compared, "
                  f"{c['differences']} differences with explore_d1")
            print(f"  v1 rules: {c['to_unknown'] + c['to_known']} of {c['answers']} answers change "
                  f"night status ({c['to_unknown']} known -> unknown, {c['to_known']} unknown -> known); "
                  f"known nights {c['known_v0'] / c['answers']:.3f} (v0) -> "
                  f"{c['known_v1'] / c['answers']:.3f} (v1)")


if __name__ == "__main__":
    main()
