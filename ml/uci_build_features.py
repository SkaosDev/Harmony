"""Build resumable UC Irvine v1 features; source data and outputs stay under data/."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from features import (FEATURES, KST_MS, label_high, local_minute, minute_hr,
                      minute_steps, night, participant_features, sleep_threshold)

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/uci/ifh_affect"
CACHE = ROOT / "data/uci_cache"
OUT = ROOT / "data/features/v1_UCI.csv"
ITEMS = ["Active", "Alert", "Excited", "Enthusiastic", "Jittery", "Nervous"]

def activation_score(frame):
    """Keep complete six-item daily responses and return their mean score."""
    clean = frame.dropna(subset=ITEMS).copy()
    return clean, clean[ITEMS].mean(axis=1)

def cumulative_steps(values):
    """Convert reboot-reset cumulative counts to per-reading increments."""
    v = np.asarray(values, dtype=float)
    if not len(v): return v
    d = np.diff(v, prepend=v[0]); d[0] = 0
    reset = d < 0
    d[reset] = v[reset]
    return d

def localize(ts):
    """Map UTC milliseconds to the KST-like coordinate expected by features.py, using LA DST."""
    utc = pd.to_datetime(np.asarray(ts, dtype=np.int64), unit="ms", utc=True)
    la = utc.tz_convert("America/Los_Angeles")
    offset = np.array([int(x.utcoffset().total_seconds()*1000) for x in la.to_pydatetime()], dtype=np.int64)
    return np.asarray(ts, dtype=np.int64) + offset - KST_MS

def read_hr(ppg, oura):
    parts=[]
    if ppg.exists():
        for c in pd.read_csv(ppg,usecols=["timestamp","hr"],chunksize=750_000):
            c["hr"]=pd.to_numeric(c.hr,errors="coerce")
            c=c[c.hr.between(30,220)]
            if len(c):
                c["minute"]=pd.to_numeric(c.timestamp,errors="coerce")//60000
                parts.append(c.groupby("minute").hr.agg(["sum","count"]).reset_index())
    if oura.exists():
        o=pd.read_csv(oura,usecols=["timestamp","heart_rate"])
        o=o.rename(columns={"heart_rate":"value"})
        o["value"]=pd.to_numeric(o.value,errors="coerce")
        o=o[o.value.between(30,220)]
        if len(o):
            o["minute"]=pd.to_numeric(o.timestamp,errors="coerce")//60000
            parts.append(o.groupby("minute").value.agg(["sum","count"]).reset_index())
    if not parts: return np.array([],dtype=np.int64),np.array([])
    h=pd.concat(parts,ignore_index=True).groupby("minute",as_index=False).sum()
    t=h.minute.to_numpy(dtype=np.int64)*60000
    return localize(t), (h["sum"]/h["count"]).to_numpy(dtype=float)

def read_steps(path):
    if not path.exists(): return np.array([],dtype=np.int64),np.array([])
    s=pd.read_csv(path,usecols=["timestamp","num_total_steps"])
    s=s.dropna().sort_values("timestamp").drop_duplicates("timestamp",keep="last")
    v=pd.to_numeric(s.num_total_steps,errors="coerce").to_numpy(dtype=float)
    # Negative deltas are device reboots: count the new cumulative value.
    d=cumulative_steps(v)
    t=pd.to_numeric(s.timestamp,errors="coerce").to_numpy(dtype=np.int64)
    minute=localize(t)//60000
    z=pd.DataFrame({"minute":minute,"steps":d}).groupby("minute",as_index=False).steps.sum()
    return z.minute.to_numpy(dtype=np.int64)*60000, z.steps.to_numpy(dtype=float)

def sleep_comparison(person, answer_t, hr_ts, hr_v, st_ts, st_v):
    path=person/"oura/sleep.csv"
    if not path.exists() or not len(answer_t): return []
    measured=pd.read_csv(path,usecols=["date","total"])
    measured["wake_day"]=(pd.to_datetime(measured.date)+pd.Timedelta(days=1)-pd.Timestamp("1970-01-01")).dt.days
    measured["minutes"]=pd.to_numeric(measured.total,errors="coerce")/60
    by_day=measured.groupby("wake_day").minutes.mean()
    mhr,mst=minute_hr(hr_ts,hr_v),minute_steps(st_ts,st_v)
    threshold=sleep_threshold(hr_ts,hr_v)
    days=np.unique(local_minute(answer_t)//1440)
    pairs=[]
    for day in days:
        if day in by_day.index:
            estimate=night(mhr,mst,threshold,int(day))[0]
            if np.isfinite(estimate): pairs.append((float(estimate),float(by_day.loc[day])))
    return pairs

def main():
    CACHE.mkdir(parents=True,exist_ok=True); tables=[]; compare=[]
    people=sorted(DATA.glob("par_*"),key=lambda p:int(p.name[4:]))
    for index,p in enumerate(people,1):
        name="UCI_"+p.name; cache=CACHE/f"{name}_py312_LA.csv"
        if cache.exists():
            tab=pd.read_csv(cache); tables.append(tab)
            sidecar=CACHE/f"{name}_py312_LA.sleep.json"
            if sidecar.exists(): compare.extend(json.loads(sidecar.read_text(encoding="utf-8")))
            else:
                e=pd.read_csv(p/"ema/daily.csv",usecols=["submission_timestamp"])
                t=pd.to_numeric(e.submission_timestamp,errors="coerce").dropna().to_numpy(dtype=np.int64)
                hts,hv=read_hr(p/"samsung/ppg.csv",p/"oura/heart_rate.csv")
                sts,sv=read_steps(p/"samsung/pedometer.csv")
                pairs=sleep_comparison(p,localize(t),hts,hv,sts,sv); compare.extend(pairs)
                sidecar.write_text(json.dumps(pairs),encoding="utf-8")
            print(f"participant {index}/{len(people)} cached",flush=True); continue
        epath=p/"ema/daily.csv"
        if not epath.exists(): continue
        e=pd.read_csv(epath,usecols=lambda c:c in {"submission_timestamp",*ITEMS})
        e,score=activation_score(e)
        if e.empty: continue
        e["activation"]=score; t=pd.to_numeric(e.submission_timestamp,errors="coerce")
        ok=t.notna(); e=e[ok]; t=t[ok].to_numpy(dtype=np.int64)
        feature_t=localize(t)
        hts,hv=read_hr(p/"samsung/ppg.csv",p/"oura/heart_rate.csv")
        sts,sv=read_steps(p/"samsung/pedometer.csv")
        pairs=sleep_comparison(p,feature_t,hts,hv,sts,sv); compare.extend(pairs)
        (CACHE/f"{name}_py312_LA.sleep.json").write_text(json.dumps(pairs),encoding="utf-8")
        feats=participant_features(feature_t,hts,hv,sts,sv,sleep_threshold(hts,hv))
        tab=pd.DataFrame({"participant":name,"t":t,"activation":e.activation.to_numpy(),**feats})
        tab["arousal_high"]=label_high(tab.activation,tab.participant)
        tab=tab[["participant","t","activation","arousal_high",*FEATURES]]
        tab.to_csv(cache,index=False); tables.append(tab)
        print(f"participant {index}/{len(people)} built",flush=True)
    result=pd.concat(tables,ignore_index=True) if tables else pd.DataFrame(columns=["participant","t","activation","arousal_high",*FEATURES])
    OUT.parent.mkdir(parents=True,exist_ok=True); result.to_csv(OUT,index=False)
    print("rows",len(result),"participants",result.participant.nunique(),"known-night share",float((result.sleep_unknown==0).mean()),"unknown shares",json.dumps({c:float(result[c].isna().mean()) for c in ("z_hr_30","zb_hr_30","z_log_steps_30","z_sleep_min","hours_since_wake")}),"output",OUT)
    if compare:
        a=np.asarray(compare); corr=np.corrcoef(a.T)[0,1] if len(a)>1 and np.std(a[:,0]) and np.std(a[:,1]) else float("nan")
        print("estimated vs Oura sleep",len(a),"nights; median signed gap minutes",float(np.median(a[:,0]-a[:,1])),"correlation",float(corr))

if __name__=="__main__": main()
