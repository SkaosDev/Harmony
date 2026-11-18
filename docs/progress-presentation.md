# Harmony — five-minute project progress presentation

**Audience:** project/course audience  
**Target length:** about 5 minutes (approximately 590 spoken words, excluding slide bullets)  
**Status basis:** the requested status says sections 2.1–2.7 are complete and 2.8–2.14 are in progress. The repository's `docs/TODO.md` still has 2.1–2.14 unchecked, and the checked-in code/report do not yet verify the v1 feature table or these training tasks. Treat these sections as the team-reported status and update the TODO/evidence before presenting it as verified.

## Slide 1 — Harmony: music for the moment (0:35)

**Slide text**
- A context-aware music companion for iPhone
- Uses a personal Spotify library and Apple Watch signals
- Four moments: wake-up, stress, low energy, wind-down
- Goal: a short queue that fits the moment

**Spoken script**
“Hello. We are team FireStarter, and our project is Harmony, a context-aware music companion for iPhone. The idea is to make it easier to choose music in a specific moment: waking up, feeling stressed, having low energy, or winding down. Harmony uses songs from the listener’s own Spotify library and, with permission, Apple Watch health summaries. It aims to build a short queue that gradually moves toward the selected listening goal. This is a music recommendation prototype, not a medical tool.”

**Visual suggestion:** a simple three-part flow: Apple Watch + time → Harmony on iPhone → Spotify queue. Use the four situation labels as small icons.  
**Timing:** 35 seconds.

## Slide 2 — From idea to working foundations (0:45)

**Slide text**
- iOS app structure and three-tab navigation
- Spotify sign-in, token storage, and library import
- HealthKit consent and watch summaries
- Synthetic demo mode for simulator work
- Reproducible Python data exploration

**Spoken script**
“Our first major milestone was turning the proposal into working foundations. The iPhone project now has its core structure, data models, and Home, Library, and Settings navigation. The Spotify integration covers sign-in, secure token storage, token refresh, and paginated library import; the project notes an import of 939 tracks in 4.6 seconds on a real account. The HealthKit path reads heart rate, steps, heart-rate variability, and sleep, then stores summaries instead of raw samples. A synthetic demo mode lets the team work in the simulator without real health data. On the research side, the EmoPhone exploration scripts reproduce the report’s initial results.”

**Visual suggestion:** a real screenshot of the current app’s three-tab shell, alongside a compact data-flow diagram. Avoid implying unfinished screens are implemented.  
**Timing:** 45 seconds.

## Slide 3 — What the early data says (0:50)

**Slide text**
- EmoPhone: three waves explored (D-1, D-2, D-3)
- D-1: 10,259 responses from 92 participants
- D-1 arousal AUROC: 0.573 (time-only: 0.532)
- Heart rate carries most of the measurable signal
- Stress prediction remains weak

**Spoken script**
“The early results give us a useful, realistic baseline. In D-1, the report records 10,259 mood responses from 92 participants. With participant-separated evaluation, the four-input arousal model reaches an AUROC of 0.573, compared with 0.532 for time of day alone. That is a measurable improvement, but still a modest result: 0.5 is chance. Heart rate appears to carry most of the useful signal. Adding steps and sleep did not produce a measurable gain on D-1, and stress was only weakly predictable. This is why we describe the work as promising but limited, rather than claiming reliable emotion detection.”

**Visual suggestion:** a two-bar chart for D-1 AUROC: time-only 0.532 and time + heart rate + steps + sleep 0.573. Label it “initial v0 result, D-1”; do not call it the final v1 model.  
**Timing:** 50 seconds.

## Slide 4 — Completed work reported through 2.7 (0:45)

**Slide text**
- v1 feature definition: personal baselines and watch-compatible heart-rate sampling
- Sleep, steps, and missing-data handling carried into the feature plan
- D-3 rating-scale adjustment specified
- v1 tables for D-1, D-2, and D-3 reported complete
- Raw datasets remain local and excluded from Git

**Spoken script**
“According to our current progress update, work through task 2.7 is complete. This stage moves from exploratory features toward a version that could run consistently in the app: personal baselines based only on the preceding fourteen days, regular reference times, heart-rate sampling every five minutes, and explicit handling of missing sleep or watch data. It also includes putting the D-3 labels onto a comparable scale and building the v1 feature tables for all three EmoPhone waves. The data-handling rule is important: the restricted participant data stays local and is not committed to the repository. The current project documents describe these design choices, while the v1 implementation evidence still needs to be reflected in the checklist.”

**Visual suggestion:** a pipeline diagram: raw watch signals → 13 ordered v1 features → local per-wave tables. Mark the v1 implementation/table stage “team-reported complete; checklist pending.”  
**Timing:** 45 seconds.

## Slide 5 — Current focus: evaluate the model (0:50)

**Slide text**
- Train and compare models on D-1 + D-2
- Keep participants separated across five folds
- Compare against a time-only baseline
- Test once on held-out D-3
- Decide which inputs are worth keeping

**Spoken script**
“Tasks 2.8 to 2.14 move into model evaluation. The planned comparison trains on D-1 and D-2 using five participant groups, so that people in a test fold are not mixed with training participants. We compare the wearable-based inputs with a time-only baseline, then keep D-3 separate for a one-time held-out test. The team will use those results to decide whether the final model should use heart rate alone, all four inputs, or a simpler time-only fallback. The report already contains exploratory v0 results for each wave, but those are not the same as the planned v1 training and held-out evaluation.”

**Visual suggestion:** a train/test diagram with D-1 + D-2 on the training side and D-3 on a separate test side; add “participant groups kept apart.”  
**Timing:** 50 seconds.

## Slide 6 — What remains before the model reaches the app (0:45)

**Slide text**
- Final model training and team decision
- Confirm dataset terms for publishing model coefficients
- Export parameters and convert to Core ML
- Match Python and Swift with synthetic golden cases
- Connect the estimate to song scores and queue logic

**Spoken script**
“After evaluation, the remaining path is integration. The selected model must be trained on the agreed data, and the team must confirm that publishing its coefficients is allowed under the dataset terms. Then the model parameters need to be exported and converted to Core ML. A key engineering check is that Python and Swift produce the same features and probabilities on synthetic test cases. Only after that can the on-device estimate be reliably connected to song scoring and queue generation. The app foundations and Spotify and HealthKit connectors reduce some integration risk, but the end-to-end recommendation flow is not yet documented as complete.”

**Visual suggestion:** a short roadmap: evaluate → choose → export → verify parity → integrate. Show an example of synthetic test input, not a real participant record.  
**Timing:** 45 seconds.

## Slide 7 — Next milestone and close (0:30)

**Slide text**
- Finish and record the 2.8–2.14 evaluation evidence
- Confirm model choice and data-use permission
- Integrate and verify on-device inference
- Build toward a complete recommendation demo

**Spoken script**
“Our next milestone is to turn the reported v1 feature work into reproducible evaluation evidence, make a model choice based on the held-out results, and verify that the chosen model runs consistently on the phone. From there, we can connect the state estimate to scored songs and a short Spotify queue. Harmony has established its app, data, and research foundations; the current challenge is proving that the model adds enough value and carrying that result safely into the product. Thank you.”

**Visual suggestion:** a clean milestone timeline ending with “end-to-end demo”; keep it labeled as the next milestone, not a completed result.  
**Timing:** 30 seconds.

## Presenter notes: evidence and wording

- The repository gives evidence for the app shell, Spotify auth/import, HealthKit summaries, synthetic demo mode, EmoPhone exploration, and MuSe preparation in `docs/TODO.md`, `docs/PROJECT.md`, `app/README.md`, and `ml/README.md`.
- The documented D-1 initial result varies slightly between runs/sections (approximately 0.572–0.573 for the four-input model; time-only approximately 0.530–0.532). The script uses the report's headline pair, 0.573 vs 0.532, and labels it as an initial v0 result.
- D-2/D-3 exploratory results are reported, but they do not verify the planned v1 train-on-D-1/D-2 and held-out-D-3 evaluation.
- The current TODO checkboxes for 2.1–2.14 are unchecked. Before presenting “completed through 2.7” as repository-verified, update the checklist only after checking each criterion and add the corresponding v1 artifacts/results. If that cannot be done before the presentation, retain the “team-reported” qualification on Slide 4.
- Do not display raw EmoPhone or UC Irvine data, participant identifiers, or individual-level examples.