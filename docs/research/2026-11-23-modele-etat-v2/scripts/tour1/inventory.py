"""Aggregate-only inventory of EmoPhone sensor archives (no raw rows printed).
For each wave and sensor file: number of archives containing it, median rows, median distinct KST days,
share of ESM responses (pooled) with >=1 record in the 60 min / 15 min before actualTriggerTime,
aggregated category label counts for low-cardinality non-identifying columns,
and Fitbit vs Fitness daily-step correlation (pooled participant-days)."""
import sys, tarfile, io, glob, os, re, json, collections
import numpy as np, pandas as pd
BASE = sys.argv[1]; OUT = sys.argv[2]
CATS = {
 'ActivityTransition.csv': ['typeEnter','typeExit'],
 'AppUsageEvent.csv': ['type','category','source'],
 'BatteryEvent.csv': ['status','pluggedType'],
 'CallEvent.csv': ['type','contactType','presentation'],
 'ChargeEvent.csv': ['type'], 'DozeModeEvent.csv': ['type'],
 'Fitbit-Calorie.csv': ['level'], 'Fitness-Activity.csv': ['value'],
 'KeyEvent.csv': ['keyboardType','prevKeyType','currKeyType','category'],
 'MessageEvent.csv': ['messageClass','messageBox','contactType'],
 'NotificationEvent.csv': ['visibility','category','isPosted'],
 'OnOffEvent.csv': ['type'], 'PowerSaveEvent.csv': ['type'], 'RingerModeEvent.csv': ['type'],
 'ScreenEvent.csv': ['type'], 'WirelessStateEvent.csv': ['type'],
 'BluetoothScan.csv': ['deviceType','bondState'], 'Proximity.csv': ['value'],
}
NUMMED = {'Fitbit-HeartRate.csv':'value','Light.csv':'value','Fitbit-StepCount.csv':'value',
          'Fitness-StepCount.csv':'value','Fitbit-Calorie.csv':'mets','Fitbit-Distance.csv':'value'}
KST = 9*3600*1000
res = {}
for w in ['D1','D2','D3']:
    esm = pd.read_csv(os.path.join(BASE, w, 'EsmResponse.csv'), usecols=['pcode','actualTriggerTime'])
    esm['p'] = esm['pcode'].astype(str).str.extract(r'(\d+)')[0].astype(int)
    esm_by = {p: np.sort(g['actualTriggerTime'].to_numpy(dtype='int64')) for p, g in esm.groupby('p')}
    stats = collections.defaultdict(lambda: {'n_arch':0,'rows':[],'days':[],'esm_n':0,'esm_hit60':0,'esm_hit15':0,
                                              'cats':collections.defaultdict(collections.Counter),'med':[], 'dur_med':[]})
    steps_pairs = []
    arcs = sorted(glob.glob(os.path.join(BASE, w, 'Sensor', '*.tar.gz')))
    for a in arcs:
        p = int(re.search(r'P(\d+)', os.path.basename(a)).group(1))
        trig = esm_by.get(p, np.array([], dtype='int64'))
        daily = {}
        try:
            tf = tarfile.open(a, 'r|gz')
        except Exception as e:
            print('ERR', a, e, file=sys.stderr); continue
        for m in tf:
            if not m.isfile(): continue
            name = os.path.basename(m.name)
            if name.startswith('.') or not name.endswith('.csv'): continue
            raw = tf.extractfile(m).read()
            st = stats[name]; st['n_arch'] += 1
            if len(raw.strip()) == 0:
                st['rows'].append(0); st['days'].append(0); st['esm_n'] += len(trig); continue
            try:
                hdr = pd.read_csv(io.BytesIO(raw), nrows=0).columns.tolist()
                use = ['timestamp'] + [c for c in CATS.get(name, []) if c in hdr]
                if name in NUMMED and NUMMED[name] in hdr and NUMMED[name] not in use: use.append(NUMMED[name])
                if name.startswith('Fitness-'): use += [c for c in ['fromTime','toTime'] if c in hdr and c not in use]
                if name == 'Fitbit-StepCount.csv' and 'value' not in use: use.append('value')
                df = pd.read_csv(io.BytesIO(raw), usecols=use, low_memory=False)
            except Exception as e:
                print('ERR', a, name, e, file=sys.stderr); continue
            ts = pd.to_numeric(df['timestamp'], errors='coerce').dropna().to_numpy(dtype='int64')
            st['rows'].append(len(df))
            st['days'].append(len(np.unique((ts + KST)//86400000)) if len(ts) else 0)
            ts = np.sort(ts)
            if len(trig):
                st['esm_n'] += len(trig)
                for win, key in [(60,'esm_hit60'),(15,'esm_hit15')]:
                    lo = np.searchsorted(ts, trig - win*60000, side='right'); hi = np.searchsorted(ts, trig, side='right')
                    st[key] += int(np.sum(hi > lo))
            for c in CATS.get(name, []):
                if c in df.columns:
                    vc = df[c].astype(str).value_counts()
                    if len(vc) <= 60:
                        st['cats'][c].update(vc.to_dict())
                    else:
                        st['cats'][c]['<many distinct>'] += 1
            if name in NUMMED and NUMMED[name] in df.columns:
                v = pd.to_numeric(df[NUMMED[name]], errors='coerce').dropna()
                if len(v): st['med'].append(float(v.median()))
            if name.startswith('Fitness-') and 'fromTime' in df.columns:
                d = (pd.to_numeric(df['toTime'], errors='coerce') - pd.to_numeric(df['fromTime'], errors='coerce')).dropna()
                if len(d): st['dur_med'].append(float(d.median())/60000)
            if name in ('Fitbit-StepCount.csv','Fitness-StepCount.csv'):
                tcol = 'fromTime' if name.startswith('Fitness') and 'fromTime' in df.columns else 'timestamp'
                dd = pd.DataFrame({'day': (pd.to_numeric(df[tcol], errors='coerce') + KST)//86400000,
                                   'v': pd.to_numeric(df['value'], errors='coerce')}).dropna()
                daily[name] = dd.groupby('day')['v'].sum()
        tf.close()
        if 'Fitbit-StepCount.csv' in daily and 'Fitness-StepCount.csv' in daily:
            j = pd.concat([daily['Fitbit-StepCount.csv'], daily['Fitness-StepCount.csv']], axis=1, join='inner').dropna()
            for r in j.itertuples(index=False): steps_pairs.append((r[0], r[1]))
        print(w, 'done', os.path.basename(a), file=sys.stderr, flush=True)
    out = {}
    for name, st in sorted(stats.items()):
        out[name] = {'n_arch': st['n_arch'], 'rows_median': float(np.median(st['rows'])) if st['rows'] else None,
                     'days_median': float(np.median(st['days'])) if st['days'] else None,
                     'share_nonempty': float(np.mean(np.array(st['rows'])>0)) if st['rows'] else None,
                     'esm_cov60': st['esm_hit60']/st['esm_n'] if st['esm_n'] else None,
                     'esm_cov15': st['esm_hit15']/st['esm_n'] if st['esm_n'] else None,
                     'value_median_of_medians': float(np.median(st['med'])) if st['med'] else None,
                     'fitness_interval_min_median': float(np.median(st['dur_med'])) if st['dur_med'] else None,
                     'cats': {c: dict(cnt.most_common(25)) for c, cnt in st['cats'].items()}}
    if steps_pairs:
        a_ = np.array(steps_pairs)
        out['_steps_fitbit_vs_fitness'] = {'participant_days': len(a_), 'pearson': float(np.corrcoef(a_[:,0], a_[:,1])[0,1]),
                                          'median_ratio_fitness_over_fitbit': float(np.median(a_[:,1]/np.maximum(a_[:,0],1)))}
    out['_n_archives'] = len(arcs); out['_esm_responses'] = int(len(esm)); out['_esm_participants'] = int(esm['p'].nunique())
    res[w] = out
    json.dump(res, open(OUT,'w'), indent=1, default=str)
print('ALL DONE', file=sys.stderr)
