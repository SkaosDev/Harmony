"""Aggregate tables for lag, uncertainty and cohort outputs -> ../out/extra.md (aggregates only)."""
import json
from pathlib import Path
OUT = Path(__file__).resolve().parent.parent / "out"
L = []
def f(b, m, k="auc"):
    return f"{b[m][k]:.3f}" if m in b and b[m][k] is not None else "-"
for name in ("lag_arousal_past_r2", "lag_arousal_full_r2"):
    r = json.loads((OUT / f"{name}.json").read_text())
    ms = ["pop", "m1_intercept", "m1d_intercept_decay", "m1d_now", "m3_hist", "m4c_decay_on_hist", "m5t_hist_time"]
    L.append(f"\n## {name} (rows on days >= 15; only check-ins older than the lag)\n")
    L.append("| lag (days) | rows | persons | " + " | ".join(ms) + " |")
    L.append("|---|---|---|" + "---|" * len(ms))
    for lag, b in r.items():
        L.append(f"| {lag} | {b['rows']} | {b['persons']} | " + " | ".join(
            f"{f(b, m)} / {f(b, m, 'auc_within')} / {f(b, m, 'brier')}"
            + ("*" if m != "pop" and b[m]["d_auc_ci"][0] > 0 else "") for m in ms) + " |")
    L.append("cells: pooled AUROC / within-person AUROC / Brier; * = pooled AUROC CI vs pop > 0")
for name in ("uncert_m1d_arousal_past_r2", "uncert_m3_arousal_past_r2", "uncert_m1d_arousal_full_r2", "uncert_m1d_valence_past_r2"):
    r = json.loads((OUT / f"{name}.json").read_text())
    ms = ["pop", "m1_intercept", "m1d_intercept_decay", "m3_hist", "m4c_decay_on_hist"]
    L.append(f"\n## {name}: share of 'high' answers among check-ins {r['share_high_in_checkins']}\n")
    for scope in ("all_rows",):
        L.append("| policy | " + " | ".join(ms) + " |")
        L.append("|---|" + "---|" * len(ms))
        for pol in ("random", "uncertain"):
            b = r[pol][scope]
            L.append(f"| {pol} (all rows) | " + " | ".join(
                f"{f(b, m)} / {f(b, m, 'auc_within')} / {f(b, m, 'brier')}" for m in ms) + " |")
    L.append("\nby day, pooled AUROC of m1d and m3 (random -> uncertain):")
    for lab in r["random"]["by_day"]:
        a, u = r["random"]["by_day"][lab], r["uncertain"]["by_day"].get(lab, {})
        if "pop" in a and "pop" in u:
            L.append(f"- day {lab}: m1d {f(a,'m1d_intercept_decay')} -> {f(u,'m1d_intercept_decay')}; "
                     f"m3 {f(a,'m3_hist')} -> {f(u,'m3_hist')}; pop {f(a,'pop')}; "
                     f"Brier m1d {f(a,'m1d_intercept_decay','brier')} -> {f(u,'m1d_intercept_decay','brier')}")
for name in ("arousal_past_r2", "arousal_full_r2"):
    r = json.loads((OUT / f"{name}.json").read_text())
    ms = ["pop", "m1_intercept", "m1d_intercept_decay", "m2_bayes", "m3_hist", "m4c_decay_on_hist", "m5t_hist_time"]
    for key in ("by_day_cohort29", "by_n_cohort29"):
        L.append(f"\n## {name} {key} (persons present >= 29 days): pooled AUROC / within / Brier\n")
        L.append("| bucket | rows | persons | " + " | ".join(ms) + " |")
        L.append("|---|---|---|" + "---|" * len(ms))
        for lab, b in r[key].items():
            if "pop" in b:
                L.append(f"| {lab} | {b['rows']} | {b['persons']} | " + " | ".join(
                    f"{f(b, m)}{'*' if m != 'pop' and b[m]['d_auc_ci'][0] > 0 else ''} / {f(b, m, 'auc_within')} / {f(b, m, 'brier')}" for m in ms) + " |")
(OUT / "extra.md").write_text("\n".join(L))
print("ok")
