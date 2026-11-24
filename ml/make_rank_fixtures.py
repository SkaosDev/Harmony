"""Golden cases for the rank grid of e0 (design v2 §4.3, TODO 6.5; Swift S3).

Usage:
    python ml/make_rank_fixtures.py

Writes ml/fixtures/rank_grid_cases.json: SYNTHETIC cases (fixed seed, nothing from EmoPhone, no
real person). Each case gives the window values of the reference grid around the prediction time
(`grid`: minute, then `quantities`; points outside [t - 14 days, t) and points with steps but no
heart rate are there on purpose) and the nights of the grid days. Expected: the rows scored with
the single reference at t (`features.rank_reference`: worn points only, night of each point's own
day; `rows`: minute, then `features`), the probability of each row with the shipped model and its
mode rule (`row_probabilities`), and e0 = rank of `probability` among them (`probability` itself
below `rank_minimum_rows` rows). `null` = unknown. Time: minutes since `origin_ms` (ms UTC), local
time is Korea (UTC+9). The probabilities use app/Harmony/Resources/model_params.json: regenerate
when the shipped model changes.
"""
import json
from pathlib import Path

import numpy as np

import export
import features as F
from evaluate_v2 import gate
from make_fixtures import PARAMS, _num, ms
from simulate_wp_b0 import rank

SEED = 20261124
OUT = Path(__file__).resolve().parent / "fixtures" / "rank_grid_cases.json"


def cases():
    """(name, description, prediction instant, days of watch data before it)."""
    return [
        ("two_weeks", "Thursday 15:10, 15 days of data: z-scores known, rank among 32+ rows",
         ms(17, 15, 10), 15),
        ("morning", "Monday 10:20: today's points (08:00-10:00) use today's night", ms(14, 10, 20), 15),
        ("short_history", "1 day of data: z-scores unknown (time only), fewer than 32 rows",
         ms(10, 15, 0), 1),
    ]


def grid_series(rng, grid_t, first_t):
    """Window values of each grid point: watch worn (heart rate), steps only, or no data."""
    n = len(grid_t)
    state = rng.choice(["worn", "steps", "off"], size=n, p=[0.6, 0.1, 0.3])
    state[grid_t < first_t] = "off"
    hr = 70 + rng.normal(0, 6, n)
    steps = np.where(rng.random(n) < 0.4, 0, rng.integers(2, 3000, n))
    steps[state == "steps"] = rng.integers(2, 3000, (state == "steps").sum())
    grid = {}
    for w, share in zip(F.WINDOWS, (0.5, 1.0, 2.0)):
        heart = np.where(state == "worn", np.round(hr + rng.normal(0, 2, n), 1), np.nan)
        if w == 15:
            heart[rng.random(n) < 0.2] = np.nan               # no reading in the last 15 min
        grid[f"hr_{w}"] = heart
        grid[f"log_steps_{w}"] = np.where(state == "off", np.nan, np.round(np.log1p(np.round(steps * share)), 4))
    return grid


def build_case(name, description, t, days, rng, params):
    grid_t = F.grid_points(t - (F.REFERENCE_DAYS + 1) * F.DAY_MS, t + 3 * 3600 * 1000)
    grid = grid_series(rng, grid_t, t - days * F.DAY_MS)
    day, first_day = (int(F.local_minute(x) // 1440) for x in (t, t - days * F.DAY_MS))
    nights = {}
    for d in range(day - F.REFERENCE_DAYS - 1, day + 1):
        known = d >= first_day and rng.random() < 0.8
        nights[d] = ((float(round(420 + rng.normal(0, 40))), float(d * 1440 + rng.integers(6 * 60, 9 * 60)))
                     if known else (np.nan, np.nan))
    rows = F.rank_reference(t, grid_t, grid, nights, columns=F.FEATURES_V2)
    columns = params["features"]
    body = rows[gate(columns)].notna().to_numpy()
    probabilities = [export.predict(params, row[columns]) if b else export.predict(params["time_only"], row.iloc[:3])
                     for b, (_, row) in zip(body, rows.iterrows())]
    probability = 0.5
    origin = ms(0, 0)
    minutes = lambda instants: [(int(x) - origin) // F.MIN_MS for x in instants]
    return {
        "name": name,
        "description": description,
        "origin_ms": origin,
        "t_minute": (t - origin) // F.MIN_MS,
        "grid": [[m, *(_num(grid[q][i]) for q in F.QUANTITIES)] for i, m in enumerate(minutes(grid_t))],
        "nights": [{"day": d, "sleep_min": _num(s), "wake_minute": _num(w)} for d, (s, w) in nights.items()],
        "rows": [[m, *(_num(v) for v in row)] for m, (_, row) in zip(minutes(rows.index), rows.iterrows())],
        "row_probabilities": probabilities,
        "probability": probability,
        "e0": rank(probability, np.array(probabilities)),
    }


def main():
    params = json.loads(PARAMS.read_text())
    rng = np.random.default_rng(SEED)
    out = [build_case(*c, rng, params) for c in cases()]
    OUT.write_text(json.dumps({"version": 1, "model_version": params["version"],
                               "quantities": list(F.QUANTITIES), "features": list(F.FEATURES_V2),
                               "rank_minimum_rows": 32, "cases": out}, separators=(",", ":")) + "\n")
    print(f"{OUT}: {len(out)} cases, {OUT.stat().st_size // 1024} KB")
    for c in out:
        print(f"  {c['name']:<14} grid {len(c['grid'])}, rows {len(c['rows'])}, e0 {c['e0']:.4f}")


if __name__ == "__main__":
    main()
