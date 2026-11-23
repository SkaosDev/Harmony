"""Aggregate within-person correlations between last Oura night (ended <=18 h before an EMA) and that
day's PANAS composites. Prints only pooled counts and correlations."""
import sys, os, glob, numpy as np, pandas as pd
BASE = sys.argv[1]
PA = ['Active','Alert','Attentive','Determined','Enthusiastic','Excited','Inspired','Interested','Proud','Strong']
NA = ['Afraid','Ashamed','Distressed','Guilty','Hostile','Irritable','Jittery','Nervous','Scared','Upset']
ACT = ['Active','Alert','Excited','Enthusiastic','Jittery','Nervous']
SV = ['total','efficiency','rmssd','hr_lowest','hr_average','deep','rem','onset_latency','restless','breath_average','temperature_delta','score']
rows = []
for p in sorted(glob.glob(os.path.join(BASE, 'par_*'))):
    e, s = os.path.join(p, 'ema', 'daily.csv'), os.path.join(p, 'oura', 'sleep.csv')
    if not (os.path.exists(e) and os.path.exists(s)): continue
    ema = pd.read_csv(e, low_memory=False); sl = pd.read_csv(s, low_memory=False)
    for c in PA + NA: ema[c] = pd.to_numeric(ema[c], errors='coerce')
    ema['ACT'] = ema[ACT].mean(axis=1, skipna=False); ema['PA'] = ema[PA].mean(axis=1, skipna=False); ema['NA'] = ema[NA].mean(axis=1, skipna=False)
    ema['t'] = pd.to_numeric(ema['submission_timestamp'], errors='coerce')
    sl['t_end'] = pd.to_numeric(sl['bedtime_end_timestamp'], errors='coerce')
    ema = ema.dropna(subset=['t']).sort_values('t'); sl = sl.dropna(subset=['t_end']).sort_values('t_end')
    for c in SV: sl[c] = pd.to_numeric(sl[c], errors='coerce')
    m = pd.merge_asof(ema[['t','ACT','PA','NA']], sl[['t_end'] + SV], left_on='t', right_on='t_end', direction='backward', tolerance=18*3600*1000)
    m['pid'] = os.path.basename(p); rows.append(m)
d = pd.concat(rows, ignore_index=True)
print(f'EMA rows {len(d)}, with Oura night ended <=18h before: {d["t_end"].notna().sum()} ({d["t_end"].notna().mean():.3f}), participants {d.dropna(subset=["t_end"]).pid.nunique()}')
d = d.dropna(subset=['t_end'])
cols = ['ACT','PA','NA'] + SV
c = d[cols] - d.groupby('pid')[cols].transform('mean')
w = c.corr().loc[SV, ['ACT','PA','NA']]
pooled = d[cols].corr().loc[SV, ['ACT','PA','NA']]
print('within-person r (person-mean centred) | pooled r'); print(pd.concat([w.add_prefix('w_'), pooled.add_prefix('p_')], axis=1).round(3).to_string())
print('approx |r| for p<0.05 with n=', len(d), ':', round(1.96/np.sqrt(len(d)), 3), '(ignores clustering)')
