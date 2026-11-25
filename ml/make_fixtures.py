"""Golden fixtures for the Swift port of the features and the model (TODO 2.17).

Usage:
    python ml/make_fixtures.py [--model data/models/state_v3.joblib]

Writes ml/fixtures/state_cases.json: 10 SYNTHETIC cases (fixed seed, nothing from EmoPhone, no
real person). Each case has the raw series the app would hold (heart rate, steps), the answer
time, the expected features of the shipped model (v3: 17, `null` = unknown), the expected
probability and the probability of the "time only" model (v3: also `valence_probability` and `valence_time_only_probability`,
chosen with the same mode rule as the energy). The Swift tests (TODO 2.18-2.21) must retrieve the same values
(tolerance 1e-6). Without --model the probability
is computed from app/Harmony/Resources/model_params.json, the file the app ships.

Time: all instants are minutes since `origin_ms` (ms UTC); local time is Korea (UTC+9).
Sleep: the app reads the Apple Watch sleep instead of estimating it, so each case also gives the
nights as Python estimates them (`nights`, `answer_night`): sleep minutes and wake minute (local
minutes since 1970-01-01), `null` = unknown. `answer_night` is the night used at the answer time
(cut at the answer before 12:00); `nights` are the full nights of the 14 previous days.
"""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

import export
import features as F

SEED = 20261120
OUT = Path(__file__).resolve().parent / "fixtures" / "state_cases.json"
PARAMS = export.APP_RESOURCES / "model_params.json"
ORIGIN = pd.Timestamp("2026-01-05")                  # a Monday, local midnight of day 0


def ms(day, hour, minute=0):
    """Milliseconds UTC of local `day` (0 = ORIGIN), hour:minute."""
    local = ORIGIN + pd.Timedelta(days=day, hours=hour, minutes=minute)
    return local.value // 10**6 - F.KST_MS


def series(rng, days, off=(), flat_hr=None):
    """Heart rate and steps of one synthetic person over `days` days, as (minute, value) lists.

    Heart rate about every 5 min with jitter and some doubled readings (to exercise the
    "first reading of each 5-minute slice" rule); asleep 23:30-07:00 (low HR, no steps). `off`:
    (from_ms, to_ms) intervals when the watch is not worn (no data at all).
    """
    hr, steps = [], []
    start = ms(0, 0)
    for slot in range(days * 288):
        t = start + slot * 5 * F.MIN_MS + int(rng.integers(0, 5)) * F.MIN_MS    # whole minutes
        if any(a <= t < b for a, b in off):
            continue
        hour = ((t + F.KST_MS) // F.MIN_MS % 1440) / 60
        asleep = hour >= 23.5 or hour < 7
        base = 52 if asleep else 70 + 8 * np.sin((hour - 9) / 24 * 2 * np.pi)
        value = flat_hr if flat_hr else int(round(base + rng.normal(0, 4)))
        hr.append((t, value))
        if rng.random() < 0.1:                       # a second reading in the same slice
            hr.append((t + F.MIN_MS, value if flat_hr else value + 1))
        if not asleep and rng.random() < 0.3:
            steps.append((t, int(rng.integers(1, 120))))
    return hr, steps


def cases():
    """(name, description, answer instant, series kwargs) of the 10 cases."""
    return [
        ("weekday_afternoon", "normal Thursday 15:10, 14 days of history", ms(14, 15, 10), {}),
        ("weekend_afternoon", "Saturday 16:00", ms(12, 16, 0), {}),
        ("morning_before_noon", "answer at 10:20: the night is cut at the answer", ms(14, 10, 20), {}),
        ("late_evening", "answer at 23:45", ms(14, 23, 45), {}),
        ("early_night", "answer at 03:00: no grid point in the 3 h block", ms(14, 3, 0), {}),
        ("short_history", "answer on day 4: fewer than 7 days of reference", ms(4, 15, 0), {}),
        ("watch_off_last_hour", "no data in the hour before the answer",
         ms(14, 17, 0), {"off": [(ms(14, 15, 50), ms(14, 17, 5))]}),
        ("night_unknown", "watch off all night: sleep unknown, never 0",
         ms(14, 14, 0), {"off": [(ms(13, 21, 0), ms(14, 9, 0))]}),
        ("no_steps_worn", "watch worn, no steps in the last hour: 0 steps, not unknown",
         ms(14, 13, 0), {"no_steps": (ms(14, 11, 50), ms(14, 13, 5))}),
        ("constant_heart_rate", "same HR all along: standard deviation 0, z-scores unknown",
         ms(14, 15, 0), {"flat_hr": 70}),
    ]


def build_case(name, description, answer_t, kwargs, rng, params):
    kwargs = dict(kwargs)
    no_steps = kwargs.pop("no_steps", None)
    days = int(max(16, (answer_t - ms(0, 0)) // (24 * 3600 * 1000) + 2))
    hr, steps = series(rng, days, **kwargs)
    if no_steps:
        steps = [(t, v) for t, v in steps if not no_steps[0] <= t < no_steps[1]]
    hr_ts, hr_v = (np.array(a) for a in zip(*hr))
    st_ts, st_v = (np.array(a) for a in zip(*steps))
    # The answer is the participant's last datum, like in the app (no future data present).
    keep = hr_ts <= answer_t
    hr_ts, hr_v = hr_ts[keep], hr_v[keep]
    keep = st_ts <= answer_t
    st_ts, st_v = st_ts[keep], st_v[keep]
    threshold = F.sleep_threshold(hr_ts, hr_v)
    columns = params["features"]
    feats = F.participant_features(np.array([answer_t]), hr_ts, hr_v, st_ts, st_v, threshold,
                                   raw_windows=params["version"] == 3)
    row = [float(feats[f][0]) for f in columns]
    mhr, mst = F.minute_hr(hr_ts, hr_v), F.minute_steps(st_ts, st_v)
    day = int(F.local_minute(answer_t) // 1440)
    nights = []
    for d in range(max(day - F.REFERENCE_DAYS, 0), day):
        sleep, wake, _ = F.night(mhr, mst, threshold, d)
        nights.append({"day": d, "sleep_min": _num(sleep), "wake_minute": _num(wake)})
    sleep, wake, _ = F.night(mhr, mst, threshold, day,
                             until=answer_t if F.local_minute(answer_t) % 1440 < F.NIGHT[1] else None)
    origin = ms(0, 0)
    return {
        "name": name,
        "description": description,
        "origin_ms": origin,
        "answer_minute": (answer_t - origin) // F.MIN_MS,
        "sleep_threshold": float(threshold),
        "hr": [[(int(t) - origin) // F.MIN_MS, int(v)] for t, v in zip(hr_ts, hr_v)],
        "steps": [[(int(t) - origin) // F.MIN_MS, int(v)] for t, v in zip(st_ts, st_v)],
        "nights": nights,
        "answer_night": {"sleep_min": _num(sleep), "wake_minute": _num(wake)},
        "features": {f: _num(v) for f, v in zip(columns, row)},
        "probability": export.predict(params, row),
        "time_only_probability": export.predict(params["time_only"], row[:3]),
        **({"valence_probability": export.predict(params["valence"], row),
            "valence_time_only_probability": export.predict(params["valence_time_only"], row[:3])}
           if "valence" in params else {}),
    }


def _num(x):
    x = float(x)
    return None if np.isnan(x) else x


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=Path, help="joblib of train.py --final (default: app params)")
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args()
    if args.model:
        import joblib
        params = export.build_params(joblib.load(args.model))
    else:
        params = json.loads(PARAMS.read_text())
    rng = np.random.default_rng(SEED)
    out = [build_case(*c, rng, params) for c in cases()]
    args.out.write_text(json.dumps({"version": 1, "model_version": params["version"],
                               "features": params["features"], "cases": out},
                              separators=(",", ":")) + "\n")
    print(f"{args.out}: {len(out)} cases, {args.out.stat().st_size // 1024} KB")
    for c in out:
        unknown = [f for f, v in c["features"].items() if v is None]
        print(f"  {c['name']:<22} P={c['probability']:.4f}, unknown: {', '.join(unknown) or '-'}")


if __name__ == "__main__":
    main()
