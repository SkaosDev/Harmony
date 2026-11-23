"""Aggregate-only inventory of UC Irvine ifh_affect: files per participant, headers, sizes,
EMA item stats (ICC, within-person correlations), Oura sleep/readiness availability."""
import sys, os, glob, collections, numpy as np, pandas as pd
BASE = sys.argv[1]
pars = sorted(glob.glob(os.path.join(BASE, 'par_*')), key=lambda p: int(p.split('_')[-1]))
files = collections.defaultdict(list); headers = {}
for p in pars:
    for f in glob.glob(os.path.join(p, '*', '*.csv')):
        rel = os.path.relpath(f, p); files[rel].append(os.path.getsize(f))
        if rel not in headers:
            with open(f, 'r', errors='replace') as fh: headers[rel] = fh.readline().strip()[:400]
print(f'participants dirs: {len(pars)}')
for rel in sorted(files):
    s = np.array(files[rel])
    print(f'{rel}: n_par={len(s)}, total {s.sum()/1e9:.2f} GB, median {np.median(s)/1e6:.1f} MB | cols: {headers[rel]}')
def icc1(d, col):
    d = d[['pid', col]].dropna(); n_i = d.groupby('pid').size(); n_i = n_i[n_i >= 2]; d = d[d.pid.isin(n_i.index)]
    g = d.groupby('pid')[col]; N = len(d); k = len(n_i); grand = d[col].mean()
    msb = (g.size() * (g.mean() - grand) ** 2).sum() / (k - 1); msw = ((d[col] - g.transform('mean')) ** 2).sum() / (N - k)
    k0 = (N - (n_i ** 2).sum() / N) / (k - 1); return (msb - msw) / (msb + (k0 - 1) * msw)
for kind in ['daily', 'weekly']:
    frames = []
    for p in pars:
        f = os.path.join(p, 'ema', f'{kind}.csv')
        if os.path.exists(f):
            d = pd.read_csv(f, low_memory=False); d['pid'] = os.path.basename(p); frames.append(d)
    ema = pd.concat(frames, ignore_index=True)
    PAN = ['Active','Afraid','Alert','Ashamed','Attentive','Determined','Distressed','Enthusiastic','Excited','Guilty','Hostile','Inspired','Interested','Irritable','Jittery','Nervous','Proud','Scared','Strong','Upset']
    extra = [c for c in ['Covid_worried','health_worried','week_felt'] if c in ema]
    for c in PAN + extra: ema[c] = pd.to_numeric(ema[c], errors='coerce')
    print(f'===== ema/{kind}: {len(ema)} rows, {ema.pid.nunique()} participants; per-participant median {ema.groupby("pid").size().median():.0f}')
    for c in PAN + extra:
        s = ema[c].dropna()
        if len(s): print(f'  {c}: n={len(s)}, {s.min():g}..{s.max():g}, mean {s.mean():.1f}, sd {s.std():.1f}, ICC1 {icc1(ema,c):.3f}')
    PA = ['Active','Alert','Attentive','Determined','Enthusiastic','Excited','Inspired','Interested','Proud','Strong']
    NA = ['Afraid','Ashamed','Distressed','Guilty','Hostile','Irritable','Jittery','Nervous','Scared','Upset']
    ACT = ['Active','Alert','Excited','Enthusiastic','Jittery','Nervous']
    ema['PA'] = ema[PA].mean(axis=1, skipna=False); ema['NA'] = ema[NA].mean(axis=1, skipna=False); ema['ACT'] = ema[ACT].mean(axis=1, skipna=False)
    ema['PAmNA'] = ema['PA'] - ema['NA']
    cols = ['ACT','PA','NA','PAmNA'] + extra
    for c in ['ACT','PA','NA','PAmNA']: print(f'  composite {c}: n={ema[c].notna().sum()}, ICC1 {icc1(ema,c):.3f}')
    d = ema[['pid'] + cols].dropna(subset=['ACT','PA','NA'])
    print('  pooled corr:'); print(d[cols].corr().round(2).to_string())
    c_ = d[cols] - d.groupby('pid')[cols].transform('mean')
    print('  within-person corr:'); print(c_.corr().round(2).to_string())
# Oura sleep/readiness availability
for name in ['oura/sleep.csv', 'oura/readiness.csv', 'oura/activity.csv']:
    n_rows = []; nonzero = collections.Counter(); tot = 0
    for p in pars:
        f = os.path.join(p, name)
        if os.path.exists(f):
            d = pd.read_csv(f, low_memory=False); n_rows.append(len(d)); tot += len(d)
            for c in d.columns:
                v = pd.to_numeric(d[c], errors='coerce'); nonzero[c] += int(((v.notna()) & (v != 0)).sum())
    if n_rows:
        print(f'===== {name}: {len(n_rows)} participants, {tot} rows, median {np.median(n_rows):.0f}/participant; share non-missing non-zero per column:')
        print('  ' + ', '.join(f'{c} {nonzero[c]/tot:.2f}' for c in nonzero))
