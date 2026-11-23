"""Gap experiment: what is left of the gain if the latest answers are `lag` days old?
Rows on days >= 15 of use; every method sees only check-ins older than the lag (rolling).
Same tuning / population models / seeds as sim.py. Aggregates only -> ../out/lag_<config>.json.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sim  # noqa: E402

LAGS = [0, 1, 2, 4, 7]
METHODS = ["pop", "m1_intercept", "m1d_intercept_decay", "m1d_now", "m3_hist", "m4c_decay_on_hist",
           "m5t_hist_time"]


def map_now(zc, yc, tc, t_rows, cutoff, tau, T_h):
    """Variant of m1d whose forgetting runs to the PREDICTION time (weights exp(-(t - c_i)/T)),
    so the offset shrinks back to 0 (population model) when answers stop. 1-D MAP per row."""
    age = (t_rows[:, None] - tc[None, :]) / sim.HOUR
    w = np.where(tc[None, :] < cutoff[:, None], np.exp(-age / T_h), 0.0)
    b = np.zeros(len(t_rows))
    for _ in range(40):
        p = 1 / (1 + np.exp(-(zc[None, :] + b[:, None])))
        g = (w * (p - yc[None, :])).sum(1) + b / tau ** 2
        h = (w * p * (1 - p)).sum(1) + 1 / tau ** 2
        step = g / h
        b -= step
        if np.abs(step).max() < 1e-7:
            break
    return b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="arousal")
    ap.add_argument("--label", default="past")
    ap.add_argument("--rate", type=int, default=2)
    ap.add_argument("--seeds", type=int, default=3)
    args = ap.parse_args()
    cv, _ = sim.load_table()
    persons = sim.build_persons(cv, args.target, args.label)
    name = f"lag_{args.target}_{args.label}_r{args.rate}"
    rows = []
    for k in range(5):
        train = [P for P in persons if P["fold"] != k]
        test = [P for P in persons if P["fold"] == k]
        prm = sim.tune(train, args.rate, seed=1000 + 10 * k)
        M = sim.fit_models(train, args.rate, seed=2000 + 10 * k)
        for s in range(args.seeds):
            for P in test:
                ev = P["dou"] >= 15
                if ev.sum() < 10:
                    continue
                ci = sim.sample_checkins(P["day"], args.rate, np.random.default_rng([s, args.rate, P["pid"]]))
                I = sim.inputs(P, M, ci)
                y = P["y"]
                _, D1 = sim.rolling(I["zpop"], I["X"][:, :1], y, ci, I["nb"], sim.prec1([prm["tb1"]]))
                _, D1d = sim.rolling(I["zpop"], I["X"][:, :1], y, ci, I["nb"], sim.prec1([prm["g1d"][0]]),
                                     P["t"], [prm["g1d"][1] * 24])
                _, D4c = sim.rolling(I["z3"], I["X"][:, :1], y, ci, I["nb"], sim.prec1([prm["g4c"][0]]),
                                     P["t"], [prm["g4c"][1] * 24])
                for lag in LAGS:
                    H = sim.history(P["t"], P["tod"], ci, 2 * y[ci] - 1, lag_h=lag * 24.0)
                    nbL = np.searchsorted(P["t"][ci], P["t"] - lag * sim.DAY, side="left")
                    z3 = M["hist"].decision_function(np.hstack([P["Xraw"], H]))
                    # 4c: decayed intercept fitted on the (unlagged) history offsets of the check-in rows,
                    # applied on top of the lagged history model
                    Z = {"pop": I["zpop"], "m1_intercept": I["zpop"] + D1[nbL, 0, 0],
                         "m1d_intercept_decay": I["zpop"] + D1d[nbL, 0, 0], "m3_hist": z3,
                         "m1d_now": I["zpop"] + map_now(I["zpop"][ci], y[ci], P["t"][ci], P["t"],
                                                        P["t"] - lag * sim.DAY, prm["g1d"][0],
                                                        prm["g1d"][1] * 24),
                         "m4c_decay_on_hist": z3 + D4c[nbL, 0, 0],
                         "m5t_hist_time": M["histtime"].decision_function(np.hstack([P["Xraw"][:, :3], H]))}
                    f = pd.DataFrame({m: 1 / (1 + np.exp(-Z[m][ev])) for m in METHODS})
                    f["y"], f["pid"], f["seed"], f["lag"] = y[ev], P["pid"], s, lag
                    rows.append(f)
        print(f"[{name}] fold {k}", flush=True)
    R = pd.concat(rows, ignore_index=True)
    rng = np.random.default_rng(0)
    res = {str(L): sim.bucket_metrics(R[R.lag == L], METHODS, rng) for L in LAGS}
    (sim.OUT / f"{name}.json").write_text(json.dumps(res, indent=1))
    print(f"[{name}] done", flush=True)


if __name__ == "__main__":
    main()
