"""Build a compact local MuSe SQLite table (TODO 1.39).

Usage: python ml/muse_build.py [--csv data/muse/muse_v3.csv] [--out data/muse/muse.sqlite]

Percentile scores are ranked over all 90,001 source rows before filtering. Duplicate
Spotify IDs are cleared on every affected row. Duplicate title/artist keys keep the
row with the most emotion tags, ties keep the earliest source row. Empty keys are
counted and excluded because they cannot support title/artist lookup.
"""

import argparse
import sqlite3
from pathlib import Path

import pandas as pd

from normalize import match_key

EXPECTED_ROWS = 90_001
ROOT = Path(__file__).resolve().parent.parent


def build(csv_path: Path, out_path: Path):
    frame = pd.read_csv(csv_path, encoding="utf-8")
    if len(frame) != EXPECTED_ROWS:
        raise ValueError(f"expected {EXPECTED_ROWS} rows, found {len(frame)}")

    frame["energy"] = frame["arousal_tags"].rank(pct=True)
    frame["positivity"] = frame["valence_tags"].rank(pct=True)

    spotify = frame["spotify_id"].fillna("").astype(str).str.strip()
    duplicate_ids = spotify.ne("") & spotify.duplicated(keep=False)
    duplicate_id_count = spotify[duplicate_ids].nunique()
    duplicate_id_rows = int(duplicate_ids.sum())
    frame.loc[duplicate_ids, "spotify_id"] = ""
    frame["spotify_id"] = frame["spotify_id"].fillna("").astype(str).str.strip()
    frame["genre"] = frame["genre"].fillna("").astype(str)
    frame["match_key"] = [match_key(title, artist)
                          for title, artist in zip(frame["track"], frame["artist"])]

    empty_key = frame["match_key"].str.replace("\t", "", regex=False).str.strip().eq("")
    empty_key_rows = int(empty_key.sum())
    candidates = frame.loc[~empty_key].copy()
    counts = candidates["match_key"].value_counts()
    duplicate_keys = counts[counts > 1]
    duplicate_key_count = len(duplicate_keys)
    duplicate_key_rows = int(duplicate_keys.sum())
    ranked = candidates.sort_values("number_of_emotion_tags", ascending=False, kind="stable")
    kept = ranked.drop_duplicates("match_key", keep="first").sort_index()

    columns = ["spotify_id", "track", "artist", "genre", "energy", "positivity", "match_key"]
    songs = kept[columns].rename(columns={"track": "title", "artist": "artists"})
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()
    with sqlite3.connect(out_path) as db:
        db.execute("PRAGMA page_size = 16384")
        db.execute("""CREATE TABLE songs (
            spotify_id TEXT NOT NULL,
            title TEXT NOT NULL,
            artists TEXT NOT NULL,
            genre TEXT NOT NULL,
            energy REAL NOT NULL,
            positivity REAL NOT NULL,
            match_key TEXT PRIMARY KEY
        ) WITHOUT ROWID""")
        db.executemany(
            "INSERT INTO songs VALUES (?, ?, ?, ?, ?, ?, ?)",
            songs.itertuples(index=False, name=None),
        )
        db.execute("CREATE INDEX songs_spotify_id ON songs (spotify_id)")
        db.commit()
        db.execute("VACUUM")

    print(f"rows read: {len(frame)}")
    print(f"duplicate Spotify IDs: {duplicate_id_count} IDs, {duplicate_id_rows} rows cleared")
    print(f"duplicate match keys: {duplicate_key_count} keys, {duplicate_key_rows} rows; {duplicate_key_rows - duplicate_key_count} rows removed")
    print(f"empty match keys: {empty_key_rows} rows excluded")
    print(f"rows kept: {len(songs)}")
    print(f"rows with Spotify ID: {(songs['spotify_id'] != '').sum()}")
    print(f"rows with genre: {(songs['genre'] != '').sum()}")
    for col in ("energy", "positivity"):
        values = songs[col]
        print(f"{col}: min={values.min():.6f}, median={values.median():.6f}, max={values.max():.6f}")
    print(f"output: {out_path} ({out_path.stat().st_size} bytes)")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--csv", type=Path, default=ROOT / "data" / "muse" / "muse_v3.csv")
    parser.add_argument("--out", type=Path, default=ROOT / "data" / "muse" / "muse.sqlite")
    args = parser.parse_args()
    build(args.csv, args.out)


if __name__ == "__main__":
    main()
