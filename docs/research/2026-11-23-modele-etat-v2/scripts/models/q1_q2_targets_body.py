"""Q1 (valence / stress targets with the same features) and Q2 (body mode, mixed app behaviour).

Same 5 GroupKFold splits as ml/train.py, same model (median imputation + scaler + LR C=1).
Prints aggregates only.
"""
import numpy as np

from common import (F13, TARGETS, TIME, auc, bal, load_table, ms, paired, splits_of, train)

table = load_table()
splits = splits_of(table)
X13 = table[F13].to_numpy(float)
XT = table[TIME].to_numpy(float)
known = table.z_hr_30.notna().to_numpy()
print(f"D-1 + D-2: {len(table)} answers, {table.participant.nunique()} participants, 5 folds")
print(f"z_hr_30 known: {known.mean():.3f} of answers")
for k in TARGETS:
    print(f"  base rate {k}_high = {table[f'{k}_high'].mean():.3f}"
          f" (z_hr_30 known: {table.loc[known, f'{k}_high'].mean():.3f},"
          f" unknown: {table.loc[~known, f'{k}_high'].mean():.3f})")

print("\n=== Q1: target x inputs (LR C=1), fold mean +/- sd ===")
for k in TARGETS:
    y = table[f"{k}_high"].to_numpy()
    r = {"time": [], "f13": [], "f13_known_only_train": [],
         "body_f13": [], "body_time": [], "body_spec": [], "nobody_time": [], "nobody_f13": [],
         "mixed": [], "mixed_spec": []}
    b = {"time": [], "f13": [], "mixed": []}
    for tr, te in splits:
        mt = train.make_model().fit(XT[tr], y[tr])
        m13 = train.make_model().fit(X13[tr], y[tr])
        trk = tr[known[tr]]
        mspec = train.make_model().fit(X13[trk], y[trk])  # trained on body rows only
        pt = mt.predict_proba(XT[te])[:, 1]
        p13 = m13.predict_proba(X13[te])[:, 1]
        ps = mspec.predict_proba(X13[te])[:, 1]
        kn = known[te]
        yt = y[te]
        r["time"].append(auc(yt, pt)); b["time"].append(bal(yt, pt))
        r["f13"].append(auc(yt, p13)); b["f13"].append(bal(yt, p13))
        r["body_f13"].append(auc(yt[kn], p13[kn]))
        r["body_time"].append(auc(yt[kn], pt[kn]))
        r["body_spec"].append(auc(yt[kn], ps[kn]))
        r["nobody_time"].append(auc(yt[~kn], pt[~kn]))
        r["nobody_f13"].append(auc(yt[~kn], p13[~kn]))
        pm = np.where(kn, p13, pt)
        r["mixed"].append(auc(yt, pm)); b["mixed"].append(bal(yt, pm))
        r["mixed_spec"].append(auc(yt, np.where(kn, ps, pt)))
    print(f"\n[{k}_high]")
    print(f"  time only (3)      AUROC {ms(r['time'])}  BA {ms(b['time'])}")
    print(f"  13 features        AUROC {ms(r['f13'])}  BA {ms(b['f13'])}")
    print(f"    paired 13 - time AUROC {paired(r['f13'], r['time'])}; BA {paired(b['f13'], b['time'])}")
    print(f"  Q2 body mode (test rows with z_hr_30 known):")
    print(f"    13-feat model (trained on all rows)   AUROC {ms(r['body_f13'])}")
    print(f"    13-feat model (trained on body rows)  AUROC {ms(r['body_spec'])}")
    print(f"    time-only model on same rows          AUROC {ms(r['body_time'])}")
    print(f"      paired 13(all) - time   {paired(r['body_f13'], r['body_time'])}")
    print(f"      paired 13(body) - 13(all) {paired(r['body_spec'], r['body_f13'])}")
    print(f"  Q2 rows with z_hr_30 unknown: time-only AUROC {ms(r['nobody_time'])};"
          f" 13-feat AUROC {ms(r['nobody_f13'])}")
    print(f"  Q2 app mixed (13 if z_hr_30 known else time) AUROC {ms(r['mixed'])}  BA {ms(b['mixed'])}")
    print(f"      paired mixed - 13 on all  {paired(r['mixed'], r['f13'])}")
    print(f"      paired mixed - time       {paired(r['mixed'], r['time'])}")
    print(f"  Q2 mixed with body-trained 13-feat model AUROC {ms(r['mixed_spec'])};"
          f" paired vs mixed {paired(r['mixed_spec'], r['mixed'])}")
