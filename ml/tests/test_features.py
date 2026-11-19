"""Features v1 (TODO 2.1-2.7). Synthetic series only: no EmoPhone data here."""

import math
import unittest

import numpy as np
import pandas as pd

from ml import features as F

MIN = 60_000
BASE_DAY = pd.Timestamp("2026-01-05")          # a Monday


def kst(day, hour, minute=0):
    """Milliseconds UTC of `day` days after Monday 2026-01-05, at hour:minute in Korea."""
    local = BASE_DAY + pd.Timedelta(days=day, hours=hour, minutes=minute)
    return local.value // 10**6 - F.KST_MS


class OrderAndTimeTests(unittest.TestCase):    # 2.1
    def test_feature_order_is_fixed(self):
        self.assertEqual(F.FEATURES, (
            "hour_sin", "hour_cos", "weekend", "z_hr_15", "z_hr_30", "z_hr_60", "zb_hr_30",
            "z_log_steps_15", "z_log_steps_30", "z_log_steps_60",
            "z_sleep_min", "hours_since_wake", "sleep_unknown"))

    def test_time_features(self):
        t = np.array([kst(0, 6), kst(5, 0), kst(6, 18, 30)])   # Mon 06:00, Sat 00:00, Sun 18:30
        tf = F.time_features(t)
        np.testing.assert_allclose(tf["hour_sin"], [1, 0, math.sin(2 * math.pi * 18.5 / 24)], atol=1e-12)
        np.testing.assert_allclose(tf["hour_cos"], [0, 1, math.cos(2 * math.pi * 18.5 / 24)], atol=1e-12)
        np.testing.assert_array_equal(tf["weekend"], [0, 1, 1])

    def test_zscore_unknown_when_std_is_zero_or_missing(self):
        z = F.zscore(np.array([12.0, 12.0, 12.0, np.nan]),
                     np.array([10.0, 10.0, np.nan, 10.0]), np.array([2.0, 0.0, 2.0, 2.0]))
        np.testing.assert_array_equal(z, [1.0, np.nan, np.nan, np.nan])


class ResampleTests(unittest.TestCase):    # 2.4
    def test_first_reading_of_each_5_minute_slice(self):
        t0 = kst(0, 10)
        ts = np.array([t0 + 4 * MIN, t0, t0 + 5 * MIN + 1000, t0 + 9 * MIN, t0 + 20 * MIN])
        v = np.array([61.0, 60.0, 70.0, 71.0, 80.0])
        rts, rv = F.resample_hr(ts, v)
        np.testing.assert_array_equal(rts, [t0, t0 + 5 * MIN + 1000, t0 + 20 * MIN])
        np.testing.assert_array_equal(rv, [60.0, 70.0, 80.0])

    def test_one_reading_is_enough_and_window_is_before_t(self):
        t = kst(0, 12)
        ts = np.array([t - 40 * MIN, t - 10 * MIN, t + 1])       # the last one is after t
        v = np.array([90.0, 60.0, 200.0])
        q = F.window_values(ts, v, np.array([], dtype=np.int64), np.array([]), np.array([t]))
        self.assertEqual(q["hr_15"][0], 60.0)
        self.assertEqual(q["hr_30"][0], 60.0)
        self.assertEqual(q["hr_60"][0], 75.0)

    def test_no_reading_means_unknown(self):
        t = kst(0, 12)
        q = F.window_values(np.array([t - 50 * MIN]), np.array([70.0]),
                            np.array([], dtype=np.int64), np.array([]), np.array([t]))
        self.assertTrue(np.isnan(q["hr_15"][0]) and np.isnan(q["hr_30"][0]))
        self.assertEqual(q["hr_60"][0], 70.0)


if __name__ == "__main__":
    unittest.main()
