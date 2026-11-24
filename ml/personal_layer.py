"""Pure reference implementation of the pilot's energy-only personal layer.

This deliberately does not train or alter the shared state model.  It implements
the fixed ``L_past`` label and the decaying one-dimensional MAP offset from the
v2 design, so the JSON fixture can protect the Python/Swift boundary.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Iterable

WINDOW = timedelta(days=14)
MIN_LABEL_RESPONSES = 5
DECAY_DAYS = 2.0
ENERGY_PRIOR_STD = 1.0
NEWTON_STEPS = 5


@dataclass(frozen=True)
class Observation:
    answered_at: datetime
    energy: int
    z_energy: float
    label: bool | None
    usable: bool = True


def sigmoid(value: float) -> float:
    return 1.0 / (1.0 + math.exp(-value))


def past_label(answered_at: datetime, energy: int, prior: Iterable[Observation]) -> bool | None:
    """The label fixed when a response is recorded; future answers never enter it."""
    values = [item.energy for item in prior
              if answered_at - WINDOW <= item.answered_at < answered_at]
    if len(values) < MIN_LABEL_RESPONSES:
        return None
    return energy > sum(values) / len(values)


def estimate(now: datetime, z_energy: float, observations: Iterable[Observation]) -> tuple[float, float, int]:
    """Return (offset, personalised probability, usable labelled response count)."""
    usable = [item for item in observations
              if item.usable and item.label is not None and now - WINDOW <= item.answered_at < now]
    if not usable:
        return 0.0, sigmoid(z_energy), 0
    offset = 0.0
    for _ in range(NEWTON_STEPS):
        gradient = offset / ENERGY_PRIOR_STD ** 2
        hessian = 1.0 / ENERGY_PRIOR_STD ** 2
        for item in usable:
            age_days = (now - item.answered_at).total_seconds() / 86_400
            weight = math.exp(-age_days / DECAY_DAYS)
            probability = sigmoid(item.z_energy + offset)
            gradient += weight * (probability - int(item.label))
            hessian += weight * probability * (1.0 - probability)
        offset -= gradient / hessian
    return offset, sigmoid(z_energy + offset), len(usable)
