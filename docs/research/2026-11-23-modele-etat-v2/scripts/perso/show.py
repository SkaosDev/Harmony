"""Print compact aggregate tables from out/<config>.json (aggregates only)."""
import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "out"
SHORT = {"pop": "pop", "time": "time", "m1_intercept": "m1", "m1d_intercept_decay": "m1d", "m2_bayes": "m2", "m3_hist": "m3",
         "m4a_bayes_on_hist": "m4a", "m4b_logit_avg": "m4b", "m5_histonly": "m5",
         "m5t_hist_time": "m5t", "base_rate": "base"}


def fmt_ci(ci):
    return f"[{ci[0]:+.3f},{ci[1]:+.3f}]" if ci else "-"


def table(block, metric, methods, title):
    print(f"\n  {title} -- {metric}")
    print("  bucket   rows  pers | " + " ".join(f"{SHORT[m]:>7}" for m in methods))
    for lab, b in block.items():
        if "pop" not in b:
            print(f"  {lab:<7}{b['rows']:>6}{b['persons']:>6} | (too few)")
            continue
        vals = []
        for m in methods:
            v = b[m][metric]
            vals.append(f"{v:7.3f}" if v is not None else "      -")
        print(f"  {lab:<7}{b['rows']:>6}{b['persons']:>6} | " + " ".join(vals))


def sig(block, methods, title, key="d_auc_ci"):
    print(f"\n  {title} -- 95% CI of delta vs pop ({key}); * = CI excludes 0 (better)")
    print("  bucket  | " + " ".join(f"{SHORT[m]:>17}" for m in methods))
    for lab, b in block.items():
        if "pop" not in b:
            continue
        cells = []
        for m in methods:
            ci = b[m][key]
            better = ci and ((ci[0] > 0) if key != "d_brier_ci" else (ci[1] < 0))
            cells.append(f"{fmt_ci(ci):>16}{'*' if better else ' '}")
        print(f"  {lab:<7} | " + " ".join(cells))


def main(name, methods=None):
    r = json.loads((OUT / f"{name}.json").read_text())
    methods = methods or list(SHORT)
    print(f"=== {name}: {r['info']}")
    for p in r["params"]:
        print("  params", {k: (round(v, 4) if isinstance(v, float) else v) for k, v in p.items()})
    print("  per-fold AUROC all rows (seed 0):",
          {SHORT[m]: f"{sum(v) / len(v):.3f}" for m, v in r["per_fold_auc_all_rows"].items()})
    for key in ("all_rows", "rows_with_checkins"):
        b = r[key]
        print(f"  {key}: rows {b['rows']} " + " ".join(
            f"{SHORT[m]}={b[m]['auc']:.3f}/{b[m]['auc_within']:.3f}" for m in methods))
    for scheme in ("by_n", "by_day"):
        table(r[scheme], "auc", methods, scheme)
        table(r[scheme], "auc_within", methods, scheme)
        sig(r[scheme], methods[1:], scheme)
        sig(r[scheme], methods[1:], scheme, "d_auc_within_ci")
        table(r[scheme], "brier", methods, scheme)
        table(r[scheme], "bal_acc", methods, scheme)
        table(r[scheme], "sd", methods, scheme)
        table(r[scheme], "sd_within", methods, scheme)
    if "frozen" in r:
        f = r["frozen"]
        print(f"\n  FROZEN: eval days >= {f['eval_days_from']}, persons need >= {f['n_max_before']} check-ins before")
        table(f["by_n"], "auc", methods, "frozen by n")
        table(f["by_n"], "auc_within", methods, "frozen by n")
        sig(f["by_n"], methods[1:], "frozen by n")
        sig(f["by_n"], methods[1:], "frozen by n", "d_auc_within_ci")
        table(f["by_n"], "brier", methods, "frozen by n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2].split(",") if len(sys.argv) > 2 else None)
