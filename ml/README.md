# ml/

Python code for the state model and the song scores.

| File | What it does |
|---|---|
| `explore_d1.py` | Reproduces Table VII of Submission B (first results on EmoPhone wave D-1). Checked on Nov. 5, 2026 with scikit-learn 1.5.2: same numbers as the report. |
| `requirements.txt` | Python dependencies. |

Run:

```sh
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r ml/requirements.txt
python ml/explore_d1.py --data /path/to/dataverse_files/D1
```

The EmoPhone files stay outside the repository (`data/` is ignored by Git). Never commit them,
never paste them into a chat, never ship them in the app (NFR9).
