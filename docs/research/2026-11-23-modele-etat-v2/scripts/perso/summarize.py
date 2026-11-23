"""Markdown tables (aggregates only) from out/*.json -> out/summary_<config>.md and out/overview.md."""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "out"
M = ["pop", "m1_intercept", "m1d_intercept_decay", "m2_bayes", "m3_hist", "m4a_bayes_on_hist",
     "m4b_logit_avg", "m4c_decay_on_hist", "m5_histonly", "m5t_hist_time", "base_rate", "time"]
S = {"pop": "0 pop", "time": "time-only", "m1_intercept": "1 int", "m1d_intercept_decay": "1d int-decay",
     "m2_bayes": "2 bayes", "m3_hist": "3 hist", "m4a_bayes_on_hist": "4a bayes+hist",
     "m4b_logit_avg": "4b avg", "m4c_decay_on_hist": "4c decay+hist", "m5_histonly": "5 hist-only", "m5t_hist_time": "5t hist+time",
     "base_rate": "past-mean"}
MIN_PERS = 20


def star(b, m, key="d_auc_ci", better=lambda ci: ci[0] > 0):
    ci = b[m].get(key)
    return "*" if ci and better(ci) else ""


def curve_table(block, metric, key=None, better=None, digits=3):
    head = "| bucket | rows | pers | " + " | ".join(S[m] for m in M) + " |"
    lines = [head, "|" + "---|" * (len(M) + 3)]
    for lab, b in block.items():
        if "pop" not in b:
            continue
        cells = []
        for m in M:
            v = b[m][metric]
            s = "-" if v is None else f"{v:.{digits}f}"
            if key and m != "pop":
                s += star(b, m, key, better)
            cells.append(s)
        lines.append(f"| {lab} | {b['rows']} | {b['persons']} | " + " | ".join(cells) + " |")
    return "\n".join(lines)


def reliable_from(block, m, key="d_auc_ci", better=lambda ci: ci[0] > 0):
    """First bucket from which every later bucket (>= MIN_PERS persons) has CI on the good side."""
    labs = [lab for lab, b in block.items() if "pop" in b and b["persons"] >= MIN_PERS]
    ok = [bool(block[lab][m].get(key)) and better(block[lab][m][key]) for lab in labs]
    for i in range(len(labs)):
        if all(ok[i:]):
            return labs[i]
    return "never"


def summarize(name):
    r = json.loads((OUT / f"{name}.json").read_text())
    out = [f"# {name}", "", f"info: {r['info']}", ""]
    out.append("tuned per outer fold (inner 4-fold simulation, log-loss): "
               + "; ".join(f"tb1={p['tb1']}, g1d={p['g1d']}, g2={p['g2']}, g4={p['g4']}, n0={p['n0']}"
                           for p in r["params"]) + "; g4c=" + str([p.get("g4c") for p in r["params"]]))
    pf = r["per_fold_auc_all_rows"]
    out.append("\nper-fold mean AUROC, all rows, seed 0: " + ", ".join(
        f"{S[m]} {sum(pf[m]) / len(pf[m]):.3f}" for m in M))
    for key in ("all_rows", "rows_with_checkins"):
        b = r[key]
        out.append(f"\n## {key} (rows {b['rows']}, persons {b['persons']})\n")
        out.append("| metric | " + " | ".join(S[m] for m in M) + " |")
        out.append("|" + "---|" * (len(M) + 1))
        for met, k in (("auc", "d_auc_ci"), ("auc_within", "d_auc_within_ci"), ("bal_acc", None),
                       ("brier", "d_brier_ci"), ("p10", None), ("p50", None), ("p90", None),
                       ("sd", None), ("sd_within", None)):
            cells = []
            for m in M:
                v = b[m][met]
                s = "-" if v is None else f"{v:.3f}"
                if k and m != "pop":
                    s += star(b, m, k, (lambda ci: ci[1] < 0) if met == "brier" else (lambda ci: ci[0] > 0))
                cells.append(s)
            out.append(f"| {met} | " + " | ".join(cells) + " |")
        out.append("\nwithin-person delta vs pop, 95% CI: " + ", ".join(
            f"{S[m]} {b[m]['d_auc_within']:+.3f} [{b[m]['d_auc_within_ci'][0]:+.3f},{b[m]['d_auc_within_ci'][1]:+.3f}]"
            for m in M[1:] if b[m]["d_auc_within_ci"]))
    def pairs_block(title, blocks):
        out.append(f"\n## pairwise deltas ({title}): d pooled AUROC [95% CI] / d Brier [CI] / d within-person AUROC [CI]\n")
        for lab, b in blocks.items():
            if "pairs" not in b:
                continue
            out.append(f"- {lab}: " + "; ".join(
                f"{k}: {v['d_auc']:+.3f} [{v['d_auc_ci'][0]:+.3f},{v['d_auc_ci'][1]:+.3f}] / "
                f"{v['d_brier']:+.4f} [{v['d_brier_ci'][0]:+.4f},{v['d_brier_ci'][1]:+.4f}] / "
                + (f"{v['d_within']:+.3f} [{v['d_within_ci'][0]:+.3f},{v['d_within_ci'][1]:+.3f}]" if v['d_within_ci'] else "-")
                for k, v in b["pairs"].items()))
    pairs_block("whole period", {"rows_with_checkins": r["rows_with_checkins"]})
    pairs_block("by_day", r["by_day"])
    pairs_block("by_n", r["by_n"])
    for scheme in ("by_n", "by_day"):
        blk = r[scheme]
        out.append(f"\n## {scheme}: pooled AUROC (* = 95% cluster-bootstrap CI of delta vs pop > 0)\n")
        out.append(curve_table(blk, "auc", "d_auc_ci", lambda ci: ci[0] > 0))
        out.append(f"\n## {scheme}: mean within-person AUROC (* = CI of mean delta > 0)\n")
        out.append(curve_table(blk, "auc_within", "d_auc_within_ci", lambda ci: ci[0] > 0))
        out.append(f"\n## {scheme}: Brier (* = CI of delta vs pop < 0)\n")
        out.append(curve_table(blk, "brier", "d_brier_ci", lambda ci: ci[1] < 0))
        out.append(f"\n## {scheme}: balanced accuracy\n")
        out.append(curve_table(blk, "bal_acc"))
        out.append(f"\n## {scheme}: p10 / p90 of predicted probabilities\n")
        out.append(curve_table(blk, "p10", digits=2))
        out.append("")
        out.append(curve_table(blk, "p90", digits=2))
        out.append(f"\n{scheme} reliable-from (pooled AUROC CI>0 in every later bucket with >= {MIN_PERS} persons): "
                   + ", ".join(f"{S[m]}: {reliable_from(blk, m)}" for m in M[1:]))
        out.append(f"\n{scheme} reliable-from (Brier CI<0): " + ", ".join(
            f"{S[m]}: {reliable_from(blk, m, 'd_brier_ci', lambda ci: ci[1] < 0)}" for m in M[1:]))
    if "frozen" in r:
        f = r["frozen"]
        out.append(f"\n## frozen design: first n check-ins then nothing; evaluate days >= {f['eval_days_from']} "
                   f"(persons with >= {f['n_max_before']} check-ins before)\n")
        out.append("pooled AUROC\n")
        out.append(curve_table(f["by_n"], "auc", "d_auc_ci", lambda ci: ci[0] > 0))
        out.append("\nmean within-person AUROC\n")
        out.append(curve_table(f["by_n"], "auc_within", "d_auc_within_ci", lambda ci: ci[0] > 0))
        out.append("\nBrier\n")
        out.append(curve_table(f["by_n"], "brier", "d_brier_ci", lambda ci: ci[1] < 0))
        n1 = f["by_n"]
        out.append("\nfrozen within-person delta (m1 intercept - pop) per n, 95% CI: " + ", ".join(
            f"n={n}: {b['m1_intercept']['d_auc_within']:+.4f} {b['m1_intercept']['d_auc_within_ci']}"
            for n, b in n1.items() if "pop" in b))
    (OUT / f"summary_{name}.md").write_text("\n".join(out))
    return r


def main():
    names = sorted(p.stem for p in OUT.glob("*.json") if not p.stem.startswith(("uncert", "lag")))
    ov = ["# overview: pooled AUROC / within-person AUROC (whole period) / Brier, rolling, rows with >= 1 check-in", "",
          "| config | " + " | ".join(S[m] for m in M) + " |", "|" + "---|" * (len(M) + 1)]
    for n in names:
        r = summarize(n)
        b = r["rows_with_checkins"]
        ov.append(f"| {n} | " + " | ".join(
            f"{b[m]['auc']:.3f}{star(b, m) if m != 'pop' else ''} / {b[m]['auc_within']:.3f}"
            f"{star(b, m, 'd_auc_within_ci') if m != 'pop' else ''} / {b[m]['brier']:.3f}" for m in M) + " |")
    ov.append("")
    ov.append("| config (by day, pooled AUROC) | method | " + " | ".join(
        ["1", "2-3", "4-7", "8-14", "15-21", "22-28", "29+"]) + " |")
    ov.append("|---|---|" + "---|" * 7)
    for n in names:
        r = json.loads((OUT / f"{n}.json").read_text())
        for m in ("pop", "m1_intercept", "m1d_intercept_decay", "m2_bayes", "m3_hist", "m4a_bayes_on_hist", "m4c_decay_on_hist", "m5t_hist_time"):
            cells = []
            for lab in ["1", "2-3", "4-7", "8-14", "15-21", "22-28", "29+"]:
                b = r["by_day"].get(lab)
                cells.append("-" if not b or "pop" not in b else f"{b[m]['auc']:.3f}{star(b, m) if m != 'pop' else ''}")
            ov.append(f"| {n} | {S[m]} | " + " | ".join(cells) + " |")
    (OUT / "overview.md").write_text("\n".join(ov))
    print("wrote", len(names), "summaries")


if __name__ == "__main__":
    main()
