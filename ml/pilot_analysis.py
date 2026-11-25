"""Pilot analysis (TODO 4.7-4.9, docs/pilot-protocol.md section 7): aggregate tables only.

Reads the anonymous export of the app (Settings > Debug > Pilot > Export pilot data, format
harmony-pilot-1, kept in data/pilot/, never committed) and prints Markdown tables:
skip rate and "Did it fit?" over the week (4.7), MuSe suggestions (4.8), watch coverage (4.9).

    python ml/pilot_analysis.py data/pilot/harmony-pilot.json
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np

FORMAT = "harmony-pilot-1"
RESAMPLES = 2000
SEED = 406


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


def bootstrap(queues, metric, seed=SEED):
    """95 % interval of metric over the week, pilot days resampled (protocol section 7.4)."""
    days = sorted({q["day"] for q in queues})
    if not days:
        return (math.nan, math.nan)
    groups = [[q for q in queues if q["day"] == day] for day in days]
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


def summary(data):
    queues = data["queues"]
    items = [item for q in queues for item in q["items"]]
    watch = data["watch"]
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
    }


def number(value):
    return "–" if math.isnan(value) else f"{value:.2f}"


def interval(value, ci):
    return f"{number(value)} [{number(ci[0])}, {number(ci[1])}]"


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


def markdown(result):
    muse, watch = result["muse"], result["watch"]
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
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("export", nargs="?", default="data/pilot/harmony-pilot.json")
    args = parser.parse_args()
    print(markdown(summary(load(args.export))))


if __name__ == "__main__":
    main()
