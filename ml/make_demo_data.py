"""Synthetic data for the app's demo mode (TODO 1.15, FR12).

Writes two files to app/Harmony/Resources/demo/:
- demo_health.json: 14 days of watch data (heart rate, steps, HRV, sleep). Each sample is
  [start, end, value], times in seconds since midnight of the first day. The app puts the
  last day on today.
- demo_songs.json: 50 scored songs with invented titles, invented artists and fake IDs.

Everything comes from a fixed random seed: no real person, no real song, and running the
script again gives the same files. Standard library only (works on Mac and Windows).

    python ml/make_demo_data.py
"""

import argparse
import json
import math
import random
from pathlib import Path

SEED = 406
DAYS = 14
MINUTE, HOUR, DAY = 60, 3600, 86_400
UNKNOWN_NIGHT = 9  # the night ending on this day: watch not worn, so sleep is unknown (not zero)
RUN_DAYS = (3, 10)
OUT = Path(__file__).resolve().parent.parent / "app" / "Harmony" / "Resources" / "demo"

ARTISTS = ["Velvet Hours", "Mira Sol", "North Avenue", "Juno Park", "Kite Season",
           "Lumen Drive", "Ada Rivers", "Second Harbor", "Pale Orchard", "Neon Saplings"]
TITLE_WORDS = (["Golden", "Quiet", "Electric", "Slow", "Midnight",
                "Paper", "Bright", "Hollow", "Silver", "Summer"],
               ["Morning", "Rivers", "Signals", "Lights", "Hearts",
                "Streets", "Tides", "Echoes", "Gardens", "Wires"])
SOURCES = ["saved"] * 35 + ["top"] * 10 + ["recent"] * 5
ORIGINS = ["muse"] * 40 + ["llm"] * 8 + ["neutral"] * 2
ADDED_DAYS_AGO = {"saved": (1, 700), "top": (30, 400), "recent": (0, 13)}


def clock(day, hours):
    """Seconds since the first midnight at `hours` (decimal) on `day`."""
    return int(day * DAY + hours * HOUR)


def inside(t, intervals):
    return any(start <= t < end for start, end in intervals)


def split_night(rng, bed, wake):
    """A night as 3 or 4 asleep intervals separated by short awake gaps."""
    gaps = sorted(rng.uniform(bed + HOUR, wake - 30 * MINUTE) for _ in range(rng.choice((2, 3))))
    intervals, start = [], bed
    for gap in gaps:
        intervals.append((start, int(gap)))
        start = int(gap + rng.uniform(4, 12) * MINUTE)
    intervals.append((start, wake))
    return intervals


def make_health(rng):
    sleep, walks, runs, off = [], [], [], []
    wakes = [clock(d, 7 + rng.gauss(0, 0.4)) for d in range(DAYS)]
    for d, wake in enumerate(wakes):
        if d == UNKNOWN_NIGHT:
            off.append((clock(d - 1, 22), wake + 20 * MINUTE))
        else:
            bed = 0 if d == 0 else clock(d - 1, 23.5 + rng.gauss(0, 0.4))
            sleep += split_night(rng, bed, wake)
        morning = wake + int(rng.uniform(60, 80) * MINUTE)
        evening = clock(d, 18 + rng.gauss(0, 0.3))
        walks.append((morning, morning + int(rng.uniform(15, 25) * MINUTE)))
        walks.append((evening, evening + int(rng.uniform(15, 25) * MINUTE)))
        for _ in range(rng.randint(3, 6)):
            start = int(rng.uniform(wake + 2 * HOUR, clock(d, 21.5)))
            walks.append((start, start + int(rng.uniform(3, 8) * MINUTE)))
        if d in RUN_DAYS:
            runs.append((clock(d, 18.75), clock(d, 19.25)))
        charging = clock(d, 20 + rng.gauss(0, 0.15))
        off.append((charging, charging + int(rng.uniform(40, 50) * MINUTE)))

    # Heart rate: every 4-7 min while the watch is worn, every minute during a run (workout).
    day_offset = [rng.gauss(0, 2) for _ in range(DAYS)]
    heart_rate, t = [], rng.randint(0, 300)
    while t < DAYS * DAY:
        running = inside(t, runs)
        if not inside(t, off):
            if running:
                bpm = 148 + rng.gauss(0, 6)
            elif inside(t, walks):
                bpm = 100 + rng.gauss(0, 6)
            elif inside(t, sleep):
                bpm = 54 + rng.gauss(0, 2.5)
            else:  # awake at rest, highest around 16:00
                bpm = 66 + 5 * math.sin(2 * math.pi * ((t % DAY) / HOUR - 10) / 24) + rng.gauss(0, 4)
            heart_rate.append([t, t, round(bpm + day_offset[t // DAY])])
        t += MINUTE if running else rng.randint(240, 420)

    # Steps: one sample per 10 min with steps; none while asleep or without the watch.
    steps = []
    for start in range(0, DAYS * DAY, 10 * MINUTE):
        count = 0
        for t in range(start, start + 10 * MINUTE, MINUTE):
            if inside(t, off) or inside(t, sleep):
                continue
            if inside(t, runs):
                count += rng.randint(155, 175)
            elif inside(t, walks):
                count += rng.randint(95, 120)
            elif rng.random() < 0.15:
                count += rng.randint(5, 40)
        if count:
            steps.append([start, start + 10 * MINUTE, count])

    # HRV (SDNN): two readings in the night, three during the day, never while moving.
    hrv = []
    for d, wake in enumerate(wakes):
        day_times = sorted(rng.uniform(wake + HOUR, clock(d, 21)) for _ in range(3))
        for t in [clock(d, 2), clock(d, 4.5)] + [int(x) for x in day_times]:
            if inside(t, off) or inside(t, walks) or inside(t, runs):
                continue
            ms = rng.gauss(55, 8) if inside(t, sleep) else rng.gauss(40, 7)
            hrv.append([t, t, round(max(ms, 10), 1)])

    return {
        "heartRate": heart_rate,
        "steps": steps,
        "hrv": hrv,
        "sleep": [[start, end, 1] for start, end in sleep],
    }


def make_songs(rng):
    titles = rng.sample([f"{a} {b}" for a in TITLE_WORDS[0] for b in TITLE_WORDS[1]], 50)
    energies = [(i + rng.random()) / 50 for i in range(50)]  # spread over 0..1
    sources, origins = SOURCES[:], ORIGINS[:]
    for values in (energies, sources, origins):
        rng.shuffle(values)
    songs = []
    for i, (title, energy, source, origin) in enumerate(zip(titles, energies, sources, origins)):
        artists = [rng.choice(ARTISTS)]
        if rng.random() < 0.12:
            artists.append(rng.choice([a for a in ARTISTS if a != artists[0]]))
        positivity = min(max(0.3 + 0.4 * energy + rng.gauss(0, 0.15), 0.02), 0.98)
        if origin == "neutral":  # neither MuSe nor the LLM gave a score
            energy = positivity = 0.5
        songs.append({
            "spotifyId": f"demo{i + 1:02d}",
            "title": title,
            "artists": artists,
            "source": source,
            "addedDaysAgo": rng.randint(*ADDED_DAYS_AGO[source]),
            "energy": round(energy, 3),
            "positivity": round(positivity, 3),
            "origin": origin,
        })
    return songs


def write_json(path, comment, key_values):
    """One key per line (one song per line for the list of songs): readable and stable."""
    def dump(value):
        if isinstance(value, list) and value and isinstance(value[0], dict):
            return "[\n" + ",\n".join("    " + json.dumps(v) for v in value) + "\n  ]"
        return json.dumps(value, separators=(",", ":"))
    lines = [f'  "comment": {json.dumps(comment)}']
    lines += [f'  "{key}": {dump(value)}' for key, value in key_values.items()]
    path.write_text("{\n" + ",\n".join(lines) + "\n}\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT, help="output folder (default: %(default)s)")
    out = parser.parse_args().out
    out.mkdir(parents=True, exist_ok=True)

    rng = random.Random(SEED)
    health = make_health(rng)
    songs = make_songs(rng)
    write_json(out / "demo_health.json",
               f"Synthetic watch data from ml/make_demo_data.py (seed {SEED}), no real person. "
               f"Samples are [start, end, value], times in seconds since midnight of the first "
               f"of {DAYS} days. heartRate: bpm; steps: count; hrv: SDNN ms; sleep: asleep interval (value 1).",
               health)
    write_json(out / "demo_songs.json",
               f"Synthetic library from ml/make_demo_data.py (seed {SEED}): invented titles and "
               f"artists, fake Spotify IDs. energy and positivity are between 0 and 1.",
               {"songs": songs})

    for name, samples in health.items():
        print(f"{name}: {len(samples)} samples")
    print(f"songs: {len(songs)}")


if __name__ == "__main__":
    main()
