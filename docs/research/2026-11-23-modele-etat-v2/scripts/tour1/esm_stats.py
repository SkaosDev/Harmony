"""Aggregate ESM label statistics per EmoPhone wave: counts, observed ranges, ICC(1), pooled and
within-person correlations. No per-participant values printed."""
import sys, os, numpy as np, pandas as pd
BASE = sys.argv[1]
def icc1(df, col):
    d = df[['pcode', col]].dropna()
    g = d.groupby('pcode')[col]
    n_i = g.size(); n_i = n_i[n_i >= 2]
    d = d[d.pcode.isin(n_i.index)]; g = d.groupby('pcode')[col]
    N = len(d); k = len(n_i); grand = d[col].mean()
    ssb = (g.size() * (g.mean() - grand) ** 2).sum(); ssw = ((d[col] - g.transform('mean')) ** 2).sum()
    msb = ssb / (k - 1); msw = ssw / (N - k)
    k0 = (N - (n_i ** 2).sum() / N) / (k - 1)
    return (msb - msw) / (msb + (k0 - 1) * msw)
def within(df, cols):
    d = df[['pcode'] + cols].dropna()
    c = d[cols] - d.groupby('pcode')[cols].transform('mean')
    return c.corr()
for w in ['D1', 'D2', 'D3']:
    df = pd.read_csv(os.path.join(BASE, w, 'EsmResponse.csv'))
    print(f'===== {w}: {len(df)} responses, {df.pcode.nunique()} participants; columns: {list(df.columns)}')
    per = df.groupby('pcode').size()
    print(f'  responses/participant: median {per.median():.0f}, IQR {per.quantile(.25):.0f}-{per.quantile(.75):.0f}')
    skip = {'pcode','actualTriggerTime','intendedTriggerTime','responseTime','reactionTime'}
    items = [c for c in df.columns if c not in skip]
    for c in items: df[c] = pd.to_numeric(df[c], errors='coerce')
    if w == 'D3':
        for c in ['stress','disturbance','happy','relaxed','cheerful','content','sad','anxious','depressed','angry']:
            if c in df: df[c] = df[c] - 3  # 0..6 -> -3..3 (linear; corr/ICC unaffected)
    print('  item: n_nonnull, observed min..max (after D3 rescale), mean, sd, ICC(1) between-person share, distinct values')
    for c in items:
        s = df[c].dropna()
        if len(s) == 0: print(f'   {c}: empty'); continue
        print(f'   {c}: n={len(s)}, {s.min():g}..{s.max():g}, mean={s.mean():.2f}, sd={s.std():.2f}, ICC1={icc1(df,c):.3f}, k={s.nunique()}')
    core = [c for c in ['valence','arousal','stress','attention','disturbance','mental','duration','change','valenceChange','arousalChange'] if c in df]
    core = [c for c in core if df[c].notna().sum() > 100]
    pd.set_option('display.width', 250); pd.set_option('display.precision', 2)
    print('  pooled Pearson:'); print(df[core].corr().round(2).to_string())
    print('  within-person Pearson (person-mean centred):'); print(within(df, core).round(2).to_string())
    if w == 'D3':
        pan = ['happy','relaxed','cheerful','content','sad','anxious','depressed','angry']
        print('  D3 PANAS-type adjectives vs valence/arousal/stress, within-person:')
        print(within(df, ['valence','arousal','stress'] + pan).loc[pan, ['valence','arousal','stress']].round(2).to_string())
        print('  D3 pooled:'); print(df[['valence','arousal','stress'] + pan].corr().loc[pan, ['valence','arousal','stress']].round(2).to_string())
    # binary labels like the app: above own mean
    for c in ['valence','arousal','stress']:
        df[c+'_hi'] = (df[c] > df.groupby('pcode')[c].transform('mean')).astype(float).where(df[c].notna())
    b = df[['arousal_hi','valence_hi','stress_hi']].dropna()
    print(f'  binary above-own-mean: base rates arousal {b.arousal_hi.mean():.3f}, valence {b.valence_hi.mean():.3f}, stress {b.stress_hi.mean():.3f}')
    print(f'  phi(arousal_hi, valence_hi)={b.arousal_hi.corr(b.valence_hi):.3f}; phi(arousal_hi, stress_hi)={b.arousal_hi.corr(b.stress_hi):.3f}; phi(valence_hi, stress_hi)={b.valence_hi.corr(b.stress_hi):.3f}')
    q = pd.crosstab(b.arousal_hi, b.valence_hi, normalize=True).round(3)
    print('  quadrant shares (rows arousal_hi 0/1, cols valence_hi 0/1):', q.values.tolist())
    # fraction of responses at the person's modal value (low within-person variability)
    for c in ['valence','arousal','stress']:
        m = df.groupby('pcode')[c].transform(lambda s: s.mode().iloc[0] if s.notna().any() else np.nan)
        print(f'  {c}: share of responses equal to own modal value {(df[c]==m).mean():.3f}; participants with within-SD<0.5: {(df.groupby("pcode")[c].std()<0.5).mean():.3f}')
