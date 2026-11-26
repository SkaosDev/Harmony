"""Pilot analysis (TODO 4.7-4.9, 6.15, docs/pilot-protocol.md section 7): aggregate tables only.

Reads the anonymous export of the app (Settings > Debug > Pilot > Export pilot data, format
harmony-pilot-2, kept in data/pilot/, never committed) and prints Markdown tables:
skip rate and "Did it fit?" over the week (4.7), MuSe suggestions (4.8), watch coverage (4.9),
check-ins (6.15, analysis WP-P of the design v2): answer rate, chronological AUROC of the common
model and of the personal layer by days of use, reward by queue strategy.

    python ml/pilot_analysis.py data/pilot/harmony-pilot.json
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np

FORMAT = "harmony-pilot-2"
RESAMPLES = 2000
SEED = 406
# Days of use of the chronological AUROC, fixed before the data (protocol section 7.3).
DAY_BINS = (("Days 1–3", 1, 3), ("Days 4–7", 4, 7), ("Whole week", 1, math.inf))
LIKE_BONUS = 0.2


def load(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("format") != FORMAT:
        raise ValueError(f"{path}: format {data.get('format')!r}, expected {FORMAT!r}")
    return data


def ratio(num, den):
    return num / den if den else math.nan


def decisions(queues, suggestion=None):
    """Skip and finish events of the queues (a song left between 30 s and its end gives none);
    `suggestion` keeps only MuSe suggestions (True) or library songs (False)."""
    events = []
    for queue in queues:
        is_suggestion = {item["position"]: item["suggestion"] for item in queue["items"]}
        events += [e["event"] for e in queue["events"]
                   if e["event"] in ("skip", "finish") and suggestion in (None, is_suggestion[e["position"]])]
    return events


def skip_rate(queues, suggestion=None):
    events = decisions(queues, suggestion)
    return ratio(events.count("skip"), len(events))


def answered(queues):
    return [q for q in queues if q.get("fit") in ("yes", "no")]


def fit_rate(queues):
    answers = answered(queues)
    return ratio(sum(q["fit"] == "yes" for q in answers), len(answers))


def bootstrap(queues, metric, key="day", seed=SEED):
    """95 % interval of metric over the week, days resampled (protocol section 7.4): pilot days for
    the queues, days of use (`key="dayOfUse"`) for the check-ins."""
    days = sorted({q[key] for q in queues})
    if not days:
        return (math.nan, math.nan)
    groups = [[q for q in queues if q[key] == day] for day in days]
    rng = np.random.default_rng(seed)
    values = np.asarray([metric([q for i in rng.integers(len(groups), size=len(groups)) for q in groups[i]])
                         for _ in range(RESAMPLES)])
    values = values[~np.isnan(values)]
    if not len(values):
        return (math.nan, math.nan)
    low, high = np.percentile(values, [2.5, 97.5])
    return (float(low), float(high))


def week(queues):
    """TODO 4.7: skip and fit rates over the week; every pilot day uses the watch (TODO 4.4)."""
    return {
        "days": len({q["day"] for q in queues}),
        "queues": len(queues),
        "decided": len(decisions(queues)),
        "skip_rate": skip_rate(queues),
        "skip_ci": bootstrap(queues, skip_rate),
        "answer_rate": ratio(len(answered(queues)), len(queues)),
        "fit_rate": fit_rate(queues),
        "fit_ci": bootstrap(queues, fit_rate),
    }


def auroc(pairs, probability):
    """AUROC of `probability` ("pCommonBefore" or "pPersonalBefore") against the label; NaN with a
    single label value."""
    above = np.asarray([p[probability] for p in pairs if p["labelEnergy"]])
    below = np.asarray([p[probability] for p in pairs if not p["labelEnergy"]])
    if not len(above) or not len(below):
        return math.nan
    # Share of (above, below) pairs ranked in the right order, ties counted half (Mann-Whitney).
    diff = above[:, None] - below[None, :]
    return float(((diff > 0).sum() + 0.5 * (diff == 0).sum()) / diff.size)


def gain(pairs):
    return auroc(pairs, "pPersonalBefore") - auroc(pairs, "pCommonBefore")


def labelled(pairs):
    """Answers with a label and both probabilities (an answer given on the lock screen gets them
    at the next opening of the app)."""
    return [p for p in pairs if p.get("labelEnergy") is not None
            and p.get("pCommonBefore") is not None and p.get("pPersonalBefore") is not None]


def chronological(pairs):
    """TODO 6.15: AUROC of the common model and of the personal layer, each answer predicted from
    the earlier ones only (decision D8), by days of use; same resamples for the three intervals."""
    rows = []
    for name, first, last in DAY_BINS:
        part = [p for p in labelled(pairs) if first <= p["dayOfUse"] <= last]
        rows.append({
            "bin": name, "n": len(part), "above": sum(p["labelEnergy"] for p in part),
            "common": auroc(part, "pCommonBefore"),
            "common_ci": bootstrap(part, lambda ps: auroc(ps, "pCommonBefore"), key="dayOfUse"),
            "personal": auroc(part, "pPersonalBefore"),
            "personal_ci": bootstrap(part, lambda ps: auroc(ps, "pPersonalBefore"), key="dayOfUse"),
            "difference": gain(part),
            "difference_ci": bootstrap(part, gain, key="dayOfUse"),
        })
    return rows


def reward(queue):
    """Reward of a queue, rule of the app (`QueueBandit.reward`, design v2 section 4.6): "Did it
    fit?" yes 1, no 0; without an answer, 1 - share of skips among skipped or finished songs;
    +0.2 per like, at most 1. None with neither an answer nor a skipped or finished song."""
    events = [e["event"] for e in queue["events"]]
    decided = [e for e in events if e in ("skip", "finish")]
    if queue.get("fit") in ("yes", "no"):
        base = 1.0 if queue["fit"] == "yes" else 0.0
    elif decided:
        base = 1 - decided.count("skip") / len(decided)
    else:
        return None
    return min(1.0, base + LIKE_BONUS * events.count("like"))


def mean_reward(queues):
    rewards = [r for r in map(reward, queues) if r is not None]
    return float(np.mean(rewards)) if rewards else math.nan


def strategies(queues):
    """TODO 6.15: mean reward of the queues of each logged strategy (S1 only during the pilot)."""
    rows = []
    for strategy in sorted({q["strategy"] for q in queues if q.get("strategy")}):
        part = [q for q in queues if q.get("strategy") == strategy]
        rows.append({"strategy": strategy, "n": sum(reward(q) is not None for q in part),
                     "mean": mean_reward(part), "ci": bootstrap(part, mean_reward)})
    return rows


def summary(data):
    queues = data["queues"]
    items = [item for q in queues for item in q["items"]]
    watch = data["watch"]
    pairs, prompts = data["checkIns"], data["prompts"]
    sent = prompts["answered"] + prompts["notNow"] + prompts["ignored"]
    return {
        "week": week(queues),
        "muse": {  # TODO 4.8
            "queues_with_suggestion": (sum(any(i["suggestion"] for i in q["items"]) for q in queues), len(queues)),
            "suggested_songs": (sum(i["suggestion"] for i in items), len(items)),
            "skip_suggestions": (decisions(queues, True).count("skip"), len(decisions(queues, True))),
            "skip_library": (decisions(queues, False).count("skip"), len(decisions(queues, False))),
        },
        "watch": {  # TODO 4.9
            "nights_known": (watch["nightsKnown"], data["days"]),
            "hours_with_hr": (watch["hoursWithHR"], watch["hours"]),
            "time_fallback": (sum(q.get("stateMode") == "timeOnly" for q in queues), len(queues)),
        },
        "checkins": {  # TODO 6.15
            "prompts": prompts,
            "answer_rate": ratio(prompts["answered"], sent),
            "sent": sent,
            "answers": len(pairs),
            "labelled": len(labelled(pairs)),
            "auroc": chronological(pairs),
        },
        "strategies": strategies(queues),  # TODO 6.15
    }


def number(value):
    return "–" if math.isnan(value) else f"{value:.2f}"


def interval(value, ci):
    return f"{number(value)} [{number(ci[0])}, {number(ci[1])}]"


def cell(value, ci):
    return "–" if math.isnan(value) else interval(value, ci)


def week_table(table, title):
    rows = [
        ("Days with a queue", table["days"]),
        ("Queues", table["queues"]),
        ("Songs skipped or finished", table["decided"]),
        ("Skip rate (< 30 s)", interval(table["skip_rate"], table["skip_ci"])),
        ("\"Did it fit?\" answered", number(table["answer_rate"])),
        ("\"Yes\" among answers", interval(table["fit_rate"], table["fit_ci"])),
    ]
    lines = [f"**{title}**", "", "| | Week [95 % CI, days] |", "|---|---:|"]
    return "\n".join(lines + [f"| {name} | {value} |" for name, value in rows])


def count_table(rows, title):
    lines = [f"**{title}**", "", "| | Count | Share |", "|---|---:|---:|"]
    lines += [f"| {name} | {num}/{den} | {number(ratio(num, den))} |" for name, (num, den) in rows]
    return "\n".join(lines)


def auroc_table(rows, title):
    lines = [f"**{title}**", "",
             "| Days of use | Labelled answers | Above the usual | Common [95 % CI] | Personal [95 % CI] "
             "| Personal − common [95 % CI] |",
             "|---|---:|---:|---:|---:|---:|"]
    lines += [f"| {r['bin']} | {r['n']} | {r['above']} | {cell(r['common'], r['common_ci'])} "
              f"| {cell(r['personal'], r['personal_ci'])} | {cell(r['difference'], r['difference_ci'])} |"
              for r in rows]
    return "\n".join(lines)


def strategy_table(rows, title):
    lines = [f"**{title}**", "", "| Strategy | Queues with a reward | Mean reward [95 % CI, days] |", "|---|---:|---:|"]
    return "\n".join(lines + [f"| {r['strategy']} | {r['n']} | {cell(r['mean'], r['ci'])} |" for r in rows])


def markdown(result):
    muse, watch, checkins = result["muse"], result["watch"], result["checkins"]
    prompts, sent = checkins["prompts"], checkins["sent"]
    return "\n\n".join([
        week_table(result["week"], "TODO 4.7 — over the week"),
        count_table([("Queues with ≥ 1 MuSe suggestion", muse["queues_with_suggestion"]),
                     ("Songs that are MuSe suggestions", muse["suggested_songs"]),
                     ("Skip rate, MuSe suggestions", muse["skip_suggestions"]),
                     ("Skip rate, library songs", muse["skip_library"])], "TODO 4.8 — MuSe fallback"),
        count_table([("Nights with known sleep", watch["nights_known"]),
                     ("Hours with a heart rate", watch["hours_with_hr"]),
                     ("Queues started from the time of day only", watch["time_fallback"])],
                    "TODO 4.9 — watch coverage"),
        count_table([("Answered", (prompts["answered"], sent)),
                     ("\"Not now\"", (prompts["notNow"], sent)),
                     ("Ignored", (prompts["ignored"], sent)),
                     ("Answers with a label", (checkins["labelled"], checkins["answers"]))],
                    f"TODO 6.15 — questions (still waiting at the export: {prompts['waiting']})"),
        auroc_table(checkins["auroc"], "TODO 6.15 — chronological AUROC, \"above the usual\""),
        strategy_table(result["strategies"], "TODO 6.15 — reward by queue strategy"),
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("export", nargs="?", default="data/pilot/harmony-pilot.json")
    args = parser.parse_args()
    print(markdown(summary(load(args.export))))


if __name__ == "__main__":
    main()
