"""Write synthetic golden cases for the v2 energy-only personal layer."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

from personal_layer import Observation, estimate, past_label

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
    cases = [
        ("no_label", START + timedelta(days=4), 0.25, []),
        ("recent_high", START + timedelta(hours=38), -0.1, labelled),
        ("old_answers_decay", START + timedelta(days=8), 0.3, labelled),
        ("unusable_is_ignored", START + timedelta(hours=38), -0.1,
         labelled + [item(30, 3, -0.8, True, False)]),
    ]
    output = []
    for name, now, z, observations in cases:
        b, p, count = estimate(now, z, observations)
        output.append({"name": name, "now": now.isoformat().replace("+00:00", "Z"),
                       "z_energy": z, "observations": [encode(x) for x in observations],
                       "offset": b, "probability": p, "usable_labelled_count": count})
    labels = [item(i * 24, value, 0, None) for i, value in enumerate([-2, 0, 1, -1, 2])]
    output.append({"name": "past_label", "now": (START + timedelta(days=6)).isoformat().replace("+00:00", "Z"),
                   "energy": 1, "prior_responses": [encode(x) for x in labels],
                   "label": past_label(START + timedelta(days=6), 1, labels)})
    OUT.write_text(json.dumps({"version": 1, "decay_days": 2, "prior_std": 1,
                               "minimum_past_responses": 5, "newton_steps": 5, "cases": output}, indent=2) + "\n")


if __name__ == "__main__":
    main()
