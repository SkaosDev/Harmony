# ml/

Python code for the state model and the song scores.

| File | What it does |
|---|---|
| `explore_d1.py` | Reproduces Table VII of Submission B (first results on EmoPhone wave D-1). Checked on Nov. 5, 2026 with scikit-learn 1.5.2: same numbers as the report. |
| `make_demo_data.py` | Writes the app's synthetic demo data (`app/Harmony/Resources/demo/`): 14 days of watch data and 50 scored songs, from a fixed seed (no real person, no real song). Standard library only: `python ml/make_demo_data.py`. |
| `requirements.txt` | Python dependencies. |

Run:

```sh
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r ml/requirements.txt
python ml/explore_d1.py --data /path/to/dataverse_files/D1
```

The EmoPhone files stay outside the repository (`data/` is ignored by Git). Never commit them,
never paste them into a chat, never ship them in the app (NFR9).
