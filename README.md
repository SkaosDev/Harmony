# Context-Aware Music Companion — CSE 406 Group G02 "FireStarter"

iPhone app that picks songs from the user's own Spotify library for four moments
(wake-up, stress, low energy, wind-down), using smartwatch data (heart rate, steps,
sleep) compared with the person's own usual values.

Repository: https://github.com/SkaosDev/Harmony

Members: Clément Royer, Cyprien Vanden Abeele, Lucas Miskulin, Riad Mekideche.

## Start here

1. `docs/PROJECT.md` — full context: idea, decisions, architecture, data, model, where we are.
2. `docs/TODO.md` — ordered checklist, from setup to the final report.
3. `CLAUDE.md` — rules for Claude Code (general guidelines + project rules).

## Repository layout

| Folder | Content |
|---|---|
| `docs/` | LaTeX sources of the documents (IEEE template). `main.tex` holds Submission A (revised) and Submission B; `Submission-B.md` is a Markdown version. `submission-A.pdf` is the version handed in for A. |
| `app/` | iPhone app (Swift, SwiftUI) — from the implementation phase |
| `ml/` | Python code for the song scores and the state model (`explore_d1.py` reproduces Table VII of Submission B) |
| `data/` | **Local only, never committed** (see below) |

## Build the documents

```sh
cd docs
latexmk -pdf main.tex
```

`IEEEtran.cls` (v1.8b) is included so the document builds without extra packages.

## Datasets and terms of use

- **EmoPhone** (Harvard Dataverse, doi:10.7910/DVN/QGRVU8): access granted by the
  dataset authors for this project. The data files must not be redistributed, so they
  stay in `data/` on team computers and are ignored by Git.
- **UC Irvine** (Dryad, doi:10.7280/D1WH6T): same rule, kept in `data/`.
- **MuSe** (Zenodo, doi:10.5281/zenodo.4281165, CC BY 4.0): may be redistributed;
  the reduced table used by the app will live in `app/` once built.

Before each submission, check that `git ls-files data/` lists nothing but `data/README.md`.
