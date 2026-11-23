"""Where do the raw (un-referenced) window values help? Subset scoring on the same 5 folds.
Models are fitted on all training rows; only the scored test rows are restricted. Aggregates only."""
import sys
import warnings

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, "/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts")
from evaluate import FAM, OUT, TARGETS, V1F, fmt, fold_scores, folds, load, paired  # noqa: E402

warnings.filterwarnings("ignore")
cv = load()
splits = folds(cv.participant)
RAW = FAM["R1 raw steps (no reference)"] + FAM["R2 raw HR (no reference)"]
ACT = ["tr_still_60", "tr_foot_60", "act_still_60", "act_foot_60"]
zk = cv.z_hr_30.notna().to_numpy()
rk = cv.raw_hr_30.notna().to_numpy()
first = cv.t.to_numpy() - cv.groupby("participant").t.transform("min").to_numpy() < 7 * 86400000
subsets = {"z_hr_30 known": zk, "z_hr_30 unknown, raw HR known": ~zk & rk, "no HR at all": ~rk,
           "first 7 days of the participant": first, "wave D-1": (cv.wave == "D1").to_numpy(),
           "wave D-2": (cv.wave == "D2").to_numpy()}
lines = [f"share of answers: " + ", ".join(f"{k} {v.mean():.3f}" for k, v in subsets.items())]
for target in TARGETS:
    lines.append(f"## {target}")
    for name, m in subsets.items():
        b = fold_scores(cv, V1F, target, splits, subset=m)
        r = fold_scores(cv, V1F + RAW, target, splits, subset=m)
        a = fold_scores(cv, V1F + RAW + ACT, target, splits, subset=m)
        lines.append(f"  {name:<34} n={m.sum():>5}  v1 {fmt(b)}  +raw Δ {paired(r, b)}")
        lines.append(f"  {'':<34} {'':>7}  +raw+activity Δ vs v1 {paired(a, b)}")
txt = "\n".join(lines)
print(txt)
open(f"{OUT}/diag.txt", "w").write(txt + "\n")
