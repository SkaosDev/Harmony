# ml/

Python code for the state model and the song scores.

| File | What it does |
|---|---|
| `explore_d1.py` | Reproduces Table VII of Submission B (first results on EmoPhone wave D-1). Checked on Nov. 5, 2026 with scikit-learn 1.5.2: same numbers as the report. |
| `features.py` | Features v1 of the state model (TODO 2.1–2.6): pure functions, fixed order `FEATURES`, the single source of truth (definitions: `docs/PROJECT.md` §6, "Features v1"). Tests: `ml/tests/test_features.py` (synthetic series only). |
| `build_features.py` | Builds one local v1 table per wave (TODO 2.7): `python ml/build_features.py --data data/emophone --out data/features` → `data/features/v1_D1.csv`… (ignored by Git). Prints aggregates only; `--check-v0` compares the nights with `explore_d1.py` (TODO 2.5). |
| `train.py` | Trains and evaluates the state model on the v1 tables (TODO 2.8–2.11): `python ml/train.py --features data/features`; 5 folds by participant on D-1 + D-2, imputation and scaling fitted inside each training fold (sklearn Pipeline). Prints aggregates only. Tests: `ml/tests/test_train.py` (synthetic tables). |
| `explore_waves.py` | Compares aggregate ESM and sensor structure across EmoPhone waves D-1, D-2 and D-3 (TODO 1.35): `python ml/explore_waves.py --data data/emophone`. |
| `make_demo_data.py` | Writes the app's synthetic demo data (`app/Harmony/Resources/demo/`): 14 days of watch data and 50 scored songs, from a fixed seed (no real person, no real song). Standard library only: `python ml/make_demo_data.py`. |
| `muse_download.py` | Downloads MuSe v3 (`muse_v3.csv`, Kaggle, CC BY 4.0) into `data/muse/`, checks its size against Kaggle and its SHA-256 against the recorded one (same file for everyone), then prints the columns and value ranges (aggregates only). Standard library only: `python ml/muse_download.py`. Results and decisions: `docs/PROJECT.md` §5.2. |
| `normalize.py` | Normalizes song titles and artists for MuSe lookup (TODO 1.40); shared cases: `ml/fixtures/normalize_cases.json`. |
| `muse_build.py` | Rebuilds the ignored local SQLite file (TODO 1.39): run `python ml/muse_download.py`, then `python ml/muse_build.py`; no database file is stored in Git. |
| `requirements.txt` | Python dependencies. |

Run:

```sh
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r ml/requirements.txt
python ml/explore_d1.py --data /path/to/dataverse_files/D1
python -m unittest ml.tests.test_features ml.tests.test_normalize ml.tests.test_train -v
python ml/build_features.py --data data/emophone --out data/features
python ml/train.py --features data/features
```

The EmoPhone files stay outside the repository (`data/` is ignored by Git). Never commit them,
never paste them into a chat, never ship them in the app (NFR9).
