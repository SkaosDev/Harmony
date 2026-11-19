"""Features v1 of the state model (TODO 2.1-2.7): the single source of truth.

Pure functions only: nothing here reads a file. Timestamps are milliseconds UTC (as in
EmoPhone); local time is Korea (UTC+9). Every definition is written in docs/PROJECT.md §6,
"Features v1"; the Swift app must compute exactly the same values.
"""
import numpy as np

KST_MS = 9 * 3600 * 1000  # timestamps are UTC; Korea is UTC+9
MIN_MS = 60_000
DAY_MS = 1440 * MIN_MS
WINDOWS = (15, 30, 60)    # minutes before t
RESAMPLE_MIN = 5          # heart rate kept: 1 reading / 5 min (Apple Watch rate, §6.4)
REFERENCE_DAYS = 14       # personal references use the 14 days before t only
READY_DAYS = 7            # ... and need values on at least 7 distinct local days
GRID_STEP_MIN = 30        # reference grid: every 30 min ...
GRID_HOURS = (8, 24)      # ... from 08:00 to 23:30, local time
BLOCK_MIN = 180           # zb_hr_30 compares with the same 3-hour block
QUANTITIES = ("hr_15", "hr_30", "hr_60", "log_steps_15", "log_steps_30", "log_steps_60")

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


def resample_hr(ts, values):
    """First heart-rate reading of each 5-minute slice of the clock (like s_hr in v0)."""
    ts = np.asarray(ts, dtype=np.int64)
    order = np.argsort(ts, kind="stable")
    ts, values = ts[order], np.asarray(values, dtype=float)[order]
    slice_ = ts // (RESAMPLE_MIN * MIN_MS)
    first = np.r_[True, slice_[1:] != slice_[:-1]]
    return ts[first], values[first]


def _in_window(ts, t, minutes):
    """Index bounds of the readings in (t - minutes, t], for every t."""
    return (np.searchsorted(ts, t - minutes * MIN_MS, "right"),
            np.searchsorted(ts, t, "right"))


def window_values(hr_ts, hr_v, st_ts, st_v, t):
    """Window quantities at every instant t, for the answers and for the reference grid.

    hr_ts/hr_v: resampled heart rate, sorted; st_ts/st_v: step counts, sorted.
    - hr_w: mean heart rate in (t - w, t], unknown (NaN) without any reading.
    - log_steps_w: log(1 + steps in (t - w, t]); 0 when the watch is worn (a heart rate in
      the window) without steps; unknown when there is neither heart rate nor steps.
    """
    t = np.asarray(t, dtype=np.int64)
    hr_sum = np.r_[0.0, np.cumsum(hr_v)]
    st_sum = np.r_[0.0, np.cumsum(st_v)]
    out = {}
    for w in WINDOWS:
        lo, hi = _in_window(hr_ts, t, w)
        n = hi - lo
        with np.errstate(invalid="ignore", divide="ignore"):
            out[f"hr_{w}"] = np.where(n > 0, (hr_sum[hi] - hr_sum[lo]) / n, np.nan)
        s_lo, s_hi = _in_window(st_ts, t, w)
        known = (n > 0) | (s_hi > s_lo)
        out[f"log_steps_{w}"] = np.where(known, np.log1p(st_sum[s_hi] - st_sum[s_lo]), np.nan)
    return out


def grid_points(start, end):
    """Reference grid instants in [start, end): 08:00, 08:30 ... 23:30 local time."""
    days = np.arange(local_minute(start) // 1440, local_minute(end) // 1440 + 1)
    offsets = np.arange(GRID_HOURS[0] * 60, GRID_HOURS[1] * 60, GRID_STEP_MIN)
    g = ((days[:, None] * 1440 + offsets[None, :]) * MIN_MS - KST_MS).ravel()
    return g[(g >= start) & (g < end)]


def block(t):
    """3-hour block of the local time of day (0 = 00:00-03:00 ... 7 = 21:00-24:00)."""
    return (local_minute(t) % 1440) // BLOCK_MIN


def reference(values, days, min_days=READY_DAYS):
    """Personal mean and standard deviation (ddof=1) of the known values.

    Unknown (NaN, NaN) unless the known values come from at least `min_days` distinct days.
    """
    values = np.asarray(values, dtype=float)
    known = ~np.isnan(values)
    if len(np.unique(np.asarray(days)[known])) < min_days:
        return np.nan, np.nan
    return values[known].mean(), values[known].std(ddof=1)


def past_reference(t, grid_t, values, days, min_days=READY_DAYS):
    """Reference at t from the grid points in [t - 14 days, t): nothing at or after t."""
    lo = np.searchsorted(grid_t, t - REFERENCE_DAYS * DAY_MS, "left")
    hi = np.searchsorted(grid_t, t, "left")
    return reference(values[lo:hi], days[lo:hi], min_days)


def zscore(x, mean, std):
    """(x - mean) / std; unknown (NaN) when a term is unknown or std is 0."""
    x, mean, std = (np.asarray(a, dtype=float) for a in (x, mean, std))
    with np.errstate(invalid="ignore", divide="ignore"):
        return np.where(std > 0, (x - mean) / std, np.nan)


def participant_features(answer_t, hr_ts, hr_v, st_ts, st_v):
    """The v1 features of one participant at each answer time (ms UTC).

    hr_ts/hr_v: raw heart rate; st_ts/st_v: step counts. Returns {feature name: array}.
    """
    answer_t = np.asarray(answer_t, dtype=np.int64)
    st_ts = np.asarray(st_ts, dtype=np.int64)
    order = np.argsort(st_ts, kind="stable")
    st_ts, st_v = st_ts[order], np.asarray(st_v, dtype=float)[order]
    hr5_ts, hr5_v = resample_hr(hr_ts, hr_v)

    grid_t = grid_points(answer_t.min() - REFERENCE_DAYS * DAY_MS, answer_t.max())
    grid_days, grid_block = local_minute(grid_t) // 1440, block(grid_t)
    grid = window_values(hr5_ts, hr5_v, st_ts, st_v, grid_t)
    now = window_values(hr5_ts, hr5_v, st_ts, st_v, answer_t)

    out = time_features(answer_t)
    for q in QUANTITIES:
        out["z_" + q] = np.full(len(answer_t), np.nan)
    out["zb_hr_30"] = np.full(len(answer_t), np.nan)
    for i, (t, b) in enumerate(zip(answer_t, block(answer_t))):
        for q in QUANTITIES:
            out["z_" + q][i] = zscore(now[q][i], *past_reference(t, grid_t, grid[q], grid_days))
        _, std = past_reference(t, grid_t, grid["hr_30"], grid_days)
        same_block = np.where(grid_block == b, grid["hr_30"], np.nan)
        block_mean, _ = past_reference(t, grid_t, same_block, grid_days)
        out["zb_hr_30"][i] = zscore(now["hr_30"][i], block_mean, std)
    return out
