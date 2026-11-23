"""Step 2: one pass over the three BSON collections inside the zip (streamed, never extracted).

- heart_rate, steps  -> compact arrays (user index, local time ms, value) in DERIVED/*.npz
- other low-volume types -> flattened scalar fields, one CSV per type in DERIVED/types/
- very large secondary types (calories, distance, wrist temperature, ...) -> counted only
- schema (keys and value types only) and counts -> OUT/bson_schema.json (aggregate)
Free-text SEMA fields (OTHER...) are dropped.
Usage: python -I -B s02_extract.py
"""
import collections
import json
import sys
import time
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common as C  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import bson  # noqa: E402

FLATTEN_CAP = 600_000           # types above this many docs are counted only
ARRAY_TYPES = {"heart_rate", "steps"}

C.DERIVED.mkdir(parents=True, exist_ok=True)
(C.DERIVED / "types").mkdir(exist_ok=True)
C.OUT.mkdir(parents=True, exist_ok=True)
z = zipfile.ZipFile(C.ZIP)
listing = [(i.filename, i.file_size) for i in z.infolist()]
with open(C.OUT / "zip_listing.txt", "w") as f:
    for name, size in listing:
        f.write(f"{name}\t{size/1e6:.1f} MB\n")


def shape(v, depth=0):
    if isinstance(v, dict):
        return {k: shape(x, depth + 1) for k, x in v.items()} if depth < 4 else "dict"
    if isinstance(v, list):
        return [shape(v[0], depth + 1)] if v else []
    return type(v).__name__


def flatten(d, prefix=""):
    out = {}
    for k, v in d.items():
        key = f"{prefix}{k}"
        if "OTHER" in str(k).upper():
            continue
        if isinstance(v, dict):
            out.update(flatten(v, key + "."))
        elif isinstance(v, list):
            out[key + "#len"] = len(v)
        else:
            out[key] = v if isinstance(v, (int, float, str, bool)) or v is None else str(v)
    return out


users = {}


def uidx(doc):
    u = str(doc.get("id", doc.get("user_id")))
    return users.setdefault(u, len(users))


schema, rows = {}, collections.defaultdict(list)
counts, type_users = collections.Counter(), collections.defaultdict(set)
arr = {t: {"u": [], "s": [], "v": []} for t in ARRAY_TYPES}
done = {t: {"u": [], "ms": [], "v": []} for t in ARRAY_TYPES}
CHUNK = 2_000_000


def to_ms(strings):
    s = pd.Series(strings)
    try:
        d = pd.to_datetime(s)
    except (ValueError, TypeError):
        d = pd.to_datetime(s, format="mixed")
    return d.astype("datetime64[ms]").astype("int64").to_numpy()


def flush(base):
    a, d = arr[base], done[base]
    if not a["u"]:
        return
    d["u"].append(np.asarray(a["u"], dtype=np.int16))
    d["ms"].append(to_ms(a["s"]))
    d["v"].append(np.asarray(a["v"], dtype=np.float32))
    a["u"].clear(); a["s"].clear(); a["v"].clear()
fail = collections.Counter()
type_total = {}
for name, _ in listing:
    if not name.endswith(".bson"):
        continue
    coll = Path(name).stem
    t0 = time.time()
    with z.open(name) as fh:
        for doc in bson.decode_file_iter(fh):
            t = f"{coll}:{doc.get('type')}"
            counts[t] += 1
            u = uidx(doc)
            type_users[t].add(u)
            data = doc.get("data") or {}
            if t not in schema:
                schema[t] = shape(data)
            base = t.split(":", 1)[1]
            if coll == "fitbit" and base in ARRAY_TYPES:
                try:
                    val = data["value"]
                    v = float(val["bpm"]) if isinstance(val, dict) else float(val)
                    a = arr[base]
                    a["u"].append(u); a["s"].append(data["dateTime"]); a["v"].append(v)
                    if len(a["u"]) >= CHUNK:
                        flush(base)
                except Exception:
                    fail[base] += 1
            elif counts[t] <= FLATTEN_CAP:
                r = flatten(data)
                r["_u"] = u
                rows[t].append(r)
    print(f"{name}: {sum(c for k, c in counts.items() if k.startswith(coll + ':'))} docs "
          f"in {time.time() - t0:.0f} s", flush=True)

# arrays: flush the last chunk and save
for base in ARRAY_TYPES:
    flush(base)
    d = done[base]
    u = np.concatenate(d["u"]) if d["u"] else np.zeros(0, np.int16)
    ms = np.concatenate(d["ms"]) if d["ms"] else np.zeros(0, np.int64)
    v = np.concatenate(d["v"]) if d["v"] else np.zeros(0, np.float32)
    np.savez(C.DERIVED / f"{base}.npz", u=u, t_local_ms=ms, v=v)
    print(base, len(ms), "rows saved; parse failures:", fail[base], flush=True)

for t, r in rows.items():
    if counts[t] > FLATTEN_CAP:
        continue  # partially read large type: not saved
    fn = t.replace(":", "__").replace(" ", "_").replace("/", "_")
    pd.DataFrame(r).to_csv(C.DERIVED / "types" / f"{fn}.csv", index=False)
json.dump({"users": len(users), "array_parse_failures": dict(fail),
           "types": {t: {"docs": counts[t], "users": len(type_users[t]),
                         "flattened": counts[t] <= FLATTEN_CAP, "data_shape": schema[t]}
                     for t in sorted(counts)}},
          open(C.OUT / "bson_schema.json", "w"), indent=1, default=str)
json.dump(users, open(C.DERIVED / "user_index.json", "w"))
print("done; users:", len(users))
