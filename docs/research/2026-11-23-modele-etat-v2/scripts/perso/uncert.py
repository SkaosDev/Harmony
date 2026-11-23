"""Optional: uncertainty-based check-in timing vs random timing, same daily budget.

Policy "uncertain": each local day, among that day's answer moments, ask at the `rate` moments
where the current model (state at the start of the day: check-ins of previous days only) is
closest to p = 0.5. Policy "random": sim.sample_checkins (identical seeds to sim.py).
Same tuned priors (sim.tune, same seeds) and population models (trained with random timing).
Writes aggregates only to ../out/uncert_<config>.json.
"""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sim  # noqa: E402


def uncertain_checkins(P, M, prm, rate, which):
    chosen = np.array([], dtype=int)
    for d in np.unique(P["day"]):
        rows = np.flatnonzero(P["day"] == d)
        I = sim.inputs(P, M, chosen)
        if which == "m3":
            z = I["z3"]
        else:                                   # m1d: decayed personal intercept, current state
            z = I["zpop"].copy()
            if len(chosen):
                age = (P["t"][chosen[-1]] - P["t"][chosen]) / sim.HOUR
                w = np.exp(-age[None, :] / (prm["g1d"][1] * 24))
                delta = sim.map_fit(I["X"][chosen, :1], I["zpop"][chosen], P["y"][chosen],
                                    sim.prec1([prm["g1d"][0]]), np.zeros((1, 1)), w)
                z = z + delta[0, 0]
        pick = rows[np.argsort(np.abs(z[rows]), kind="stable")[:rate]]
        chosen = np.sort(np.concatenate([chosen, pick]))
    return chosen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="arousal")
    ap.add_argument("--label", default="past")
    ap.add_argument("--rate", type=int, default=2)
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--which", default="m1d", choices=["m1d", "m3"])
    args = ap.parse_args()
    t0 = time.time()
    cv, _ = sim.load_table()
    persons = sim.build_persons(cv, args.target, args.label)
    name = f"uncert_{args.which}_{args.target}_{args.label}_r{args.rate}"
    rolls = {"random": [], "uncertain": []}
    share_high = {"random": [], "uncertain": []}
    for k in range(5):
        train = [P for P in persons if P["fold"] != k]
        test = [P for P in persons if P["fold"] == k]
        prm = sim.tune(train, args.rate, seed=1000 + 10 * k)
        prm["rate"] = args.rate
        M = sim.fit_models(train, args.rate, seed=2000 + 10 * k)
        for s in range(args.seeds):
            for P in test:
                cis = {"random": sim.sample_checkins(P["day"], args.rate,
                                                     np.random.default_rng([s, args.rate, P["pid"]]))}
                if s == 0:                       # deterministic policy: one run is enough
                    cis["uncertain"] = uncertain_checkins(P, M, prm, args.rate, args.which)
                for pol, ci in cis.items():
                    r, _ = sim.predict_person(P, M, ci, prm, frozen=False)
                    r["fold"], r["seed"] = k, s
                    rolls[pol].append(r)
                    share_high[pol].append(P["y"][ci].mean())
        print(f"[{name}] fold {k} {time.time() - t0:.0f}s", flush=True)
    rng = np.random.default_rng(0)
    res = {"config": name, "share_high_in_checkins": {p: float(np.mean(v)) for p, v in share_high.items()}}
    for pol, rs in rolls.items():
        R = pd.concat(rs, ignore_index=True)
        res[pol] = {"all_rows": sim.bucket_metrics(R, sim.METHODS, rng),
                    "by_day": sim.curves(R, "dou", sim.D_EDGES, sim.D_LABELS, sim.METHODS, rng),
                    "by_n": sim.curves(R, "nb", sim.N_EDGES, sim.N_LABELS, sim.METHODS, rng)}
    (sim.OUT / f"{name}.json").write_text(json.dumps(res, indent=1))
    print(f"[{name}] done {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
