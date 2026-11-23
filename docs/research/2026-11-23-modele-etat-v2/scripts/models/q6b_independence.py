"""Q6 complement (LR C=1 on 13 features, OOF over the 5 splits of ml/train.py):
does the valence model carry information beyond the arousal model?
- correlation of the two predicted axes vs correlation of the true labels
- AUROC of p_valence for valence_high within each true arousal stratum
- AUROC of the 'off-diagonal' score (logit p_V - logit p_A) for the off-diagonal truth
  (valence_high - arousal_high: +1 calm-positive vs -1 tense), rows where the labels differ
- precision P(true quadrant | predicted quadrant), base-rate thresholds
Aggregates only."""
import numpy as np

from common import F13, auc, load_table, logit, ms, spearman, splits_of, train

table = load_table()
splits = splits_of(table)
X = table[F13].to_numpy(float)
XT = table[F13[:3]].to_numpy(float)
YA, YV = table.arousal_high.to_numpy(), table.valence_high.to_numpy()
for xname, XX in (("13 features", X), ("time only", XT)):
    pa, pv = np.zeros(len(YA)), np.zeros(len(YA))
    thr_a, thr_v = np.zeros(len(YA)), np.zeros(len(YA))
    f_strat, f_off = [], []
    for tr, te in splits:
        pa[te] = train.make_model().fit(XX[tr], YA[tr]).predict_proba(XX[te])[:, 1]
        pv[te] = train.make_model().fit(XX[tr], YV[tr]).predict_proba(XX[te])[:, 1]
        thr_a[te], thr_v[te] = YA[tr].mean(), YV[tr].mean()
        a, v = YA[te], YV[te]
        f_strat.append((auc(v[a == 0], pv[te][a == 0]), auc(v[a == 1], pv[te][a == 1]),
                        auc(a[v == 0], pa[te][v == 0]), auc(a[v == 1], pa[te][v == 1])))
        d = a != v
        off = logit(pv[te]) - logit(pa[te])
        f_off.append(auc(v[d], off[d]))       # 1 = calm-positive (lowA-highV), 0 = tense
    f_strat = np.array(f_strat)
    print(f"\n[{xname}] Spearman(p_A, p_V) {spearman(pa, pv):.3f}; "
          f"true labels phi {np.corrcoef(YA, YV)[0, 1]:.3f}")
    print(f"  AUROC p_V for valence_high | arousal low {ms(f_strat[:, 0])}; | arousal high {ms(f_strat[:, 1])}")
    print(f"  AUROC p_A for arousal_high | valence low {ms(f_strat[:, 2])}; | valence high {ms(f_strat[:, 3])}")
    print(f"  off-diagonal AUROC (logit p_V - logit p_A) calm-positive vs tense, rows A!=V: {ms(f_off)}")
    true_q = 2 * YA + YV
    pq = 2 * (pa > thr_a) + (pv > thr_v)
    names = ["lowA-lowV", "lowA-highV", "highA-lowV", "highA-highV"]
    print("  precision P(true q | predicted q), base-rate thresholds (true share in brackets):")
    for q in range(4):
        m = pq == q
        print(f"    predicted {names[q]:<12} (pred share {m.mean():.3f}): precision "
              f"{(true_q[m] == q).mean():.3f} [base {(true_q == q).mean():.3f}]")
