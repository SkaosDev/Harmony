"""Compact aggregate tables for the notes -> ../out/compact.md."""
import json
from pathlib import Path
OUT = Path(__file__).resolve().parent.parent / "out"
MS = ["pop", "m1_intercept", "m1d_intercept_decay", "m2_bayes", "m3_hist", "m4a_bayes_on_hist",
      "m4c_decay_on_hist", "m5t_hist_time", "base_rate"]
H = ["0 pop", "1 int", "1d int-decay", "2 bayes", "3 hist", "4a", "4c", "5t hist+time", "past-mean"]
L = []
def tab(block, metric, ci, good):
    L.append("| bucket | persons | " + " | ".join(H) + " |")
    L.append("|---|---|" + "---|" * len(H))
    for lab, b in block.items():
        if "pop" not in b:
            continue
        cells = []
        for m in MS:
            s = f"{b[m][metric]:.3f}" if b[m][metric] is not None else "-"
            c = b[m].get(ci)
            if m != "pop" and c and good(c):
                s += "*"
            cells.append(s)
        L.append(f"| {lab} | {b['persons']} | " + " | ".join(cells) + " |")
for name in ("arousal_past_r2", "arousal_full_r2", "arousal_past_r1", "arousal_past_r4", "valence_past_r2", "stress_past_r2"):
    r = json.loads((OUT / f"{name}.json").read_text())
    for sch in ("by_n", "by_day"):
        L.append(f"\n### {name} {sch}: pooled AUROC (* CI>0 vs pop)\n")
        tab(r[sch], "auc", "d_auc_ci", lambda c: c[0] > 0)
        if name.startswith("arousal_past_r2") or name.startswith("arousal_full_r2"):
            L.append(f"\n### {name} {sch}: Brier (* CI<0 vs pop)\n")
            tab(r[sch], "brier", "d_brier_ci", lambda c: c[1] < 0)
for name in ("arousal_past_r2", "arousal_full_r2", "arousal_past_r2_null"):
    r = json.loads((OUT / f"{name}.json").read_text())
    L.append(f"\n### {name} frozen (first n check-ins only; rows on days >= 21): pooled AUROC\n")
    tab(r["frozen"]["by_n"], "auc", "d_auc_ci", lambda c: c[0] > 0)
    L.append(f"\n### {name} frozen: within-person AUROC\n")
    tab(r["frozen"]["by_n"], "auc_within", "d_auc_within_ci", lambda c: c[0] > 0)
    L.append("\nfrozen m1 within-person delta: " + "; ".join(
        f"n={n}: {b['m1_intercept']['d_auc_within']:+.5f} [{b['m1_intercept']['d_auc_within_ci'][0]:+.5f},{b['m1_intercept']['d_auc_within_ci'][1]:+.5f}]"
        for n, b in r["frozen"]["by_n"].items() if "pop" in b and b["m1_intercept"]["d_auc_within_ci"]))
(OUT / "compact.md").write_text("\n".join(L))
print("ok")
