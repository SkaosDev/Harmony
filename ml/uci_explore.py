"""Aggregate-only exploration of the UC Irvine dataset (TODO 5.2)."""
import hashlib
from itertools import combinations
from pathlib import Path
import pandas as pd
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / "data/uci/ifh_affect"
PEOPLE = sorted(ROOT.glob("par_*"), key=lambda p: int(p.name[4:]))
ITEMS = ["Active", "Alert", "Excited", "Enthusiastic", "Jittery", "Nervous"]
DUPLICATE_FILES = ("ema/daily.csv", "oura/sleep.csv", "oura/heart_rate.csv", "samsung/pedometer.csv")

def duplicate_ids():
    """Counts only: participant IDs with identical files or shared EMA instants (TODO 5.9)."""
    for rel in DUPLICATE_FILES:
        digest = {p.name: hashlib.md5((p / rel).read_bytes()).hexdigest()
                  for p in PEOPLE if (p / rel).exists()}
        same = sum(digest[a] == digest[b] for a, b in combinations(digest, 2))
        print(rel, "files", len(digest), "identical ID pairs", same)
    instants = {p.name: set(pd.read_csv(p / "ema/daily.csv", usecols=["submission_timestamp"])
                            .submission_timestamp.dropna().astype("int64"))
                for p in PEOPLE if (p / "ema/daily.csv").exists()}
    shared = sum(bool(instants[a] & instants[b]) for a, b in combinations(instants, 2))
    print("ID pairs sharing an EMA submission instant", shared)

def main():
    counts = {k: [] for k in ("ema", "hr", "steps", "sleep")}
    dates, hours, intervals, invalid = [], [], [], []
    hr_hour_sum = np.zeros(24); hr_hour_count = np.zeros(24)
    oura_periods = candidate_nights = matched_nights = 0
    cover = {k: {"day": [], "night": []} for k in ("ppg", "hrv", "oura")}
    for i, p in enumerate(PEOPLE, 1):
        print(f"Reading participant {i}/{len(PEOPLE)}", flush=True)
        sampled = {}
        ema_path = p / "ema/daily.csv"
        ema_days=set()
        if ema_path.exists():
            e = pd.read_csv(ema_path, usecols=lambda c: c in {"submission_timestamp", "start_timestamp", *ITEMS})
            counts["ema"].append(len(e))
            if len(e):
                t = pd.to_numeric(e.submission_timestamp, errors="coerce").dropna()
                if len(t):
                    dates.extend(t.tolist())
                    local = pd.to_datetime(t, unit="ms", utc=True).dt.tz_convert("America/Los_Angeles")
                    hours.extend(local.dt.hour.tolist())
                    ema_days=set(local.dt.date.tolist())
        else: counts["ema"].append(0)
        for typ, path in (("steps", p/"samsung/pedometer.csv"), ("sleep", p/"oura/sleep.csv")):
            counts[typ].append(int(path.exists() and path.stat().st_size > 0))
        sleep_path=p/"oura/sleep.csv"
        if sleep_path.exists() and ema_days:
            s=pd.read_csv(sleep_path,usecols=["date"])
            wake_days=set((pd.to_datetime(s.date)+pd.Timedelta(days=1)).dt.date.tolist())
            oura_periods += len(s); candidate_nights += len(ema_days); matched_nights += len(ema_days & wake_days)
        # Stream the large PPG file; only timestamp and HR enter memory.
        pp = p/"samsung/ppg.csv"
        if pp.exists():
            valid_n = bad_n = total = 0; ts = []; sample_hr_t = []; sample_hr = []
            for c in pd.read_csv(pp, usecols=["timestamp", "hr"], chunksize=1_000_000):
                h = pd.to_numeric(c.hr, errors="coerce"); t = pd.to_numeric(c.timestamp, errors="coerce")
                total += len(c); valid_n += h.between(30,220).sum(); bad_n += (~h.between(30,220)).sum()
                stride=max(1,len(t)//2000); sampled_t=t.iloc[::stride]; sampled_h=h.iloc[::stride]
                ts.extend(sampled_t.dropna().astype("int64").tolist())
                ok=sampled_t.notna() & sampled_h.between(30,220)
                sample_hr_t.extend(sampled_t[ok].astype("int64").tolist())
                sample_hr.extend(sampled_h[ok].astype(float).tolist())
            counts["hr"].append(total > 0)
            dif = np.diff(np.sort(np.unique(ts))) / 1000
            intervals.extend(dif[dif > 0].tolist())
            invalid.append((bad_n, total))
            sampled["ppg"] = ts
            if sample_hr_t:
                local=pd.to_datetime(sample_hr_t,unit="ms",utc=True).tz_convert("America/Los_Angeles")
                hh=local.hour.to_numpy(); hr_hour_sum += np.bincount(hh,weights=sample_hr,minlength=24)
                hr_hour_count += np.bincount(hh,minlength=24)
        else: counts["hr"].append(0)
        for key, path, tc in (("ppg",pp,"timestamp"),("hrv",p/"samsung/hrv_1min.csv","timestamp"),("oura",p/"oura/heart_rate.csv","timestamp")):
            if path.exists():
                a=sampled.get(key,[])
                if key != "ppg":
                    a=[]
                    for c in pd.read_csv(path,usecols=[tc],chunksize=1_000_000): a.extend(pd.to_numeric(c[tc],errors="coerce").dropna().iloc[::100].tolist())
                if a:
                    dt=pd.to_datetime(a,unit="ms",utc=True).tz_convert("America/Los_Angeles")
                    hm=dt.hour+dt.minute/60
                    for band,mask in (("day",(hm>=8)),("night",(hm<6))): cover[key][band].append(len(set(dt[mask].date))/max(1,len(set(dt.date))))
    print("participants", len(PEOPLE), "EMA/HR/steps/Oura_sleep", *(sum(counts[k]) for k in counts))
    vals=[n for n in counts["ema"] if n]
    print("EMA responses total/median per participant",sum(vals),float(np.median(vals)) if vals else 0)
    if dates: print("EMA UTC range",pd.to_datetime(min(dates),unit="ms",utc=True),pd.to_datetime(max(dates),unit="ms",utc=True),"local submission hour histogram",np.bincount(hours,minlength=24).tolist())
    if intervals: print("PPG sampled interval seconds median",float(np.median(intervals)),"invalid HR share",sum(a for a,b in invalid)/max(1,sum(b for a,b in invalid)))
    print("PPG sampled mean HR by LA local hour",np.round(hr_hour_sum/np.maximum(hr_hour_count,1),1).tolist())
    print("Oura sleep periods",oura_periods,"EMA participant-nights with period",matched_nights,"of",candidate_nights,"share",matched_nights/max(1,candidate_nights))
    for source in cover:
        print(source,"day coverage mean",np.mean(cover[source]["day"]) if cover[source]["day"] else 0,"night coverage mean",np.mean(cover[source]["night"]) if cover[source]["night"] else 0)
    duplicate_ids()

if __name__ == "__main__": main()
