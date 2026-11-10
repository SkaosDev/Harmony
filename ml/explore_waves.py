"""Compare EmoPhone wave ESM and Fitbit schemas (TODO 1.35).

Usage: python ml/explore_waves.py --data data/emophone

Prints aggregate statistics only. It never opens UserInfo.csv, prints text values,
or extracts sensor archives. Sensor CSV column names and timestamp intervals are read
in memory from the archives.
"""

import argparse
import tarfile
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

WAVES = ("D1", "D2", "D3")
SENSOR_CSVS = ("Fitbit-HeartRate.csv", "Fitbit-StepCount.csv")


def archives_for(wave_dir):
    return sorted((wave_dir / "Sensor").glob("*_Sensor_P*.tar.gz"))


def read_sensor_aggregates(archives):
    names = Counter()
    columns = {name: None for name in SENSOR_CSVS}
    hr_medians = []
    participants = set()
    for archive in archives:
        participant = archive.stem.split("_P")[-1].removesuffix(".tar")
        participants.add("P" + participant)
        with tarfile.open(archive, "r:gz") as tar:
            for member in tar:
                name = Path(member.name).name
                if not name.lower().endswith(".csv"):
                    continue
                names[name] += 1
                if name not in SENSOR_CSVS:
                    continue
                stream = tar.extractfile(member)
                frame = pd.read_csv(stream, nrows=0)
                if columns[name] is None:
                    columns[name] = list(frame.columns)
                if name == "Fitbit-HeartRate.csv":
                    stream = tar.extractfile(member)
                    hr = pd.read_csv(stream, usecols=lambda col: col == "timestamp")
                    ts = pd.to_numeric(hr["timestamp"], errors="coerce").dropna().sort_values()
                    diffs = ts.diff().dropna()
                    if not diffs.empty:
                        hr_medians.append(float(diffs.median()) / 60_000)
    return names, columns, participants, hr_medians


def describe_wave(wave_dir, baseline_columns):
    esm = pd.read_csv(wave_dir / "EsmResponse.csv")
    columns = list(esm.columns)
    print(f"\n{wave_dir.name}: ESM rows={len(esm)}, participants={esm['pcode'].nunique()}")
    print(f"  columns ({len(columns)}): {', '.join(columns)}")
    print(f"  added vs D1: {', '.join(sorted(set(columns) - baseline_columns)) or 'none'}")
    print(f"  missing vs D1: {', '.join(sorted(baseline_columns - set(columns))) or 'none'}")
    for col in esm.select_dtypes(include="number").columns:
        if col == "actualTriggerTime" or col.lower().endswith("time") or col == "duration":
            continue
        values = esm[col].dropna()
        unique = sorted(values.unique().tolist())
        line = f"  {col}: min={values.min():g}, max={values.max():g}, empty={esm[col].isna().mean():.1%}"
        if len(unique) <= 15:
            line += f", distinct={unique}"
        else:
            line += f", distinct_count={len(unique)}"
        print(line)
    timestamps = pd.to_numeric(esm["actualTriggerTime"], errors="coerce").dropna()
    if timestamps.empty:
        print("  actualTriggerTime: no numeric timestamps")
    else:
        dates = pd.to_datetime(timestamps, unit="ms", utc=True).dt.tz_convert("Asia/Seoul")
        print(f"  actualTriggerTime: milliseconds since Unix epoch (UTC); KST {dates.min()} .. {dates.max()}")
    archives = archives_for(wave_dir)
    names, sensor_columns, sensor_people, hr_medians = read_sensor_aggregates(archives)
    print(f"  sensor archives={len(archives)}; participants with archives={len(sensor_people)}")
    print("  CSV archive counts: " + (", ".join(f"{n} ({c})" for n, c in sorted(names.items())) or "none"))
    for name in SENSOR_CSVS:
        print(f"  {name} columns: {', '.join(sensor_columns[name] or []) or 'not found'}")
    if hr_medians:
        print(f"  Fitbit HR median interval: median of participant medians={np.median(hr_medians):.2f} min (n={len(hr_medians)})")
    else:
        print("  Fitbit HR median interval: unavailable")
    response_people = set(esm["pcode"].dropna().astype(str))
    print(f"  responses without sensor archive={len(response_people - sensor_people)}; archives without responses={len(sensor_people - response_people)}")
    return set(columns)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, required=True, help="root containing D1, D2 and D3")
    root = parser.parse_args().data
    baseline = pd.read_csv(root / "D1" / "EsmResponse.csv", nrows=0)
    baseline_columns = set(baseline.columns)
    for wave in WAVES:
        describe_wave(root / wave, baseline_columns)


if __name__ == "__main__":
    main()
