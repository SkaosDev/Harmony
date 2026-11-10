"""Download MuSe v3 from Kaggle and print its columns and value ranges (TODO 1.38).

MuSe, The Musical Sentiment Dataset (Akiki & Burghardt 2021, doi:10.5334/johd.33), CC BY 4.0.
We use version 3 of the data, published by the authors on Kaggle
(cakiki/muse-the-musical-sentiment-dataset, dataset version 5, file muse_v3.csv): unlike the
Zenodo version (doi:10.5281/zenodo.4281165), it has a genre column. See docs/PROJECT.md §5.2.

Downloads muse_v3.csv into data/muse/ (ignored by Git), checks its size against Kaggle and its
SHA-256 against the value recorded below (so every team member gets the same file), then
prints aggregates of the CSV only: number of rows, and for each column how many values are
filled and their range (or the most common values). A correct file already present is not
downloaded again. Standard library only.

    python ml/muse_download.py
"""

import argparse
import csv
import hashlib
import io
import statistics
import urllib.request
import zipfile
from collections import Counter
from pathlib import Path

URL = ("https://www.kaggle.com/api/v1/datasets/download/"
       "cakiki/muse-the-musical-sentiment-dataset?datasetVersionNumber=5")
FILE = "muse_v3.csv"
SIZE = 18_200_150  # bytes, as listed by Kaggle
SHA256 = "9fdba18b43c2b05187a4136bc0c0996c2cf41a3e5d55b27015131fafd410aa07"  # Nov. 10, 2026
OUT = Path(__file__).resolve().parent.parent / "data" / "muse"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def download(out):
    """muse_v3.csv in `out`, checked. Returns its path."""
    path = out / FILE
    if not (path.exists() and path.stat().st_size == SIZE):
        print(f"downloading {FILE} from Kaggle ({SIZE / 1e6:.1f} MB)")
        request = urllib.request.Request(URL, headers={"User-Agent": "harmony-ml-script"})
        with urllib.request.urlopen(request, timeout=120) as response:
            archive = zipfile.ZipFile(io.BytesIO(response.read()))
        path.write_bytes(archive.read(FILE))
    data = path.read_bytes()
    if len(data) != SIZE:
        raise SystemExit(f"{FILE}: {len(data)} bytes, Kaggle lists {SIZE}")
    digest = sha256(data)
    if SHA256 is not None and digest != SHA256:
        raise SystemExit(f"{FILE}: SHA-256 {digest} differs from the recorded {SHA256}")
    print(f"{FILE}: {len(data)} bytes (same as Kaggle), sha256 {digest}"
          + (" OK (same as recorded)" if SHA256 else " (not recorded yet)"))
    return path


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
    summarise(download(out))


if __name__ == "__main__":
    main()
