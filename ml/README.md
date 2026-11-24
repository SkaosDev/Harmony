# ml/

Python code for the state model and the song scores.

| File | What it does |
|---|---|
| `explore_d1.py` | Reproduces Table VII of Submission B (first results on EmoPhone wave D-1). Checked on Nov. 5, 2026 with scikit-learn 1.5.2: same numbers as the report. |
| `features.py` | Features v1 of the state model (TODO 2.1–2.6): pure functions, fixed order `FEATURES`, the single source of truth (definitions: `docs/PROJECT.md` §6, "Features v1"). Tests: `ml/tests/test_features.py` (synthetic series only). |
| `build_features.py` | Builds one local v1 table per wave (TODO 2.7): `python ml/build_features.py --data data/emophone --out data/features` → `data/features/v1_D1.csv`… (ignored by Git). Prints aggregates only; `--check-v0` compares the nights with `explore_d1.py` (TODO 2.5). |
| `train.py` | Trains and evaluates the state model on the v1 tables (TODO 2.8–2.11): `python ml/train.py --features data/features`; 5 folds by participant on D-1 + D-2, imputation and scaling fitted inside each training fold (sklearn Pipeline). `--test-d3`: single test on the held-out D-3; `--final data/models/state_model.joblib`: final model on all waves (TODO 2.14) and the "time only" model of the app's fallback (TODO 2.21), kept in `data/` (the exported coefficients are in Git, see `export.py`). Prints aggregates only. Tests: `ml/tests/test_train.py` (synthetic tables). |
| `export.py`, `export_coreml.py` | Export of the final model to the app (TODO 2.15–2.16): `python ml/export.py --model data/models/state_model.joblib [--coreml]` writes `app/Harmony/Resources/model_params.json` (< 5 KB; the time-only model under `time_only`) and, with `--coreml` (macOS, coremltools 8), `StateModel.mlmodel`, checked against scikit-learn on 100 rows (gap < 1e-6). `export.predict` is the reference the Swift code must match. Tests: `ml/tests/test_export.py`. |
| `make_fixtures.py` | Golden fixtures for the Swift tests (TODO 2.17): `python ml/make_fixtures.py` → `ml/fixtures/state_cases.json`, 10 synthetic cases (fixed seed) with series, expected features, probability and time-only probability. Tests: `ml/tests/test_fixtures.py`. |
| `explore_waves.py` | Compares aggregate ESM and sensor structure across EmoPhone waves D-1, D-2 and D-3 (TODO 1.35): `python ml/explore_waves.py --data data/emophone`. |
| `uci_explore.py` | Explores UC Irvine with aggregate outputs only (TODO 5.2): `python ml/uci_explore.py`; streams Samsung PPG and reports dataset coverage. |
| `uci_build_features.py` | Builds resumable UC Irvine v1 features in `data/features/v1_UCI.csv` with per-participant cache in `data/uci_cache/` (TODO 5.4–5.5); reuses `features.py` unchanged. |
| `uci_eval.py` | Runs the frozen UC Irvine one-shot, grouped validation and comparison protocol (TODO 5.6–5.8): `python ml/uci_eval.py`; aggregate metrics only. |
| `make_demo_data.py` | Writes the app's synthetic demo data (`app/Harmony/Resources/demo/`): 14 days of watch data and 50 scored songs, from a fixed seed (no real person, no real song). Standard library only: `python ml/make_demo_data.py`. |
| `muse_download.py` | Downloads MuSe v3 (`muse_v3.csv`, Kaggle, CC BY 4.0) into `data/muse/`, checks its size against Kaggle and its SHA-256 against the recorded one (same file for everyone), then prints the columns and value ranges (aggregates only). Standard library only: `python ml/muse_download.py`. Results and decisions: `docs/PROJECT.md` §5.2. |
| `normalize.py` | Normalizes song titles and artists for MuSe lookup (TODO 1.40); shared cases: `ml/fixtures/normalize_cases.json`. |
| `muse_build.py` | Rebuilds the ignored local SQLite file (TODO 1.39): run `python ml/muse_download.py`, then `python ml/muse_build.py`; no database file is stored in Git. |
| `llm_check.py`, `llm_anchors.py`, `prompts/` | LLM song scores (TODO 2.29–2.30). `prompts/score.txt` (system prompt, with the 48 reference songs printed by `python ml/llm_anchors.py`) and `prompts/score_config.json` (model, max tokens, effort, output schema) are the single source read by the Worker and by this script; shared cases: `ml/fixtures/score_cases.json`. `python ml/llm_check.py` (needs `ANTHROPIC_API_KEY`) sends 2,000 MuSe titles and artists (never their scores) through the Batch API, keeps the batch in `data/llm_check/` (resumable) and prints aggregates only: correlation and error against MuSe, and the TODO 2.31 rule. Trial 3 (`docs/PROJECT.md` §7): `--part dev --effort low|medium`, then `--part test --shrink K_ENERGY K_POSITIVITY`. Tests: `ml/tests/test_llm_check.py`. |
| `pilot_analysis.py` | Pilot analysis (TODO 4.7–4.9, `docs/pilot-protocol.md` §7): `python ml/pilot_analysis.py data/pilot/harmony-pilot.json` reads the app's anonymous export (`harmony-pilot-1`, never committed) and prints aggregate tables only; shared example: `ml/fixtures/pilot_export_example.json`. |
| `requirements.txt` | Python dependencies. |

Run:

```sh
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r ml/requirements.txt
python ml/explore_d1.py --data /path/to/dataverse_files/D1
python -m unittest ml.tests.test_features ml.tests.test_normalize ml.tests.test_train ml.tests.test_export ml.tests.test_fixtures ml.tests.test_uci ml.tests.test_llm_check ml.tests.test_pilot_analysis -v
python ml/build_features.py --data data/emophone --out data/features
python ml/train.py --features data/features
```

The EmoPhone files stay outside the repository (`data/` is ignored by Git). Never commit them,
never paste them into a chat, never ship them in the app (NFR9).

## Phase 6 — évaluation locale du modèle d'état

Les critères sont dans `docs/PROJECT.md` §3. Les tables et les fichiers joblib
restent dans `data/`. Le build du 26 nov. garde son modèle à 13 features.
Les résultats agrégés sont résumés dans `docs/PROJECT.md` §6.5 et §6.8.

```text
python ml/build_features.py --data data/emophone --out data/features --v2 --waves D1 D2
python ml/evaluate_v2.py
python ml/build_features.py --data data/emophone --out data/features --v2 --waves D3
python ml/evaluate_v2.py --confirm-d3 data/results/wp-a1.json
python ml/simulate_wp_b0.py --out data/results/wp-b0.json
```

Après adoption de l'énergie v2, `ml/evaluate_v2.py --final data/results/wp-a1.json
data/models/state_v3.joblib` entraîne le candidat. Utiliser ensuite `ml/export.py
--model data/models/state_v3.joblib --out data/models/v3 --coreml` sur macOS et
`ml/make_fixtures.py --model data/models/state_v3.joblib --out data/models/v3/state_cases.json`.
WP-B0 utilise le contrat v1 du pilote par défaut. L'option `--v2` simule le candidat.
