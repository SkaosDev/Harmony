"""Charts of the report, the blog and the README (aggregate results only, no participant data).

Every number below is an aggregate already written in the repo; its source is noted next to it.
The made-up user of `example` runs through the real personal layer (`ml/personal_layer.py`, the
code the Swift golden fixtures come from). When `data/results/wp-b0.json` is present (aggregates
of `ml/simulate_wp_b0.py`), the simulation numbers are checked against it first.

    python ml/make_figures.py            # writes docs/figures/<name>.pdf and .svg
"""
from __future__ import annotations

import json
import math
from datetime import datetime, timedelta
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

import personal_layer as pl  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "figures"
WP_B0 = ROOT / "data" / "results" / "wp-b0.json"

# Colours (dataviz reference palette): grey = the shared model, blue = ours / the personal layer.
INK, INK2, GRID = "#191919", "#666666", "#e3e3e3"
SHARED = "#8a8a8a"
OURS = "#2370cd"
BLUES = {1: "#519ced", 2: "#2370cd", 4: "#0f4a96"}   # answers per day, light to dark
COL = 3.45      # IEEE column width (in)
FULL = 7.1      # IEEE text width (in)

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Times New Roman", "Times", "STIXGeneral", "DejaVu Serif"],
    "mathtext.fontset": "stix",
    "font.size": 7.5,
    "axes.titlesize": 8,
    "axes.labelsize": 7.5,
    "axes.edgecolor": INK2,
    "axes.labelcolor": INK,
    "axes.linewidth": 0.6,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "xtick.color": INK2,
    "ytick.color": INK2,
    "xtick.labelcolor": INK,
    "ytick.labelcolor": INK,
    "xtick.major.width": 0.6,
    "ytick.major.width": 0.6,
    "legend.frameon": False,
    "legend.fontsize": 7,
    "pdf.fonttype": 42,
    "svg.fonttype": "none",
    "svg.hashsalt": "harmony",
})

# --- Numbers -----------------------------------------------------------------------------------

# State model, first results on EmoPhone wave 1 (docs/main.tex Table VII, PROJECT.md:638-648).
WAVE1 = [  # (label, AUROC, kind)
    ("Time of day only", 0.532, "base"),
    ("Time + sleep", 0.526, "base"),
    ("Time + heart rate", 0.577, "base"),
    ("Time + heart rate + steps", 0.577, "base"),
    ("Time + heart rate + steps + sleep (ours)", 0.573, "ours"),
    ("Same inputs, gradient-boosted trees", 0.558, "alt"),
    ("Time + heart rate, 1 reading / 5 min", 0.575, "alt"),
    ("Our model, predicting stress", 0.543, "alt"),
    ("Other participants at the same time", 0.530, "alt"),
]
PUBLISHED_BEST = 0.576   # best published result on this wave [emophone]

# Final evaluation, people kept apart (docs/main.tex Table X, PROJECT.md:686-704, 803-807).
FINAL = [  # (label, CV mean, CV sd, wave 3 held out)
    ("Time of day only", 0.534, 0.014, 0.534),
    ("Time + heart rate", 0.554, 0.012, 0.570),
    ("Time + HR + steps + sleep (13)", 0.563, 0.008, 0.576),
    ("+ raw HR and steps (17, final)", 0.572, 0.018, 0.597),
]

# Personal layer, exact app rule simulated on EmoPhone (WP-B0, PROJECT.md:929-941,
# data/results/wp-b0.json). Pooled AUROC by days of use; None = no labelled answer yet.
DAY_BINS = ["1–3", "4–7", "8–14", "15+"]
SHARED_2 = [0.511, 0.534, 0.516, 0.507]                  # energy_3_2 "common"
PERSONAL = {1: [None, 0.637, 0.760, 0.769],              # energy_3_1 "personal"
            2: [0.511, 0.736, 0.820, 0.810],             # energy_3_2
            4: [0.694, 0.784, 0.831, 0.833]}             # energy_3_4
# Whole period, 2 answers a day: (label, shared, personal, series).
WHOLE = [
    ("App question\n(3 levels)", 0.514, 0.797, "energy_3_2"),
    ("7-step\nanswer", 0.544, 0.657, "energy_7_2"),
    ("Clock-only\nshared model", 0.513, 0.797, "energy_time_control_2"),
]

# If the user stops answering: research simulation, earlier model, 7-step answers, 2 a day
# (docs/research/2026-11-23-modele-etat-v2/resultats/perso/extra.md:6-10, m1d_now vs pop).
STOP_DAYS = [0, 1, 2, 4, 7]
STOP_PERSONAL = [0.693, 0.667, 0.639, 0.590, 0.554]
STOP_SHARED = 0.546

# App performance on the iPhone 16 (docs/main.tex section VII-D).
LATENCY = [  # (label, low, typical, high) in seconds
    ("One state estimate", 0.13, 0.14, 0.15),
    ("Queue on screen (median of 12)", 0.28, 0.34, 0.37),
    ("Queue with a fresh estimate", 0.54, 0.54, 0.54),
]
NFR3 = 2.0


def check_against_simulation() -> None:
    """Fail loudly if a constant above differs from the stored simulation aggregates."""
    if not WP_B0.exists():
        print(f"(skipped the check: {WP_B0.relative_to(ROOT)} is not here)")
        return
    series = json.loads(WP_B0.read_text())["series"]
    bins = ["1–3", "4–7", "8–14", "15+"]

    def same(value, cell, key, where):
        if value is None:
            if cell["n"] != 0:
                raise SystemExit(f"{where}: no value in the script, n = {cell['n']} in {WP_B0.name}")
        elif round(cell[key], 3) != value:
            raise SystemExit(f"{where}: {value} in the script, {cell[key]:.4f} in {WP_B0.name}")

    for i, b in enumerate(bins):
        same(SHARED_2[i], series["energy_3_2"][b], "common", f"energy_3_2 {b}")
        for per_day, values in PERSONAL.items():
            same(values[i], series[f"energy_3_{per_day}"][b], "personal", f"energy_3_{per_day} {b}")
    for _, shared, personal, name in WHOLE:
        same(shared, series[name]["all"], "common", f"{name} all")
        same(personal, series[name]["all"], "personal", f"{name} all")
    print(f"constants match {WP_B0.relative_to(ROOT)}")


# --- Helpers -----------------------------------------------------------------------------------

def save(fig, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / f"{name}.pdf", bbox_inches="tight", pad_inches=0.02, metadata={"CreationDate": None})
    fig.savefig(OUT / f"{name}.svg", bbox_inches="tight", pad_inches=0.02, metadata={"Date": None})
    plt.close(fig)
    print(f"wrote docs/figures/{name}.pdf and .svg")


def chance_line(ax, horizontal: bool = True, label: str = "chance") -> None:
    draw = ax.axhline if horizontal else ax.axvline
    draw(0.5, color=INK2, lw=0.7, ls=(0, (1.5, 2)), zorder=0)
    if horizontal and label:
        ax.annotate(label, (1, 0.5), xycoords=("axes fraction", "data"), xytext=(0, 2),
                    textcoords="offset points", ha="right", va="bottom", color=INK2, fontsize=6.5)


def light_grid(ax, axis: str = "y") -> None:
    ax.grid(axis=axis, color=GRID, lw=0.5)
    ax.set_axisbelow(True)


# --- Figures -----------------------------------------------------------------------------------

def wave1_inputs() -> None:
    """Dot plot: which inputs and which models carry the signal on wave 1."""
    fig, ax = plt.subplots(figsize=(COL, 2.15))
    rows = list(reversed(WAVE1))
    for y, (label, auc, kind) in enumerate(rows):
        colour = OURS if kind == "ours" else SHARED
        ax.plot([0.5, auc], [y, y], color=colour, lw=1.2 if kind == "ours" else 0.8, solid_capstyle="round")
        ax.plot(auc, y, "o", ms=5 if kind == "ours" else 4, color=colour, mec="white", mew=0.8, zorder=3)
        ax.annotate(f"{auc:.3f}", (auc, y), xytext=(5, 0), textcoords="offset points", va="center",
                    fontsize=6.5, color=INK, fontweight="bold" if kind == "ours" else "normal")
    ax.set_yticks(range(len(rows)), [r[0] for r in rows])
    for tick, row in zip(ax.get_yticklabels(), rows):
        if row[2] == "ours":
            tick.set_fontweight("bold")
    ax.axvline(PUBLISHED_BEST, color=INK2, lw=0.7, ls="--", zorder=0)
    ax.annotate("best published\n(thousands of inputs)", (PUBLISHED_BEST, len(rows) - 0.4), xytext=(3, 0),
                textcoords="offset points", fontsize=6, color=INK2, va="top")
    ax.axvline(0.5, color=INK2, lw=0.7, ls=(0, (1.5, 2)), zorder=0)
    ax.set_xlim(0.495, 0.612)
    ax.set_ylim(-0.6, len(rows) - 0.4)
    ax.set_xlabel("AUROC on people kept apart (0.5 = chance)")
    ax.tick_params(axis="y", length=0)
    ax.spines["left"].set_visible(False)
    light_grid(ax, "x")
    save(fig, "wave1-inputs")


def final_eval() -> None:
    """Dot plot with error bars: the final model in cross-validation and on a held-out wave."""
    fig, ax = plt.subplots(figsize=(COL, 1.75))
    rows = list(reversed(FINAL))
    for y, (label, cv, sd, held) in enumerate(rows):
        final = y == 0
        ax.errorbar(cv, y + 0.13, xerr=sd, fmt="o", ms=4, color=SHARED, ecolor=SHARED, elinewidth=0.8,
                    capsize=2, mec="white", mew=0.6, zorder=3, label="Waves 1+2, 5 folds (± s.d.)" if final else None)
        ax.plot(held, y - 0.13, "D", ms=4.2, color=OURS, mec="white", mew=0.6, zorder=3,
                label="Wave 3, held out, tested once" if final else None)
        ax.annotate(f"{held:.3f}", (held, y - 0.13), xytext=(5, 0), textcoords="offset points", va="center",
                    fontsize=6.5, color=INK, fontweight="bold" if final else "normal")
        ax.annotate(f"{cv:.3f}", (cv - sd, y + 0.13), xytext=(-4, 0), textcoords="offset points", va="center",
                    ha="right", fontsize=6.5, color=INK2)
    ax.set_yticks(range(len(rows)), [r[0] for r in rows])
    ax.get_yticklabels()[0].set_fontweight("bold")
    ax.axvline(0.5, color=INK2, lw=0.7, ls=(0, (1.5, 2)), zorder=0)
    ax.set_xlim(0.495, 0.625)
    ax.set_ylim(-0.6, len(rows) - 0.3)
    ax.set_xlabel("AUROC on people kept apart (0.5 = chance)")
    ax.tick_params(axis="y", length=0)
    ax.spines["left"].set_visible(False)
    light_grid(ax, "x")
    ax.legend(loc="lower right", bbox_to_anchor=(1.0, 1.0), ncol=2, handletextpad=0.3, columnspacing=1.0,
              borderaxespad=0.2)
    save(fig, "eval")


def learning() -> None:
    """The headline: the personal layer against the shared model, by days of use."""
    fig, (ax, bx) = plt.subplots(1, 2, figsize=(FULL, 2.25), gridspec_kw={"width_ratios": [1.35, 1]})
    x = range(len(DAY_BINS))

    ax.plot(x, SHARED_2, "s-", color=SHARED, lw=1.4, ms=4, mec="white", mew=0.6)
    ax.annotate("Shared watch model", (3, SHARED_2[3]), xytext=(6, 0), textcoords="offset points",
                va="center", color=INK, fontsize=7)
    labels = {1: "1 answer a day", 2: "2 answers a day (app)", 4: "4 answers a day"}
    for per_day in (1, 2, 4):
        pts = [(i, v) for i, v in enumerate(PERSONAL[per_day]) if v is not None]
        xs, ys = zip(*pts)
        main = per_day == 2
        ax.plot(xs, ys, "o-", color=BLUES[per_day], lw=2.0 if main else 1.0, ms=5 if main else 3.5,
                mec="white", mew=0.7, zorder=3 if main else 2)
        ax.annotate(labels[per_day], (3, ys[-1]), xytext=(6, {1: -4, 2: 0, 4: 5}[per_day]),
                    textcoords="offset points", va="center", color=INK, fontsize=7,
                    fontweight="bold" if main else "normal")
    for i, offset in ((1, (7, -7)), (2, (0, -12))):
        ax.annotate(f"{PERSONAL[2][i]:.2f}", (i, PERSONAL[2][i]), xytext=offset, textcoords="offset points",
                    ha="left" if i == 1 else "center", fontsize=6.5, color=INK, fontweight="bold")
    ax.annotate(f"{SHARED_2[1]:.2f}", (1, SHARED_2[1]), xytext=(0, 5), textcoords="offset points",
                ha="center", fontsize=6.5, color=INK2)
    chance_line(ax, label="")
    ax.annotate("chance", (0, 0.5), xytext=(0, -9), textcoords="offset points", ha="center", fontsize=6.5,
                color=INK2)
    ax.set_xticks(list(x), DAY_BINS)
    ax.set_xlim(-0.25, 4.6)
    ax.set_ylim(0.45, 0.88)
    ax.set_xlabel("Days of use")
    ax.set_ylabel("AUROC (0.5 = chance)")
    ax.set_title("(a) The estimate learns the person within days", loc="left", color=INK)
    light_grid(ax)
    ax.spines["bottom"].set_bounds(0, 3)

    for i, (label, shared, personal, _) in enumerate(WHOLE):
        bx.plot([i, i], [shared, personal], color=GRID, lw=3, solid_capstyle="round", zorder=1)
        bx.plot(i, shared, "s", ms=5, color=SHARED, mec="white", mew=0.6, zorder=3)
        bx.plot(i, personal, "o", ms=6, color=OURS, mec="white", mew=0.7, zorder=3)
        bx.annotate(f"{personal:.3f}", (i, personal), xytext=(0, 6), textcoords="offset points", ha="center",
                    fontsize=6.5, color=INK, fontweight="bold")
        bx.annotate(f"{shared:.3f}", (i, shared), xytext=(0, -10), textcoords="offset points", ha="center",
                    fontsize=6.5, color=INK2)
    bx.plot([], [], "s", color=SHARED, ms=5, label="Shared model alone")
    bx.plot([], [], "o", color=OURS, ms=6, label="With the personal layer")
    chance_line(bx)
    bx.set_xticks(range(len(WHOLE)), [w[0] for w in WHOLE])
    bx.set_xlim(-0.5, len(WHOLE) - 0.5)
    bx.set_ylim(0.45, 0.88)
    bx.set_title("(b) Whole period, 2 answers a day", loc="left", color=INK)
    bx.legend(loc="upper center", bbox_to_anchor=(0.5, 1.0), handletextpad=0.2, borderaxespad=0.1)
    light_grid(bx)
    bx.tick_params(axis="x", length=0)
    fig.tight_layout(w_pad=2.0)
    save(fig, "learning")


def example() -> None:
    """A made-up user through the real personal layer: what the phone estimates, day after day."""
    start = datetime(2026, 1, 5)
    # Energy answers (−2 Low, 0 Medium, +2 High), two a day; None = no answer that day.
    plan = [(0, -2), (2, 0), (0, 2), (-2, 0), (0, -2), (2, 0),        # mixed: the layer hesitates
            (2, 2), (0, 2), (2, 2), (2, 0), (2, 2),                     # more Highs than usual
            None, None, None, None, None,                               # no answers for 5 days
            (-2, 0), (0, -2), (-2, -2), (0, -2), (-2, 0)]               # more Lows than usual
    days = len(plan)

    def z_common(t: datetime) -> float:
        # A made-up shared model: a small swing over the day, as the real one gives (p ≈ 0.4–0.6).
        hour = t.hour + t.minute / 60
        return 0.3 * math.sin(2 * math.pi * (hour - 9) / 24) + 0.1 * math.sin(1.7 * (t - start).days)

    observations: list[pl.Observation] = []
    answers = []   # (time, energy, label)
    for d, pair in enumerate(plan):
        if pair is None:
            continue
        for k, energy in enumerate(pair):
            t = start + timedelta(days=d, hours=(11.2 if k == 0 else 17.4) + 0.3 * math.sin(3 * d + k))
            label = pl.past_label(t, energy, observations)
            observations.append(pl.Observation(t, energy, z_common(t), label))
            answers.append((t, energy, label))

    grid_t, shared_p, personal_p = [], [], []
    for d in range(days):
        for half_hour in range(16, 47):              # 08:00 to 23:00
            t = start + timedelta(days=d, minutes=30 * half_hour)
            z = z_common(t)
            _, p, _ = pl.estimate(t, z, observations)
            grid_t.append(d + half_hour / 48 + 1)
            shared_p.append(pl.sigmoid(z))
            personal_p.append(p)
        grid_t.append(float("nan"))
        shared_p.append(float("nan"))
        personal_p.append(float("nan"))

    fig, (ax, sx) = plt.subplots(2, 1, figsize=(COL, 2.45), sharex=True,
                                 gridspec_kw={"height_ratios": [3.4, 1], "hspace": 0.12})
    ax.axvspan(12, 17, color="#f3f3f3", lw=0, zorder=0)
    ax.annotate("no answers: drifts\nback to the shared\nmodel", (14.5, 0.98), ha="center", va="top",
                fontsize=6.3, color=INK2)
    ax.plot(grid_t, shared_p, color=SHARED, lw=1.0, label="Shared watch model")
    ax.plot(grid_t, personal_p, color=OURS, lw=1.6, label="Personal estimate")
    ax.axhline(0.5, color=INK2, lw=0.6, ls=(0, (1.5, 2)), zorder=0)
    ax.set_ylim(0.0, 1.0)
    ax.set_yticks([0, 0.5, 1])
    ax.set_ylabel("Chance of 'above\nyour usual'")
    ax.annotate("learns: more\nHighs than usual", (9.5, 0.98), ha="center", va="top", fontsize=6.3, color=INK)
    ax.annotate("learns: more\nLows than usual", (19.5, 0.98), ha="center", va="top", fontsize=6.3, color=INK)
    ax.legend(loc="lower left", ncol=2, handlelength=1.4, borderaxespad=0.1, columnspacing=1.0)
    light_grid(ax)

    sx.axvspan(12, 17, color="#f3f3f3", lw=0, zorder=0)
    for t, energy, label in answers:
        x_pos = (t - start).total_seconds() / 86_400 + 1
        if label is None:
            sx.plot(x_pos, energy, "o", ms=3.2, mfc="white", mec=INK2, mew=0.7)
        else:
            sx.plot(x_pos, energy, "^" if label else "v", ms=3.8, color=OURS if label else INK, mec="white",
                    mew=0.4)
    sx.set_ylim(-3, 3)
    sx.set_yticks([-2, 0, 2], ["Low", "Med", "High"])
    sx.set_ylabel("Answer")
    sx.set_xlim(1, days + 1)
    sx.set_xticks(range(1, days + 1, 2))
    sx.set_xlabel("Day of use (made-up user, 2 questions a day)")
    sx.plot([], [], "^", color=OURS, ms=3.8, label="above usual")
    sx.plot([], [], "v", color=INK, ms=3.8, label="below")
    sx.plot([], [], "o", mfc="white", mec=INK2, ms=3.2, label="first 5: no label yet")
    sx.legend(loc="upper center", bbox_to_anchor=(0.5, -0.95), ncol=3, handletextpad=0.1, columnspacing=0.8,
              fontsize=6.3)
    light_grid(sx)
    save(fig, "example")


def latency() -> None:
    """Horizontal bars from zero: the app is far under its 2 s budget."""
    fig, ax = plt.subplots(figsize=(COL, 1.25))
    rows = list(reversed(LATENCY))
    for y, (label, low, typical, high) in enumerate(rows):
        ax.barh(y, typical, height=0.5, color=OURS, zorder=2)
        if high > low:
            ax.errorbar(typical, y, xerr=[[typical - low], [high - typical]], fmt="none", ecolor=INK,
                        elinewidth=0.7, capsize=2, zorder=3)
        ax.annotate(f"{typical:.2f} s", (high, y), xytext=(4, 0), textcoords="offset points", va="center",
                    fontsize=6.5, color=INK)
    ax.axvline(NFR3, color=INK, lw=0.8, ls="--")
    ax.annotate("limit (NFR3): 2 s", (NFR3, len(rows) - 0.45), xytext=(-3, 0), textcoords="offset points",
                ha="right", va="top", fontsize=6.5, color=INK)
    ax.set_yticks(range(len(rows)), [r[0] for r in rows])
    ax.set_xlim(0, 2.1)
    ax.set_ylim(-0.5, len(rows) - 0.4)
    ax.set_xlabel("Seconds after the tap (iPhone 16)")
    ax.tick_params(axis="y", length=0)
    ax.spines["left"].set_visible(False)
    light_grid(ax, "x")
    save(fig, "latency")


def stop() -> None:
    """If the user stops answering, the estimate falls back to the shared model, never below."""
    fig, ax = plt.subplots(figsize=(COL, 1.7))
    ax.plot(STOP_DAYS, STOP_PERSONAL, "o-", color=OURS, lw=1.6, ms=4.5, mec="white", mew=0.6,
            label="Personal estimate")
    ax.axhline(STOP_SHARED, color=SHARED, lw=1.2, label="Shared model")
    for d, v in zip(STOP_DAYS, STOP_PERSONAL):
        ax.annotate(f"{v:.3f}", (d, v), xytext=(0, 5), textcoords="offset points", ha="center", fontsize=6.5,
                    color=INK)
    chance_line(ax)
    ax.set_xticks(STOP_DAYS)
    ax.set_ylim(0.48, 0.72)
    ax.set_xlabel("Days since the last answer")
    ax.set_ylabel("AUROC")
    ax.legend(loc="upper right")
    light_grid(ax)
    save(fig, "stop")


if __name__ == "__main__":
    check_against_simulation()
    wave1_inputs()
    final_eval()
    learning()
    example()
    latency()
    stop()
