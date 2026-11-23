"""Pilot analysis (TODO 4.7-4.9, docs/pilot-protocol.md section 7): aggregate tables only.

Reads the anonymous export of the app (Settings > Debug > Pilot > Export pilot data, format
harmony-pilot-1, kept in data/pilot/, never committed) and prints Markdown tables:
skip rate and "Did it fit?" by kind of queue (4.7), MuSe suggestions (4.8), watch coverage (4.9).

    python ml/pilot_analysis.py data/pilot/harmony-pilot.json
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np

FORMAT = "harmony-pilot-1"
KINDS = ("body", "timeOnly")
NAMES = {"body": "Body", "timeOnly": "Time only"}
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


def bootstrap(queues, by, metric, seed=SEED):
    """95 % interval of metric(body) - metric(time only), days resampled within each kind."""
    rng = np.random.default_rng(seed)
    groups = {}
    for kind in KINDS:
        days = sorted({q["day"] for q in queues if q.get(by) == kind})
        if not days:
            return (math.nan, math.nan)
        groups[kind] = [[q for q in queues if q.get(by) == kind and q["day"] == day] for day in days]
    diffs = []
    for _ in range(RESAMPLES):
        picked = {kind: [q for i in rng.integers(len(days), size=len(days)) for q in days[i]]
                  for kind, days in groups.items()}
        diffs.append(metric(picked["body"]) - metric(picked["timeOnly"]))
    diffs = np.asarray(diffs)
    diffs = diffs[~np.isnan(diffs)]
    if not len(diffs):
        return (math.nan, math.nan)
    low, high = np.percentile(diffs, [2.5, 97.5])
    return (float(low), float(high))


def by_kind(queues, by):
    """TODO 4.7: one column per kind, `by` = "kind" (drawn) or "stateMode" (estimate used)."""
    table = {}
    for kind in KINDS:
        rows = [q for q in queues if q.get(by) == kind]
        table[kind] = {
            "days": len({q["day"] for q in rows}),
            "queues": len(rows),
            "decided": len(decisions(rows)),
            "skip_rate": skip_rate(rows),
            "answer_rate": ratio(len(answered(rows)), len(rows)),
            "fit_rate": fit_rate(rows),
        }
    table["skip_diff"] = table["body"]["skip_rate"] - table["timeOnly"]["skip_rate"]
    table["skip_ci"] = bootstrap(queues, by, skip_rate)
    table["fit_diff"] = table["body"]["fit_rate"] - table["timeOnly"]["fit_rate"]
    table["fit_ci"] = bootstrap(queues, by, fit_rate)
    return table


def summary(data):
    queues = data["queues"]
    items = [item for q in queues for item in q["items"]]
    body = [q for q in queues if q["kind"] == "body"]
    watch = data["watch"]
    return {
        "by_kind": by_kind(queues, "kind"),
        "by_mode": by_kind(queues, "stateMode"),
        "muse": {  # TODO 4.8
            "queues_with_suggestion": (sum(any(i["suggestion"] for i in q["items"]) for q in queues), len(queues)),
            "suggested_songs": (sum(i["suggestion"] for i in items), len(items)),
            "skip_suggestions": (decisions(queues, True).count("skip"), len(decisions(queues, True))),
            "skip_library": (decisions(queues, False).count("skip"), len(decisions(queues, False))),
        },
        "watch": {  # TODO 4.9
            "nights_known": (watch["nightsKnown"], data["days"]),
            "hours_with_hr": (watch["hoursWithHR"], watch["hours"]),
            "body_fallback": (sum(q.get("stateMode") == "timeOnly" for q in body), len(body)),
        },
    }


def number(value, signed=False):
    if math.isnan(value):
        return "–"
    return f"{value:+.2f}" if signed else f"{value:.2f}"


def kind_table(table, title):
    body, time_only = table["body"], table["timeOnly"]

    def diff(key):
        low, high = table[f"{key}_ci"]
        return f"{number(table[f'{key}_diff'], True)} [{number(low, True)}, {number(high, True)}]"

    rows = [
        ("Days", body["days"], time_only["days"], ""),
        ("Queues", body["queues"], time_only["queues"], ""),
        ("Songs skipped or finished", body["decided"], time_only["decided"], ""),
        ("Skip rate (< 30 s)", number(body["skip_rate"]), number(time_only["skip_rate"]), diff("skip")),
        ("\"Did it fit?\" answered", number(body["answer_rate"]), number(time_only["answer_rate"]), ""),
        ("\"Yes\" among answers", number(body["fit_rate"]), number(time_only["fit_rate"]), diff("fit")),
    ]
    lines = [f"**{title}**", "",
             f"| | {NAMES['body']} | {NAMES['timeOnly']} | Body − time only [95 % CI, days] |",
             "|---|---:|---:|---:|"]
    return "\n".join(lines + [f"| {name} | {a} | {b} | {c} |" for name, a, b, c in rows])


def count_table(rows, title):
    lines = [f"**{title}**", "", "| | Count | Share |", "|---|---:|---:|"]
    lines += [f"| {name} | {num}/{den} | {number(ratio(num, den))} |" for name, (num, den) in rows]
    return "\n".join(lines)


def markdown(result):
    muse, watch = result["muse"], result["watch"]
    return "\n\n".join([
        kind_table(result["by_kind"], "TODO 4.7 — by kind drawn for the day"),
        kind_table(result["by_mode"], "TODO 4.7 — by estimate really used"),
        count_table([("Queues with ≥ 1 MuSe suggestion", muse["queues_with_suggestion"]),
                     ("Songs that are MuSe suggestions", muse["suggested_songs"]),
                     ("Skip rate, MuSe suggestions", muse["skip_suggestions"]),
                     ("Skip rate, library songs", muse["skip_library"])], "TODO 4.8 — MuSe fallback"),
        count_table([("Nights with known sleep", watch["nights_known"]),
                     ("Hours with a heart rate", watch["hours_with_hr"]),
                     ("Body queues started from the time of day only", watch["body_fallback"])],
                    "TODO 4.9 — watch coverage"),
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("export", nargs="?", default="data/pilot/harmony-pilot.json")
    args = parser.parse_args()
    print(markdown(summary(load(args.export))))


if __name__ == "__main__":
    main()
