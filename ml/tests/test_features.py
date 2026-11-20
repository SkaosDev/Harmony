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

    def test_no_heart_rate_at_all(self):
        empty = np.array([], dtype=np.int64)
        self.assertEqual(len(F.resample_hr(empty, np.array([]))[0]), 0)
        f = F.participant_features(np.array([kst(9, 14), kst(9, 9)]), empty, np.array([]),
                                   empty, np.array([]), np.nan)
        self.assertTrue(np.isnan(f["z_hr_30"]).all() and np.isnan(f["z_sleep_min"]).all())
        np.testing.assert_array_equal(f["sleep_unknown"], [1, 1])

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


class ReferenceTests(unittest.TestCase):    # 2.2
    def test_ready_only_with_7_days_of_data(self):
        days = np.repeat(np.arange(7), 2)
        values = np.arange(14, dtype=float)
        mean, std = F.reference(values, days)
        self.assertAlmostEqual(mean, values.mean())
        self.assertAlmostEqual(std, values.std(ddof=1))
        values[days == 6] = np.nan                       # day 6 has no value: 6 days left
        self.assertTrue(all(np.isnan(F.reference(values, days))))

    def test_only_the_14_previous_days_are_used(self):
        t = kst(20, 12)
        grid_t = np.array([kst(d, 12) for d in range(30)])
        days = np.arange(30)
        values = np.full(30, 70.0)
        values[6:20] = np.arange(14) + 60.0               # [t - 14 days, t): days 6..19
        expected = F.past_reference(t, grid_t, values, days)
        extreme = values.copy()
        extreme[20:] = 1e6                               # at t and in the future
        extreme[:6] = -1e6                               # more than 14 days before t
        self.assertEqual(F.past_reference(t, grid_t, extreme, days), expected)
        self.assertAlmostEqual(expected[0], 66.5)


class GridTests(unittest.TestCase):    # 2.3
    def test_grid_every_30_min_from_8_to_23_30_local(self):
        g = F.grid_points(kst(0, 0), kst(1, 0))
        self.assertEqual(len(g), 32)
        self.assertEqual((g[0], g[-1]), (kst(0, 8), kst(0, 23, 30)))
        np.testing.assert_array_equal(np.diff(g), 30 * MIN)

    def test_steps_known_when_worn_or_counted(self):
        t = kst(0, 12)
        hr_ts = np.array([t - 5 * MIN])
        st_ts = np.array([t - 50 * MIN, t - 20 * MIN])   # sorted
        q = F.window_values(hr_ts, np.array([60.0]), st_ts, np.array([9.0, 30.0]), np.array([t]))
        self.assertEqual(q["log_steps_15"][0], 0.0)                 # worn, no steps
        self.assertAlmostEqual(q["log_steps_30"][0], math.log1p(30))
        self.assertAlmostEqual(q["log_steps_60"][0], math.log1p(39))
        q = F.window_values(np.array([], dtype=np.int64), np.array([]), st_ts,
                            np.array([9.0, 30.0]), np.array([t]))
        self.assertTrue(np.isnan(q["log_steps_15"][0]))           # not worn, no steps
        self.assertAlmostEqual(q["log_steps_30"][0], math.log1p(30))   # steps counted

    def test_features_use_the_grid_reference(self):
        rng = np.random.default_rng(0)
        hr_ts = np.arange(kst(0, 0), kst(21, 0), 5 * MIN)         # worn all the time
        hr_v = 60 + 10 * rng.random(len(hr_ts))
        answers = np.array([kst(20, 3), kst(20, 14), kst(3, 14)])   # 03:00, 14:00, day 3
        f = F.participant_features(answers, hr_ts, hr_v, np.array([], dtype=np.int64), np.array([]),
                                   F.sleep_threshold(hr_ts, hr_v))
        g = F.grid_points(kst(6, 14), kst(20, 14))
        gq = F.window_values(hr_ts, hr_v, np.array([], dtype=np.int64), np.array([]), g)
        x = F.window_values(hr_ts, hr_v, np.array([], dtype=np.int64), np.array([]),
                            answers[1:2])["hr_30"][0]
        mean, std = gq["hr_30"].mean(), gq["hr_30"].std(ddof=1)
        in_block = (F.local_minute(g) % 1440) // 180 == 4                 # 12:00-15:00
        self.assertAlmostEqual(f["z_hr_30"][1], (x - mean) / std)
        self.assertAlmostEqual(f["zb_hr_30"][1], (x - gq["hr_30"][in_block].mean()) / std)
        self.assertTrue(np.isnan(f["zb_hr_30"][0]))     # 03:00: no grid point in its block
        self.assertFalse(np.isnan(f["z_hr_30"][0]))
        self.assertTrue(np.isnan(f["z_hr_30"][2]))      # day 3: fewer than 7 days of data
        self.assertTrue(np.isnan(f["z_log_steps_15"][1]))   # always 0 steps: std 0 -> unknown


def bed_minute(wake_day):
    """Synthetic bedtime, in minutes from the wake day's midnight: 23:00, 23:15, 23:30, 23:45."""
    return -60 + 15 * (wake_day % 4)


def sleeper(days=21):
    """A synthetic wearer: heart rate every minute, low and without steps from bedtime to 07:00."""
    hr_ts = np.arange(kst(0, 0), kst(days, 0), MIN)
    minute = F.local_minute(hr_ts)
    tod = minute % 1440
    evening = tod >= 21 * 60
    wake_day = minute // 1440 + evening - F.local_minute(kst(0, 0)) // 1440   # day 0 = BASE_DAY
    rel =tod - 1440 * evening                       # minutes from the wake day's midnight
    asleep = (rel >= bed_minute(wake_day)) & (rel < 7 * 60)
    hr_v = np.where(asleep, 50.0, 75.0) + minute % 7
    st_ts = hr_ts[~asleep & (tod % 10 == 0)]
    return hr_ts, hr_v, st_ts, np.full(len(st_ts), 20.0)


class SleepTests(unittest.TestCase):    # 2.5
    def setUp(self):
        self.hr_ts, self.hr_v, self.st_ts, self.st_v = sleeper()
        self.mhr = F.minute_hr(self.hr_ts, self.hr_v)
        self.mst = F.minute_steps(self.st_ts, self.st_v)
        self.thr = F.sleep_threshold(self.hr_ts, self.hr_v)

    def test_full_night(self):
        sleep, wake, coverage = F.night(self.mhr, self.mst, self.thr, wake_day=self.day(10))
        self.assertEqual(sleep, 7 * 60 - bed_minute(10))
        self.assertEqual(wake, self.day(10) * 1440 + 7 * 60 - 1)          # 06:59
        self.assertEqual(coverage, 1.0)

    def test_nothing_after_the_answer(self):
        t = kst(12, 3)                                                    # 03:00
        sleep, wake, _ = F.night(self.mhr, self.mst, self.thr, self.day(12), until=t)
        self.assertEqual(sleep, 3 * 60 - bed_minute(12))
        self.assertEqual(wake, F.local_minute(t) - 1)                     # 02:59
        later = self.hr_ts > t
        hr_v = np.where(later, 250.0, self.hr_v)                          # extreme future
        mhr = F.minute_hr(self.hr_ts, hr_v)
        self.assertEqual(F.night(mhr, self.mst, self.thr, self.day(12), until=t)[:2], (sleep, wake))

    def test_coverage_counts_15_min_slots_of_the_elapsed_window(self):
        keep = (self.hr_ts >= kst(11, 23)) & (self.hr_ts < kst(12, 7))   # worn 23:00-07:00
        mhr = F.minute_hr(self.hr_ts[keep], self.hr_v[keep])
        full = F.night(mhr, self.mst, self.thr, self.day(12))
        self.assertAlmostEqual(full[2], 32 / 60)                          # 21:00-12:00
        self.assertTrue(np.isnan(full[0]))                                # < 60 %: unknown
        at7 = F.night(mhr, self.mst, self.thr, self.day(12), until=kst(12, 7))
        self.assertAlmostEqual(at7[2], 32 / 40)                           # 21:00-07:00
        self.assertFalse(np.isnan(at7[0]))
        at705 = F.night(mhr, self.mst, self.thr, self.day(12), until=kst(12, 7, 5))
        self.assertAlmostEqual(at705[2], 32 / 41)                         # started slot counts

    def test_unknown_without_a_2_hour_block(self):
        t = kst(12, 0, 30)                                                # 90 min of sleep at most
        sleep, wake, coverage = F.night(self.mhr, self.mst, self.thr, self.day(12), until=t)
        self.assertEqual(coverage, 1.0)
        self.assertTrue(np.isnan(sleep) and np.isnan(wake))

    def test_v0_rules_give_the_v0_nights(self):
        from ml.explore_d1 import night_sleep
        keep = ~((self.hr_ts >= kst(8, 1)) & (self.hr_ts < kst(8, 8)))   # one night not worn
        hr = pd.DataFrame({"timestamp": self.hr_ts[keep], "value": self.hr_v[keep]})
        st = pd.DataFrame({"timestamp": self.st_ts, "value": self.st_v})
        days = [BASE_DAY + pd.Timedelta(days=d) for d in range(3, 12)]
        v0 = night_sleep("P000", days, hr, st)
        mhr = F.minute_hr(hr.timestamp.values, hr.value.values)
        thr = F.sleep_threshold(hr.timestamp.values, hr.value.values)
        for d, r in zip(range(3, 12), v0):
            sleep, wake, coverage = F.night(mhr, self.mst, thr, self.day(d), slot_min=1)
            self.assertEqual(coverage, r["night_worn"])
            if "sleep_min" in r:
                self.assertEqual((sleep, wake), (r["sleep_min"], r["wake_min"]))
            else:
                self.assertTrue(np.isnan(sleep))
        self.assertNotIn("sleep_min", v0[5])                              # day 8 is unknown

    def test_sleep_features(self):
        answers = np.array([kst(20, 14), kst(20, 3), kst(2, 14)])
        f = F.participant_features(answers, self.hr_ts, self.hr_v, self.st_ts, self.st_v, self.thr)
        known = [7 * 60 - bed_minute(d) for d in range(6, 20)]           # 14 previous nights
        mean, std = np.mean(known), np.std(known, ddof=1)
        self.assertAlmostEqual(f["z_sleep_min"][0], (7 * 60 - bed_minute(20) - mean) / std)
        self.assertAlmostEqual(f["hours_since_wake"][0], (14 * 60 - (7 * 60 - 1)) / 60)
        self.assertAlmostEqual(f["z_sleep_min"][1], (3 * 60 - bed_minute(20) - mean) / std)
        self.assertAlmostEqual(f["hours_since_wake"][1], 1 / 60)
        self.assertTrue(np.isnan(f["z_sleep_min"][2]))                  # 2 previous nights < 5
        np.testing.assert_array_equal(f["sleep_unknown"], [0, 0, 0])

    def test_no_future_data_changes_any_feature(self):    # 2.2
        answers = np.array([kst(d, h) for d in range(8, 15) for h in (2, 9, 14, 22)])
        before = F.participant_features(answers, self.hr_ts, self.hr_v, self.st_ts, self.st_v, self.thr)
        self.assertEqual(set(before), set(F.FEATURES))
        cut = answers[-1]
        hr_v = np.where(self.hr_ts > cut, 250.0, self.hr_v)            # extreme future values
        st_v = np.where(self.st_ts > cut, 1e5, self.st_v)
        extra_ts = np.arange(cut + 1, cut + 3 * F.DAY_MS, 7_000)        # and extra readings
        after = F.participant_features(answers, np.r_[self.hr_ts, extra_ts],
                                       np.r_[hr_v, np.full(len(extra_ts), 30.0)],
                                       self.st_ts, st_v, self.thr)
        for name in F.FEATURES:
            np.testing.assert_array_equal(before[name], after[name], err_msg=name)
        self.assertFalse(np.isnan(before["z_hr_30"][-1]))

    @staticmethod
    def day(d):
        return F.local_minute(kst(d, 0)) // 1440


class LabelTests(unittest.TestCase):    # 2.6
    def test_d3_stress_back_to_minus_3_plus_3(self):
        np.testing.assert_array_equal(F.rescale_d3(np.array([0, 3, 6, np.nan])), [-3, 0, 3, np.nan])

    def test_label_above_the_participant_mean(self):
        values = np.array([-3.0, 0.0, 3.0, 1.0, 1.0, 2.0, np.nan])
        who = np.array(["D3_P001"] * 3 + ["D3_P002"] * 4)
        np.testing.assert_array_equal(F.label_high(values, who), [0, 0, 1, 0, 0, 1, 0])


if __name__ == "__main__":
    unittest.main()
