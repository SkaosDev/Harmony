"""Write synthetic golden cases for the v2 energy-only personal layer."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

from personal_layer import (DECAY_DAYS, ENERGY_PRIOR_STD, MIN_LABEL_RESPONSES, NEWTON_STEPS, WINDOW,
                            Observation, estimate, past_label)

OUT = Path(__file__).resolve().parent / "fixtures" / "personal_layer_cases.json"
START = datetime(2026, 12, 1, 12, tzinfo=timezone.utc)


def item(hours, energy, z, label, usable=True):
    return Observation(START + timedelta(hours=hours), energy, z, label, usable)


def encode(observation):
    return {"answered_at": observation.answered_at.isoformat().replace("+00:00", "Z"),
            "energy": observation.energy, "z_energy": observation.z_energy,
            "label": observation.label, "usable": observation.usable}


def main():
    labelled = [item(i * 6, value, -0.2 + i * 0.08, value > 0)
                for i, value in enumerate([-2, 0, 1, -1, 2, 1])]
    now = START + timedelta(days=20)
    edges = [Observation(now - WINDOW - timedelta(minutes=1), 2, 0.4, True),   # older than 14 days
             Observation(now - WINDOW, -1, -0.3, False),                       # exactly 14 days: kept
             Observation(now - timedelta(days=3), 2, 0.1, True),
             Observation(now - timedelta(days=2), 1, 0.2, None),               # no label yet
             Observation(now - timedelta(days=1), -2, -0.5, False, False),     # not usable
             Observation(now - timedelta(hours=12), 1, 0.0, True),
             Observation(now, 3, 0.6, True)]                                   # at `now`: not past
    cases = [
        ("no_label", START + timedelta(days=4), 0.25, []),
        ("recent_high", START + timedelta(hours=38), -0.1, labelled),
        ("old_answers_decay", START + timedelta(days=8), 0.3, labelled),
        ("unusable_is_ignored", START + timedelta(hours=38), -0.1,
         labelled + [item(30, 3, -0.8, True, False)]),
        ("window_boundaries", now, 0.1, edges),
    ]
    output = []
    for name, now, z, observations in cases:
        b, p, count = estimate(now, z, observations)
        output.append({"name": name, "now": now.isoformat().replace("+00:00", "Z"),
                       "z_energy": z, "observations": [encode(x) for x in observations],
                       "offset": b, "probability": p, "usable_labelled_count": count})
    labels = [item(i * 24, value, 0, None) for i, value in enumerate([-2, 0, 1, -1, 2])]
    # Mean of the 5 kept answers 0.6 < 1: True. Keeping either excluded answer gives False;
    # dropping the one at exactly 14 days leaves 4 answers: no label.
    prior = [Observation(now - WINDOW - timedelta(minutes=1), 3, 0, None),
             Observation(now - WINDOW, -2, 0, None),
             *(Observation(now - timedelta(days=d), v, 0, None) for d, v in ((10, 1), (6, 1), (2, 1), (1, 2))),
             Observation(now, 3, 0, None)]
    for name, answered_at, energy, responses in (("past_label", START + timedelta(days=6), 1, labels),
                                                  ("past_label_window_boundaries", now, 1, prior)):
        output.append({"name": name, "now": answered_at.isoformat().replace("+00:00", "Z"),
                       "energy": energy, "prior_responses": [encode(x) for x in responses],
                       "label": past_label(answered_at, energy, responses)})
    OUT.write_text(json.dumps({"version": 1, "window_days": WINDOW.days,
                               "decay_days": DECAY_DAYS, "prior_std": ENERGY_PRIOR_STD,
                               "minimum_past_responses": MIN_LABEL_RESPONSES, "newton_steps": NEWTON_STEPS,
                               "cases": output}, indent=2) + "\n")


if __name__ == "__main__":
    main()
