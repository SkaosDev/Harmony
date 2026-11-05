# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# Project: Harmony (CSE 406, group G02 "FireStarter")

iPhone app that plays a short queue from the user's own Spotify library to fit the moment
(wake-up, stress, low energy, wind-down), using Apple Watch heart rate, steps and sleep.
Full context: `docs/PROJECT.md`. Work plan: `docs/TODO.md`. Course report: `docs/main.tex`.

## Before any task
- Read `docs/PROJECT.md` (sections relevant to the task) and the task in `docs/TODO.md`.
- One TODO item (or a small group) per session and per branch. Tick it in `docs/TODO.md`
  only when its "check" line is verified.
- If the task contradicts `docs/PROJECT.md` or the report, stop and ask.

## Stack
- App: Swift 6, SwiftUI, SwiftData, HealthKit, Core ML; iOS 18.0 minimum; Xcode 27.2.
- Spotify: Web API (library) + iOS SDK / App Remote (playback). Development mode: 5 users max.
- ML: Python 3.12, pandas, scikit-learn 1.5.2 (pinned for coremltools 8).
- Cloud: one Cloudflare Worker (TypeScript) that holds the LLM API key. Nothing else.

## Hard rules
- Never commit, print or paste EmoPhone / UC Irvine data. They live in `data/` (git-ignored) or
  outside the repo. Only scripts and aggregate results go to Git (the trained model too,
  once TODO 2.14b is confirmed).
- No API key or secret in the app or in Git. The LLM key lives only in the Worker (`wrangler secret`).
- Health data never leave the phone. The Worker only receives song titles and artists.
- Never show a named emotion to the user; no medical claims.
- Model evaluation always keeps whole participants apart (GroupKFold / held-out wave). Never a random split.
- The features computed in Swift must match `docs/PROJECT.md` §6 exactly; a change there means
  retraining and updating the golden test fixtures.
- Unknown is not zero: a night or a period without watch data is "unknown", never 0 sleep or 0 steps.

## Commands
- ML results check: `python ml/explore_d1.py --data <path to D1>` (must reproduce Table VII).
- iOS build/test: through XcodeBuildMCP if installed, otherwise `xcodebuild test -scheme Harmony
  -destination 'platform=iOS Simulator,name=iPhone 16'`.
- Report: `cd docs && latexmk -pdf main.tex`.
