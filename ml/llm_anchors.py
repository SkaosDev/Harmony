"""Reference songs for the LLM prompt (TODO 2.30, trial 3).

Usage: python ml/llm_anchors.py [--db data/muse/muse.sqlite] [--csv data/muse/muse_v3.csv]
Prints the block of reference songs written in ml/prompts/score.txt: in each cell of a 4 x 4
grid of energy x positivity quartiles, 3 MuSe songs with at least 10 emotion tags (a reliable
reference), drawn with a fixed seed, with distinct genres within a cell and distinct artists
overall. One line per song: title<TAB>artists<TAB>energy<TAB>positivity, scores as integers
0-100 (MuSe percentiles). MuSe: Akiki & Burghardt 2021, doi:10.5334/johd.33, CC BY 4.0.
"""

import argparse
import sqlite3
from pathlib import Path

import pandas as pd

from llm_check import _clean
from normalize import match_key

ROOT = Path(__file__).resolve().parents[1]
MIN_TAGS, PER_CELL, SEED = 10, 3, 0
EDGES = [0, 0.25, 0.5, 0.75, 1]


def muse_with_tags(db: Path, csv: Path) -> pd.DataFrame:
    """The songs of muse.sqlite with their number of emotion tags (kept row = most tags)."""
    raw = pd.read_csv(csv, usecols=["track", "artist", "number_of_emotion_tags"])
    raw["match_key"] = [match_key(t, a) for t, a in zip(raw["track"], raw["artist"])]
    tags = raw.groupby("match_key")["number_of_emotion_tags"].max()
    with sqlite3.connect(db) as con:
        songs = pd.read_sql("SELECT match_key, title, artists, genre, energy, positivity "
                            "FROM songs ORDER BY match_key", con)
    songs["tags"] = songs["match_key"].map(tags)
    return songs


def select_anchors(songs: pd.DataFrame) -> pd.DataFrame:
    """PER_CELL well-tagged songs per grid cell, sorted by energy then positivity."""
    pool = songs[songs["tags"] >= MIN_TAGS].sort_values("match_key")
    pool = pool.assign(cell_e=pd.cut(pool["energy"], EDGES, labels=False, include_lowest=True),
                       cell_p=pd.cut(pool["positivity"], EDGES, labels=False, include_lowest=True))
    pool = pool.sample(frac=1, random_state=SEED)
    chosen, artists = [], set()
    for cell, rows in pool.groupby(["cell_e", "cell_p"]):
        genres = set()
        for row in rows.itertuples():
            artist = row.match_key.split("\t")[1]
            if artist in artists or row.genre in genres:
                continue
            chosen.append(row.Index)
            artists.add(artist)
            genres.add(row.genre)
            if len(genres) == PER_CELL:
                break
        if len(genres) < PER_CELL:
            raise ValueError(f"cell {cell}: only {len(genres)} reference songs")
    return pool.loc[chosen].sort_values(["energy", "positivity"]).reset_index(drop=True)


def anchor_block(anchors: pd.DataFrame) -> str:
    return "\n".join(f"{_clean(row.title)}\t{_clean(row.artists)}\t"
                     f"{round(row.energy * 100)}\t{round(row.positivity * 100)}"
                     for row in anchors.itertuples())


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--db", type=Path, default=ROOT / "data" / "muse" / "muse.sqlite")
    parser.add_argument("--csv", type=Path, default=ROOT / "data" / "muse" / "muse_v3.csv")
    args = parser.parse_args()
    print(anchor_block(select_anchors(muse_with_tags(args.db, args.csv))))


if __name__ == "__main__":
    main()
