"""Candidate NEW features for Harmony's state model, computed on EmoPhone D-1 + D-2 only.

Writes one derived per-response table per wave into out/ (participant, t, valence, new features),
in exactly the row order of data/features/v1_Dx.csv, and prints aggregates only.

All new definitions work on whole local minutes (KST): a window of w minutes at an answer whose
local minute is a covers the minutes [a - w, a - 1] (strictly before the answer minute: past only).
Heart rate = the v1 resampled series (first reading of each 5-min clock slot). Watch "worn" in a
5-min slot = a resampled HR reading or a Fitbit step row in that slot (v1 rule). Unknown = NaN.

Usage: python extract.py [--waves D1 D2] [--jobs 6]
"""
import argparse
import os
import sys
import tarfile
import time
from multiprocessing import Pool
from pathlib import Path

import numpy as np
import pandas as pd

sys.dont_write_bytecode = True
sys.path.insert(0, "/Users/clement/Hanyang/Harmony/ml")
from features import local_minute, minute_hr, minute_steps, night, resample_hr, sleep_threshold  # noqa: E402

DATA = Path("/Users/clement/Hanyang/Harmony/data/emophone_data")
V1 = Path("/Users/clement/Hanyang/Harmony/data/features")
OUT = Path("/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out")
DAY = 1440
REF_DAYS, READY = 14, 7
GRID_OFF = np.arange(8 * 60, 24 * 60, 30)          # v1 grid 08:00 ... 23:30
WANT = {"Fitbit-HeartRate.csv", "Fitbit-StepCount.csv", "Fitbit-Calorie.csv",
        "ActivityEvent.csv", "ActivityTransition.csv"}
ACT_COLS = ["confidenceStill", "confidenceUnknown", "confidenceInVehicle", "confidenceOnBicycle",
            "confidenceOnFoot", "confidenceWalking", "confidenceRunning", "confidenceTilting"]
ACT_CODE = np.array([0, 4, 2, 3, 1, 1, 1, 4])        # still, other, vehicle, bicycle, foot x3, other
TR_CODE = {"STILL": 0, "WALKING": 1, "RUNNING": 1, "ON_FOOT": 1, "IN_VEHICLE": 2, "ON_BICYCLE": 3}
ACT_CARRY = 30                                      # an activity event holds for <= 30 min
TR_CARRY = 12 * 60                                  # a transition state holds for <= 12 h
BOUT_SPM = 60                                       # walking minute = >= 60 steps in the minute
BOUT_LOOK = 720                                     # look back <= 12 h for the last walking minute


def read_archive(path):
    tabs = {}
    with tarfile.open(path, "r:gz") as tf:
        for m in tf:
            n = os.path.basename(m.name)
            if n in WANT and m.isfile():
                try:
                    tabs[n] = pd.read_csv(tf.extractfile(m))
                except pd.errors.EmptyDataError:
                    tabs[n] = None
    return tabs


def psum(x):
    return np.r_[0.0, np.cumsum(np.asarray(x, dtype=float))]


def wsum(P, lo, hi):
    """Sum over [lo, hi) of the series whose prefix sum is P (indices clipped)."""
    n = len(P) - 1
    lo, hi = np.clip(lo, 0, n), np.clip(hi, 0, n)
    return P[hi] - P[np.minimum(lo, hi)]


def zmat(x, base, min_known):
    """z of x against the rows of base (n, k): mean / sd(ddof=1) of the known baseline values."""
    known = ~np.isnan(base)
    cnt = known.sum(1)
    with np.errstate(invalid="ignore", divide="ignore"):
        mu = np.nanmean(np.where(known, base, np.nan), 1)
        sd = np.nanstd(np.where(known, base, np.nan), 1, ddof=1)
        z = (x - mu) / sd
    return np.where((cnt >= min_known) & (sd > 0), z, np.nan)


def zgrid(qa, qg, gm, gday, am):
    """v1 grid reference: grid points in [a - 14 d, a), >= 7 distinct days, z = (qa - mu) / sd."""
    out = np.full(len(am), np.nan)
    for i, a in enumerate(am):
        if np.isnan(qa[i]):
            continue
        lo = np.searchsorted(gm, a - REF_DAYS * DAY, "left")
        hi = np.searchsorted(gm, a, "left")
        v = qg[lo:hi]
        k = ~np.isnan(v)
        if k.sum() < 2 or len(np.unique(gday[lo:hi][k])) < READY:
            continue
        sd = v[k].std(ddof=1)
        if sd > 0:
            out[i] = (qa[i] - v[k].mean()) / sd
    return out


class Dense:
    """Per-minute arrays of one participant over [m0, m1) local minutes."""

    def __init__(self, tabs, answer_t):
        am = local_minute(answer_t)
        self.m0 = (am.min() // DAY - REF_DAYS - 3) * DAY
        self.m1 = am.max() + 1
        N = self.N = self.m1 - self.m0
        hr = tabs.get("Fitbit-HeartRate.csv")
        st = tabs.get("Fitbit-StepCount.csv")
        self.hr_raw = hr if hr is not None and len(hr) else None
        self.st_raw = st if st is not None and len(st) else None
        self.hr = np.full(N, np.nan)
        if self.hr_raw is not None:
            ts, v = resample_hr(self.hr_raw.timestamp.values, self.hr_raw.value.values)
            i = local_minute(ts) - self.m0
            k = (i >= 0) & (i < N)
            self.hr[i[k]] = v[k]
        self.st = np.zeros(N)
        strow = np.zeros(N, dtype=bool)
        if self.st_raw is not None:
            i = local_minute(self.st_raw.timestamp.values) - self.m0
            k = (i >= 0) & (i < N)
            np.add.at(self.st, i[k], self.st_raw.value.values[k].astype(float))
            strow[i[k]] = True
        slot_worn = np.zeros(N // 5 + 1, dtype=bool)
        idx = np.arange(N)
        slot_worn[idx[~np.isnan(self.hr) | strow] // 5] = True
        self.worn = slot_worn[idx // 5]                  # minute belongs to a worn 5-min slot
        self.has_hr = ~np.isnan(self.hr)
        self.anyrow = self.has_hr | strow                 # v1 "known" rule for a window
        # Fitbit-Calorie: METs (x10 in the file) and level 0-3, only on worn minutes
        self.mets = np.full(N, np.nan)
        self.lvl = np.full(N, np.nan)
        cal = tabs.get("Fitbit-Calorie.csv")
        if cal is not None and len(cal):
            i = local_minute(cal.timestamp.values) - self.m0
            k = (i >= 0) & (i < N)
            self.mets[i[k]] = cal.mets.values[k] / 10.0
            self.lvl[i[k]] = cal.level.values[k]
            self.mets[~self.worn] = np.nan
            self.lvl[~self.worn] = np.nan
        # ActivityEvent: argmax state of the last event at or before the minute, held <= 30 min
        self.act = np.full(N, np.nan)
        ae = tabs.get("ActivityEvent.csv")
        if ae is not None and len(ae):
            ae = ae.sort_values("timestamp", kind="stable")
            i = local_minute(ae.timestamp.values) - self.m0
            code = ACT_CODE[np.argmax(ae[ACT_COLS].to_numpy(dtype=float), 1)]
            self.act = self._carry(i, code, ACT_CARRY)
        # ActivityTransition: state entered, held <= 12 h
        self.tr = np.full(N, np.nan)
        at = tabs.get("ActivityTransition.csv")
        if at is not None and len(at):
            at = at.sort_values("timestamp", kind="stable")
            i = local_minute(at.timestamp.values) - self.m0
            code = at.typeEnter.map(TR_CODE).to_numpy(dtype=float)
            self.tr = self._carry(i, code, TR_CARRY)

    def _carry(self, i, code, hold):
        N = self.N
        k = (i < N)
        i, code = i[k], code[k]
        last = np.full(N, -1)
        val = np.full(N, np.nan)
        pos = np.clip(i, 0, N - 1)
        inside = i >= 0
        # last event index per minute (events before m0 seed minute 0 only if within hold)
        order = np.arange(len(i))
        lastev = np.full(N, -1)
        np.maximum.at(lastev, pos[inside], order[inside])   # last event of each minute
        if (~inside).any():
            j = np.where(~inside)[0][-1]
            if lastev[0] < 0 and -i[j] <= hold:
                lastev[0] = j
        lastev = np.maximum.accumulate(lastev)
        ok = lastev >= 0
        age = np.arange(N) - np.where(ok, i[np.maximum(lastev, 0)], 0)
        ok &= age <= hold
        val[ok] = code[lastev[ok]]
        return val


def participant(args):
    wave, pid, answer_t = args
    pcode = pid.split("_")[1]
    tabs = read_archive(DATA / wave / "Sensor" / f"{wave}_Sensor_{pcode}.tar.gz")
    answer_t = np.asarray(answer_t, dtype=np.int64)
    D = Dense(tabs, answer_t)
    am = local_minute(answer_t) - D.m0               # answer minute index
    n = len(am)
    f = {}
    P_st, P_hr, P_nhr = psum(D.st), psum(np.nan_to_num(D.hr)), psum(D.has_hr)
    P_any, P_worn = psum(D.anyrow), psum(D.worn)

    def hr_mean(lo, hi):
        c = wsum(P_nhr, lo, hi)
        with np.errstate(invalid="ignore", divide="ignore"):
            return np.where(c > 0, wsum(P_hr, lo, hi) / c, np.nan)

    def log_steps(lo, hi):
        return np.where(wsum(P_any, lo, hi) > 0, np.log1p(wsum(P_st, lo, hi)), np.nan)

    def cover(lo, hi):
        with np.errstate(invalid="ignore", divide="ignore"):
            return np.where(hi > lo, wsum(P_worn, lo, hi) / np.maximum(hi - lo, 1), 0.0)

    # sedentary readings: no step in the reading minute and the 10 minutes before
    idx = np.arange(D.N)
    st10 = wsum(P_st, idx - 10, idx + 1)
    sed = D.has_hr & (st10 == 0)
    P_sed, P_sedhr = psum(sed), psum(np.where(sed, D.hr, 0.0))

    def sed_mean(lo, hi):
        c = wsum(P_sed, lo, hi)
        with np.errstate(invalid="ignore", divide="ignore"):
            return np.where(c > 0, wsum(P_sedhr, lo, hi) / c, np.nan)

    # METs / level on worn minutes
    hasm = ~np.isnan(D.mets)
    P_m, P_nm = psum(np.nan_to_num(D.mets)), psum(hasm)
    P_l1 = psum(np.nan_to_num(D.lvl) >= 1)

    def mets_mean(lo, hi):
        c = wsum(P_nm, lo, hi)
        with np.errstate(invalid="ignore", divide="ignore"):
            return np.where(c > 0, wsum(P_m, lo, hi) / c, np.nan)

    def lvl_share(lo, hi):
        c = wsum(P_nm, lo, hi)
        with np.errstate(invalid="ignore", divide="ignore"):
            return np.where(c > 0, wsum(P_l1, lo, hi) / c, np.nan)

    # grid (v1 reference points) in minute indices
    days = np.arange(D.m0 // DAY, (D.m0 + D.N) // DAY + 1)
    gm = (days[:, None] * DAY + GRID_OFF[None, :]).ravel() - D.m0
    gm = gm[(gm > 0) & (gm < D.N)]
    gday = (gm + D.m0) // DAY

    # ---- sanity: v1 quantities re-derived on whole minutes (to compare with the v1 table)
    for w in (30,):
        f[f"chk_z_hr_{w}"] = zgrid(hr_mean(am - w, am), hr_mean(gm - w, gm), gm, gday, am)
        f[f"chk_z_log_steps_{w}"] = zgrid(log_steps(am - w, am), log_steps(gm - w, gm), gm, gday, am)

    # ---- A. longer windows, v1 grid rule
    for w in (120, 240):
        f[f"z_hr_{w}"] = zgrid(hr_mean(am - w, am), hr_mean(gm - w, gm), gm, gday, am)
        f[f"z_log_steps_{w}"] = zgrid(log_steps(am - w, am), log_steps(gm - w, gm), gm, gday, am)

    # ---- E1. sedentary HR, v1 grid rule
    for w in (30, 60, 120):
        f[f"z_sedhr_{w}"] = zgrid(sed_mean(am - w, am), sed_mean(gm - w, gm), gm, gday, am)

    # ---- G. intensity (Fitbit-Calorie), v1 grid rule + raw share of active minutes
    for w in (15, 30, 60):
        f[f"z_mets_{w}"] = zgrid(mets_mean(am - w, am), mets_mean(gm - w, gm), gm, gday, am)
    # raw (not z-scored) window values: known whenever the watch is worn, no 7-day reference needed
    for w in (30, 60):
        f[f"raw_log_steps_{w}"] = log_steps(am - w, am)
        f[f"raw_hr_{w}"] = hr_mean(am - w, am)
        f[f"raw_mets_{w}"] = mets_mean(am - w, am)
    for w in (30, 60):
        f[f"lvl1_share_{w}"] = lvl_share(am - w, am)
        f[f"z_lvl1_share_{w}"] = zgrid(lvl_share(am - w, am), lvl_share(gm - w, gm), gm, gday, am)

    # ---- B. day so far since the last 06:00, baseline = same clock time on the 14 previous days
    def since6(a):
        anchor = a - ((a + D.m0 - 360) % DAY)
        cov = cover(anchor, a)
        ok = cov >= 0.5
        return (np.where(ok, np.log1p(wsum(P_st, anchor, a)), np.nan),
                np.where(ok, hr_mean(anchor, a), np.nan),
                np.where(ok, sed_mean(anchor, a), np.nan))

    cur = since6(am)
    base = [since6(am - k * DAY) for k in range(1, REF_DAYS + 1)]
    for j, name in enumerate(("z_steps_since6", "z_hr_since6", "z_sedhr_since6")):
        f[name] = zmat(cur[j], np.stack([b[j] for b in base], 1), READY)
    f["cov_since6"] = cover(am - ((am + D.m0 - 360) % DAY), am)

    # ---- C. since wake (v1 sleep estimate, as hours_since_wake)
    f["chk_hours_since_wake"] = np.full(n, np.nan)
    for name in ("z_steps_since_wake", "z_hr_since_wake", "z_hr_wake60", "z_steps_wake120"):
        f[name] = np.full(n, np.nan)
    if D.hr_raw is not None:
        hts, hv = D.hr_raw.timestamp.values, D.hr_raw.value.values
        sts = D.st_raw.timestamp.values if D.st_raw is not None else np.array([], dtype=np.int64)
        sv = D.st_raw.value.values if D.st_raw is not None else np.array([])
        mhr, mst = minute_hr(hts, hv), minute_steps(sts, sv)
        thr = sleep_threshold(hts, hv)
        amin = am + D.m0
        dayv = amin // DAY
        pdays = np.arange(dayv.min() - REF_DAYS, dayv.max() + 1)
        wake_full = np.array([night(mhr, mst, thr, d)[1] for d in pdays], dtype=float) - D.m0
        for i in range(n):
            if amin[i] % DAY < 12 * 60:
                wk = night(mhr, mst, thr, dayv[i], until=answer_t[i])[1]
                wk = wk - D.m0 if not np.isnan(wk) else np.nan
            else:
                wk = wake_full[dayv[i] - pdays[0]]
            if np.isnan(wk) or am[i] < wk:
                continue
            wk = int(wk)
            f["chk_hours_since_wake"][i] = (am[i] - wk) / 60
            prev = (pdays >= dayv[i] - REF_DAYS) & (pdays < dayv[i])
            wprev = wake_full[prev]
            wprev = wprev[~np.isnan(wprev)].astype(int)
            e = am[i] - wk - 1                                    # whole minutes awake before a
            for name, L, kind in (("z_steps_since_wake", e, "st"), ("z_hr_since_wake", e, "hr"),
                                  ("z_hr_wake60", min(60, e), "hr"),
                                  ("z_steps_wake120", min(120, e), "st")):
                if L < 5:
                    continue
                lo, hi = np.r_[wk + 1, wprev + 1], np.r_[wk + 1 + L, wprev + 1 + L]
                ok = cover(lo, hi) >= 0.5
                q = log_steps(lo, hi) if kind == "st" else hr_mean(lo, hi)
                q = np.where(ok, q, np.nan)
                f[name][i] = zmat(q[:1], q[None, 1:], 5)[0]

    # ---- D. yesterday and previous evening; baseline = the 14 days before yesterday
    dlist = np.arange(D.m0 // DAY, (D.m0 + D.N) // DAY + 1)
    dstart = dlist * DAY - D.m0

    def day_q(off0, off1, kind, need, cov=None):
        lo, hi = dstart + off0, dstart + off1
        clo, chi = (lo, hi) if cov is None else (dstart + cov[0], dstart + cov[1])
        ok = (cover(clo, chi) >= need) & (lo >= 0) & (hi <= D.N)
        q = {"st": lambda: np.log1p(wsum(P_st, lo, hi)), "hr": lambda: hr_mean(lo, hi),
             "sed": lambda: sed_mean(lo, hi)}[kind]()
        return np.where(ok, q, np.nan)

    dq = {"z_steps_yday": day_q(0, DAY, "st", 0.6, (480, 1320)), "z_hr_yday": day_q(480, 1320, "hr", 0.5),
          "z_sedhr_yday": day_q(480, 1320, "sed", 0.5),
          "z_hr_prev_evening": day_q(1080, 1440, "hr", 0.5),
          "z_steps_prev_evening": day_q(1080, 1440, "st", 0.5)}
    di = (am + D.m0) // DAY - dlist[0]                   # index of the answer day
    for name, q in dq.items():
        x = q[di - 1]
        basem = np.stack([q[di - k] for k in range(2, REF_DAYS + 2)], 1)
        f[name] = zmat(x, basem, READY)

    # ---- F. minutes since the last walking minute (>= 60 steps), <= 12 h back
    bout = D.st >= BOUT_SPM
    lastb = np.maximum.accumulate(np.where(bout, idx, -1))
    j = lastb[np.maximum(am - 1, 0)]
    gap = np.where(j >= 0, am - j, BOUT_LOOK + 1)
    lo = np.where(gap <= BOUT_LOOK, j, am - BOUT_LOOK)
    ok = cover(lo, am) >= 0.5
    f["log_min_since_walk"] = np.where(ok, np.log1p(np.minimum(gap, BOUT_LOOK)), np.nan)

    # ---- E2. HR residual after recent steps (per person, readings of the 14 previous days)
    ri = np.where(D.has_hr)[0]
    for name in ("zres_hr_30", "zres_hr_60"):
        f[name] = np.full(n, np.nan)
    if len(ri) > 50:
        y = D.hr[ri]
        x1 = np.log1p(wsum(P_st, ri - 10, ri + 1))
        x2 = np.log1p(wsum(P_st, ri - 60, ri + 1))
        X = np.c_[np.ones(len(ri)), x1, x2]
        XX = np.einsum("ni,nj->nij", X, X).reshape(len(ri), 9)
        PXX = np.vstack([np.zeros(9), np.cumsum(XX, 0)])
        PXy = np.vstack([np.zeros(3), np.cumsum(X * y[:, None], 0)])
        Pyy = psum(y * y)
        rday = (ri + D.m0) // DAY
        Pdchg = np.r_[0, np.cumsum(np.r_[1, np.diff(rday) != 0])]
        for i, a in enumerate(am):
            lo = np.searchsorted(ri, a - REF_DAYS * DAY, "left")
            hi = np.searchsorted(ri, a, "left")
            if hi - lo < 100 or Pdchg[hi] - Pdchg[lo + 1] + 1 < READY:
                continue
            XtX = (PXX[hi] - PXX[lo]).reshape(3, 3)
            Xty = PXy[hi] - PXy[lo]
            beta = np.linalg.solve(XtX + 1e-6 * np.eye(3), Xty)
            rss = (Pyy[hi] - Pyy[lo]) - 2 * beta @ Xty + beta @ XtX @ beta
            sd = np.sqrt(max(rss, 0) / (hi - lo - 3))
            for w, name in ((30, "zres_hr_30"), (60, "zres_hr_60")):
                wl = np.searchsorted(ri, a - w, "left")
                if hi > wl and sd > 0:
                    mres = ((PXy[hi, 0] - PXy[wl, 0]) - beta @ (PXX[hi, :3] - PXX[wl, :3])) / (hi - wl)
                    f[name][i] = mres / sd

    # ---- H. activity type from the phone (ActivityEvent, ActivityTransition)
    for src, arr in (("act", D.act), ("tr", D.tr)):
        known = ~np.isnan(arr)
        Pk = psum(known)
        for w in (30, 60):
            kn = wsum(Pk, am - w, am)
            ok = kn >= w / 2
            for code, lab in ((0, "still"), (1, "foot"), (2, "vehicle")):
                Pc = psum(known & (arr == code))
                with np.errstate(invalid="ignore", divide="ignore"):
                    f[f"{src}_{lab}_{w}"] = np.where(ok, wsum(Pc, am - w, am) / kn, np.nan)
            f[f"{src}_known_{w}"] = kn / w
    return pd.DataFrame(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--waves", nargs="+", default=["D1", "D2"])
    ap.add_argument("--jobs", type=int, default=6)
    args = ap.parse_args()
    for wave in args.waves:
        assert wave in ("D1", "D2"), "D-3 is reserved"
        t0 = time.time()
        v1 = pd.read_csv(V1 / f"v1_{wave}.csv", usecols=["participant", "t", "arousal", "stress"])
        # valence: same reading and sorting as ml/build_features.py
        esm = pd.read_csv(DATA / wave / "EsmResponse.csv",
                          usecols=["pcode", "actualTriggerTime", "arousal", "stress", "valence"])
        parts = list(dict.fromkeys(v1.participant))
        val = []
        for pid in parts:
            e = esm[esm.pcode == pid.split("_")[1]].sort_values("actualTriggerTime")
            val.append(e)
        val = pd.concat(val, ignore_index=True)
        assert (val.actualTriggerTime.values == v1.t.values).all()
        assert (val.arousal.values == v1.arousal.values).all()
        assert (val.stress.values == v1.stress.values).all()
        jobs = [(wave, pid, v1.t[v1.participant == pid].to_numpy()) for pid in parts]
        with Pool(args.jobs) as pool:
            res = pool.map(participant, jobs, chunksize=1)
        new = pd.concat(res, ignore_index=True)
        table = pd.concat([v1[["participant", "t"]], val[["valence"]], new], axis=1)
        assert len(table) == len(v1)
        table.to_csv(OUT / f"new_{wave}.csv", index=False)
        print(f"{wave}: {len(table)} rows, {len(parts)} participants, {time.time() - t0:.0f} s")
        miss = table.drop(columns=["participant", "t", "valence"]).isna().mean().round(3)
        print("  share unknown:", miss.to_dict())


if __name__ == "__main__":
    main()
