"""Print CSV headers (column names only) of each sensor file in the first archive of each wave,
plus, for low-cardinality non-identifying columns, the set of distinct category labels (aggregate)."""
import sys, tarfile, io, glob, os, collections
import pandas as pd
BASE = sys.argv[1]
SENSITIVE = ('number','name','contact','package','ssid','bssid','mac','address','lat','lon','altitude','app','uid','text','title')
for w in ['D1','D2','D3']:
    arcs = sorted(glob.glob(os.path.join(BASE, w, 'Sensor', '*.tar.gz')))
    print('=====', w, 'archives', len(arcs))
    with tarfile.open(arcs[len(arcs)//2], 'r|gz') as tf:
        for m in tf:
            if not m.isfile() or os.path.basename(m.name).startswith('.'):
                continue
            f = tf.extractfile(m)
            data = f.read()
            name = os.path.basename(m.name)
            try:
                df = pd.read_csv(io.BytesIO(data), nrows=200000, low_memory=False)
            except Exception as e:
                print(name, 'ERR', e); continue
            print(f'-- {name}: cols={list(df.columns)}')
            for c in df.columns:
                if any(s in c.lower() for s in SENSITIVE):
                    continue
                if df[c].dtype == object:
                    nun = df[c].nunique()
                    if nun <= 25:
                        print(f'     {c}: categories={sorted(map(str, df[c].dropna().unique()))}')
                    else:
                        print(f'     {c}: object, {nun} distinct (not shown)')
