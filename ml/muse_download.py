"""Download MuSe from Zenodo and print its columns and value ranges (TODO 1.38).

MuSe, The Musical Sentiment Dataset: doi:10.5281/zenodo.4281165, CC BY 4.0.
Downloads every file of the Zenodo record into data/muse/ (ignored by Git), checks each MD5
against the one published by Zenodo, then prints aggregates of the CSV only: number of rows,
and for each column how many values are filled and their range (or the most common values).
Files already present with the right MD5 are not downloaded again. Standard library only.

    python ml/muse_download.py
"""

import argparse
import csv
import hashlib
import json
import statistics
import urllib.request
from collections import Counter
from pathlib import Path

RECORD = "https://zenodo.org/api/records/4281165"
OUT = Path(__file__).resolve().parent.parent / "data" / "muse"


def md5(path):
    digest = hashlib.md5()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def download(out):
    """Every file of the record, checked against Zenodo's MD5. Returns the local paths."""
    with urllib.request.urlopen(RECORD, timeout=60) as response:
        files = json.load(response)["files"]
    paths = []
    for file in files:
        path = out / file["key"]
        expected = file["checksum"].removeprefix("md5:")
        if not (path.exists() and md5(path) == expected):
            print(f"downloading {file['key']} ({file['size'] / 1e6:.1f} MB)")
            partial = path.with_name(path.name + ".part")
            urllib.request.urlretrieve(file["links"]["self"], partial)
            if md5(partial) != expected:
                partial.unlink()
                raise SystemExit(f"{file['key']}: MD5 does not match Zenodo, file deleted")
            partial.replace(path)
        print(f"{file['key']}: {path.stat().st_size} bytes, md5 {expected} OK (same as Zenodo)")
        paths.append(path)
    return paths


def floats(values):
    try:
        return [float(v) for v in values]
    except ValueError:
        return None


def summarise(path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    print(f"\n{path.name}: {len(rows)} rows, {len(rows[0])} columns")
    for column in rows[0]:
        values = [row[column] for row in rows if row[column].strip()]
        numbers = floats(values)
        head = f"  {column:<24} filled {len(values):>6} ({len(values) / len(rows):6.1%})"
        if values and numbers is not None:
            q1, median, q3 = statistics.quantiles(numbers, n=4)
            print(f"{head}  numeric  min {min(numbers):.3f}  q1 {q1:.3f}  median {median:.3f}"
                  f"  q3 {q3:.3f}  max {max(numbers):.3f}  mean {statistics.fmean(numbers):.3f}")
        else:
            counts = Counter(values)
            line = f"{head}  text     distinct {len(counts)}"
            if len(counts) <= 1000:  # categories (e.g. genre): show the most common ones
                line += "  most common: " + ", ".join(f"{v} ({n})" for v, n in counts.most_common(5))
            print(line)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=OUT, help="download folder (default: %(default)s)")
    out = parser.parse_args().out
    out.mkdir(parents=True, exist_ok=True)
    for path in download(out):
        if path.suffix == ".csv":
            summarise(path)


if __name__ == "__main__":
    main()
