"""Features v1 of the state model (TODO 2.1-2.7): the single source of truth.

Pure functions only: nothing here reads a file. Timestamps are milliseconds UTC (as in
EmoPhone); local time is Korea (UTC+9). Every definition is written in docs/PROJECT.md §6,
"Features v1"; the Swift app must compute exactly the same values.
"""
import numpy as np

KST_MS = 9 * 3600 * 1000  # timestamps are UTC; Korea is UTC+9
MIN_MS = 60_000
DAY_MS = 1440 * MIN_MS

# The model input, in this fixed order (exported to the app with the model).
FEATURES = (
    "hour_sin", "hour_cos", "weekend", "z_hr_15", "z_hr_30", "z_hr_60", "zb_hr_30",
    "z_log_steps_15", "z_log_steps_30", "z_log_steps_60",
    "z_sleep_min", "hours_since_wake", "sleep_unknown",
)


def local_minute(t):
    """Minutes since 1970-01-01 00:00, Korean time."""
    return (np.asarray(t, dtype=np.int64) + KST_MS) // MIN_MS


def time_features(t):
    """hour_sin, hour_cos (local hour + minutes / 60) and weekend (Saturday or Sunday)."""
    minute = local_minute(t)
    hour = (minute % 1440) / 60
    weekday = (minute // 1440 + 3) % 7                # 1970-01-01 was a Thursday (3)
    return {"hour_sin": np.sin(2 * np.pi * hour / 24),
            "hour_cos": np.cos(2 * np.pi * hour / 24),
            "weekend": (weekday >= 5).astype(int)}


def zscore(x, mean, std):
    """(x - mean) / std; unknown (NaN) when a term is unknown or std is 0."""
    x, mean, std = (np.asarray(a, dtype=float) for a in (x, mean, std))
    with np.errstate(invalid="ignore", divide="ignore"):
        return np.where(std > 0, (x - mean) / std, np.nan)
