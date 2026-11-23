import pandas as pd, numpy as np
R="/Users/clement/Hanyang/Harmony/data"
for w in ("D1","D2"):
    e=pd.read_csv(f"{R}/emophone_data/{w}/EsmResponse.csv", nrows=0)
    print(w,"ESM columns:",list(e.columns))
    e=pd.read_csv(f"{R}/emophone_data/{w}/EsmResponse.csv", usecols=["pcode","actualTriggerTime","valence","arousal","stress"])
    print(" rows",len(e),"pcodes",e.pcode.nunique(),"dup (pcode,t)",e.duplicated(["pcode","actualTriggerTime"]).sum(),
          "valence range",e.valence.min(),e.valence.max(),"NaN val",e.valence.isna().sum())
    f=pd.read_csv(f"{R}/features/v1_{w}.csv")
    print(" feat rows",len(f),"participants",f.participant.nunique(),"cols",list(f.columns)[:6])
    print(" dup (participant,t)", f.duplicated(["participant","t"]).sum())
    # per-person answers/day aggregate
    g=f.groupby("participant").t.agg(["min","max","count"])
    days=(g["max"]-g["min"])/86400000
    print(" days span median %.1f (p10 %.1f p90 %.1f); answers/person median %d; answers/day median %.2f"%(days.median(),days.quantile(.1),days.quantile(.9),g["count"].median(),(g["count"]/days.clip(lower=1)).median()))
    print(" missing share per feature:", f.iloc[:,6:].isna().mean().round(2).to_dict())
