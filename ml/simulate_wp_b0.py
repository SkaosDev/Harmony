"""Chronological WP-B0 simulation on held-out D-1/D-2 participants."""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score

import features as F
from evaluate_v2 import TIME, fit, gate, load, logits, mixed_logits
from explore_d1 import read_participant
from train import folds


def sigmoid(z):
    return 1 / (1 + np.exp(-np.asarray(z, dtype=float)))


def rank(probability, grid):
    return float(np.mean(grid <= probability)) if len(grid) >= 32 else float(probability)


def rank_rows(person, data, models, columns):
    wave, code = person.participant.iloc[0].split("_", 1)
    archive = data / wave / "Sensor" / f"{wave}_Sensor_{code}.tar.gz"
    hr, steps = read_participant(archive)
    ht, hv = F.resample_hr(hr.timestamp, hr.value)
    st = np.array([], dtype=np.int64) if steps is None else steps.timestamp.to_numpy(dtype=np.int64)
    sv = np.array([]) if steps is None else steps.value.to_numpy(dtype=float)
    order = np.argsort(st, kind="stable")
    grid_t = F.grid_points(person.t.min() - 14 * F.DAY_MS, person.t.max())
    grid = F.window_values(ht, hv, st[order], sv[order], grid_t)
    mhr, mst = F.minute_hr(hr.timestamp, hr.value), F.minute_steps(st, sv)
    threshold = F.sleep_threshold(hr.timestamp, hr.value)
    days = F.local_minute(person.t.to_numpy()) // 1440
    nights = {d: F.night(mhr, mst, threshold, d)[:2]
              for d in range(days.min() - 14, days.max() + 1)}
    body, time = models
    references = []
    for t, day in zip(person.t, days):
        current_nights = nights
        if F.local_minute(t) % 1440 < F.NIGHT[1]:
            current_nights = {**nights, day: F.night(mhr, mst, threshold, day, until=t)[:2]}
        references.append(F.rank_reference(t, grid_t, grid, current_nights, columns=columns))
    counts = [len(ref) if len(ref) >= 32 else 0 for ref in references]
    enough = [ref for ref, count in zip(references, counts) if count]
    starts = np.r_[0, np.cumsum(counts)]
    mixed_grid = time_grid = np.array([])
    if enough:
        combined = pd.concat(enough, ignore_index=True)
        time_grid = sigmoid(logits(time, combined, TIME))
        mixed_grid = np.where(combined[gate(columns)].notna(),
                              sigmoid(logits(body, combined, columns)), time_grid)
    # rank() compares probabilities, as in the app (its fallback returns the probability).
    for index, (p, p_time) in enumerate(zip(sigmoid(person.energy_z), sigmoid(person.time_z))):
        if counts[index]:
            section = slice(starts[index], starts[index + 1])
            yield rank(p, mixed_grid[section]), rank(p_time, time_grid[section])
        else:
            yield p, p_time


def sample(days, rate, rng):
    chosen = []
    for day in np.unique(days):
        rows = np.flatnonzero(days == day)
        chosen.append(rng.choice(rows, min(rate, len(rows)), replace=False))
    return np.sort(np.concatenate(chosen))


def chronological(times, answers, z, tau, decay, *, minimum=5):
    """Fix each label using only earlier sampled answers. Score before learning."""
    age = (times[:, None] - times[None, :]) / F.DAY_MS
    past = (age > 0) & (age <= 14)
    count = past.sum(axis=1)
    label = np.where(count >= minimum, answers > (past @ answers) / count.clip(1), np.nan)
    eligible = past & np.isfinite(label)[None, :]
    weights = eligible * np.exp(-np.where(eligible, age, 0) / decay)
    b = np.zeros(len(times))
    for _ in range(5):
        p = 1 / (1 + np.exp(-(z[None, :] + b[:, None])))
        g = (weights * (p - np.nan_to_num(label)[None, :])).sum(axis=1) + b / tau**2
        h = (weights * p * (1 - p)).sum(axis=1) + 1 / tau**2
        b -= g / h
    return label, z + b, eligible.sum(axis=1)


def summarize(rows):
    all_rows = pd.DataFrame(rows, columns=["day", "label", "common", "personal", "rank", "switched"])
    result = {}
    for name, group in [("all", all_rows), ("1–3", all_rows[all_rows.day <= 3]),
                        ("4–7", all_rows[all_rows.day.between(4, 7)]),
                        ("8–14", all_rows[all_rows.day.between(8, 14)]),
                        ("15+", all_rows[all_rows.day >= 15])]:
        group = group.dropna(subset=["label"])
        result[name] = {"n": len(group)}
        if group.label.nunique() == 2:
            result[name].update({col: roc_auc_score(group.label, group[col])
                                 for col in ("common", "personal", "rank", "switched")})
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--features", type=Path, default=Path("data/features"))
    ap.add_argument("--data", type=Path, default=Path("data/emophone"))
    ap.add_argument("--v2", action="store_true", help="simulate the adopted v2 energy contract")
    ap.add_argument("--out", type=Path, help="write aggregate JSON here")
    args = ap.parse_args()
    columns = F.FEATURES_V2 if args.v2 else F.FEATURES
    table = pd.concat([load(args.features, wave) for wave in ("D1", "D2")], ignore_index=True)
    rows = {}
    sensitivity = {}
    for fold, (train, test) in enumerate(folds(table.participant), start=1):
        train, test = table.iloc[train], table.iloc[test].copy()
        energy = fit(train, columns, "arousal"), fit(train, TIME, "arousal")
        valence = fit(train, F.FEATURES_V2, "valence"), fit(train, TIME, "valence")
        test["energy_z"] = mixed_logits(*energy, test, columns)
        test["time_z"] = energy[1].decision_function(test[list(TIME)].to_numpy())
        test["valence_z"] = mixed_logits(*valence, test, F.FEATURES_V2)
        for _, person in test.groupby("participant"):
            person = person.sort_values("t", kind="stable")
            t = person.t.to_numpy()
            days = F.local_minute(t) // 1440
            energy_rank, time_rank = np.array(list(rank_rows(person, args.data, energy, columns))).T
            for seed in range(3):
                for rate in (1, 2, 4):
                    take = sample(days, rate, np.random.default_rng(seed))
                    for target, z, tau, quantize in (
                        ("energy_7", person.energy_z.to_numpy(), 1., False),
                        ("energy_3", person.energy_z.to_numpy(), 1., True),
                        ("valence_model", person.valence_z.to_numpy(), 1.5, False),
                        ("valence_constant", np.full(len(t), np.log(.566 / .434)), 1.5, False),
                    ):
                        energy_target = target.startswith("energy")
                        answer = person["arousal" if energy_target else "valence"].to_numpy()[take]
                        if quantize:
                            answer = np.where(answer < -1, -2, np.where(answer > 1, 2, 0))
                        common = z[take]
                        label, personal, count = chronological(t[take], answer, common, tau, 2.)
                        raw = 1 / (1 + np.exp(-common))
                        baseline = energy_rank[take] if energy_target else raw
                        switched = np.where(count >= 5, 1 / (1 + np.exp(-personal)), baseline)
                        rows.setdefault(f"{target}_{rate}", []).extend(
                            zip(days[take] - days.min() + 1, label, raw, personal, baseline, switched))
                        if target == "energy_3":
                            time = 1 / (1 + np.exp(-person.time_z.to_numpy()[take]))
                            control = np.where(count >= 5, 1 / (1 + np.exp(-personal)), time_rank[take])
                            rows.setdefault(f"energy_time_control_{rate}", []).extend(
                                zip(days[take] - days.min() + 1, label, time, personal,
                                    time_rank[take], control))
                        if rate == 2 and target in ("energy_3", "valence_constant"):
                            valid = np.isfinite(label)
                            for prior, decay in ((tau, 1.), (tau, 2.), (tau, 4.), (.5 * tau, 2.), (2 * tau, 2.)):
                                _, adjusted, _ = chronological(t[take], answer, common, prior, decay)
                                # Logistic log-loss, summed over the labelled answers only.
                                loss = np.logaddexp(0, adjusted[valid]) - label[valid] * adjusted[valid]
                                key = f"{target}:tau={prior},T={decay}"
                                total = sensitivity.setdefault(key, [0., 0])
                                total[0] += float(loss.sum())
                                total[1] += len(loss)
        print(f"WP-B0: fold {fold} complete", file=sys.stderr, flush=True)
    result = json.dumps({"series": {key: summarize(value) for key, value in rows.items()},
                         "sensitivity_log_loss": {key: total / n for key, (total, n) in sensitivity.items()}},
                        indent=2)
    if args.out:
        args.out.write_text(result + "\n", encoding="utf-8")
    else:
        print(result)


if __name__ == "__main__":
    main()
