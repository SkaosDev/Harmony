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

## Prerequisites

What you need depends on the part you work on. Each line comes with a command to check it.

### Everyone

| What | Check |
|---|---|
| Git, and the collaborator invitation to `SkaosDev/Harmony` accepted | `git clone https://github.com/SkaosDev/Harmony.git` |
| Claude Code | `claude --version` |
| GitHub CLI, to open and review PRs (optional) | `gh auth status` |

### iPhone app (Mac only)

iOS apps can only be built on a Mac.

| What | Check |
|---|---|
| Xcode 27.2 + command-line tools (`xcode-select --install`) | `xcodebuild -version` |
| Node.js 18+ (for XcodeBuildMCP now, and for `wrangler`, the Cloudflare Worker tool, later) | `node -v` |
| XcodeBuildMCP in Claude Code: `claude mcp add -s user XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp` | `/mcp` in Claude Code lists it as connected |

The simulator needs nothing more. To run the app on a real iPhone you also need:
- your iPhone registered in the team's Apple Developer account (HealthKit does not work with a free account);
- the Spotify app, logged in with an account added to the team's Spotify developer dashboard
  (5 users max); playback needs Spotify Premium;
- an Apple Watch for real health data (otherwise use the demo mode, TODO 1.17).

### ML scripts (Windows or Mac)

| What | Check |
|---|---|
| Python 3.12 (not 3.14: the pinned scikit-learn 1.5.2 does not install on it) | `python --version` |
| Virtual environment + dependencies (commands below) | `python -c "import sklearn; print(sklearn.__version__)"` prints `1.5.2` |
| EmoPhone waves copied to `data/emophone/D1`, `D2`, `D3` (ask the team; never commit them) | `git status` does not list them |

```sh
# Windows (PowerShell). If activation is blocked:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
py -3.12 -m venv .venv
.venv\Scripts\activate

# macOS
python3.12 -m venv .venv && source .venv/bin/activate

# Both
pip install -r ml/requirements.txt
python ml/explore_d1.py --data data/emophone/D1   # must reproduce Table VII of the report
```

### Report

A LaTeX distribution with `latexmk`: MacTeX on Mac, MiKTeX or TeX Live on Windows. Check: `latexmk -v`.

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
