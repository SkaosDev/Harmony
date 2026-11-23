"""Q4 complement: value of one answered in-app item as an extra input (upper bound of a
'question' feature). For each target T and each other item Q, LR C=1 on the 13 v1 features
+ Q's answer, coded (i) raw -3..+3, (ii) minus the person's past-only mean (>= 5 earlier
answers, else unknown -> training median). Same 5 splits as ml/train.py. Aggregates only."""
import numpy as np

from common import F13, TARGETS, auc, load_table, ms, paired, splits_of, train

table = load_table().copy()
splits = splits_of(table)
order = np.lexsort((table.t.to_numpy(), table.participant.to_numpy()))
for q in TARGETS:
    s = table.iloc[order].groupby("participant")[q]
    past_mean = s.transform(lambda v: v.shift(1).expanding().mean())
    past_n = s.cumcount()
    pc = (table.iloc[order][q] - past_mean).where(past_n >= 5)
    table.loc[table.index[order], f"{q}_pastc"] = pc.to_numpy()
print(f"share with >= 5 earlier answers: {table['arousal_pastc'].notna().mean():.3f}")
X13 = table[F13].to_numpy(float)
for k in TARGETS:
    y = table[f"{k}_high"].to_numpy()
    base = [auc(y[te], train.make_model().fit(X13[tr], y[tr]).predict_proba(X13[te])[:, 1])
            for tr, te in splits]
    print(f"\n[{k}_high] LR 13 features AUROC {ms(base)}")
    for q in TARGETS:
        if q == k:
            continue
        for code in (q, f"{q}_pastc"):
            X = np.column_stack([X13, table[code].to_numpy(float)])
            r = [auc(y[te], train.make_model().fit(X[tr], y[tr]).predict_proba(X[te])[:, 1])
                 for tr, te in splits]
            print(f"  + answered {code:<14} AUROC {ms(r)}  paired vs 13 {paired(r, base)}")
