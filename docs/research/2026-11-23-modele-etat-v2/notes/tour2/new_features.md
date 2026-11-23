# New input features for Harmony's state model: offline experiments on EmoPhone D-1 + D-2

Scope and method (applies to every section). Only D-1 and D-2 were opened (D-3 and `v1_D3.csv` untouched). Nothing in the repo was changed; repo modules (`ml/features.py`, `ml/train.py`) were imported read-only with `PYTHONDONTWRITEBYTECODE=1`, Python 3.12 + scikit-learn 1.5.2 from the repo `.venv`. Only aggregates are reported; `UserInfo.csv` and `Location.csv` were never opened.

- Scripts: `/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/` — `extract.py` (new features, one pass over the sensor archives), `evaluate.py` (families, single-feature screen, Q5), `diag.py` (subset scoring), `probe.py` (file formats).
- Outputs (aggregate text): `.../scratchpad/v2/features/out/` — `eval_families.txt` (LOCAL-FAM), `eval_singles.txt` (LOCAL-SINGLE), `diag.txt` (LOCAL-DIAG), `eval_q5_P.txt` / `eval_q5_P0.txt` (LOCAL-Q5), `extract.txt`, `probe.txt`. Derived per-response tables `new_D1.csv`, `new_D2.csv` (participant, t, valence, new features; local only, never to Git).
- Rows: exactly the 31,301 answers / 191 participants of `data/features/v1_D1.csv` + `v1_D2.csv`, same order. Valence joined from each wave's `EsmResponse.csv` with the same read/sort as `ml/build_features.py` (assert: t, arousal, stress identical row by row). `valence_high` = `features.label_high(valence, participant)`. Base rates: arousal_high 0.464, valence_high 0.566, stress_high 0.462 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt).
- Evaluation: `train.folds()` (5 GroupKFold folds by `wave + pcode`), model = median imputer + StandardScaler + LogisticRegression (C = 1 unless "nested C"), fitted inside each training fold. Results = mean ± sd over the 5 folds (sd with ddof = 0, as `train.py`); "Δ" = fold-wise paired difference (v1 + X) − v1 (13 features), mean ± sd, and the number of folds where Δ > 0. BA = balanced accuracy at 0.5.
- Validation of the extraction: my whole-minute re-derivation of v1 `z_hr_30` / `z_log_steps_30` correlates r = 0.995 / 0.990 with the v1 table (same unknown share 0.43 on D-1), and `hours_since_wake` is identical (r = 1.0, max diff 0) — [extract run, local check](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/extract.py).
- New windows use whole local minutes strictly before the answer minute ([a − w, a − 1]); HR = v1 resampled HR (first reading per 5-min clock slot); "worn" 5-min slot = a resampled HR or a Fitbit step row (v1 rule); unknown = NaN, imputed by the training median. Personal z-scores use either the v1 30-min grid (08:00–23:30, 14 previous days, ≥ 7 distinct days) or, for day-level quantities, the same quantity on each of the 14 previous days (≥ 7 known days; ≥ 5 known nights for wake-based ones).

**Reference numbers on this machine (same `train.folds`)**: arousal time-only 0.534 ± 0.009, v1 0.563 ± 0.012 (BA 0.537 ± 0.007); valence time-only 0.534 ± 0.004, v1 0.542 ± 0.017 (BA 0.512 ± 0.002); stress time-only 0.543 ± 0.012, v1 0.540 ± 0.011 (BA 0.516 ± 0.005) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt). Calling `train.load` + `train.folds` + `train.cross_validate` directly on this Mac gives the same 0.534 ± 0.009 / 0.554 ± 0.010 / 0.563 ± 0.012 (BA 0.537 ± 0.007), whereas PROJECT.md §6.5 reports 0.535 ± 0.017 / 0.554 ± 0.012 / 0.563 ± 0.010 (BA 0.540 ± 0.004) — [docs/PROJECT.md §6.5](/Users/clement/Hanyang/Harmony/docs/PROJECT.md). Same means, different fold sds → the fold assignment differs between the two machines (191 participants, 41 tied answer counts; GroupKFold breaks ties with a non-stable `argsort`; macOS / NumPy 2.5.4 here vs the team's Windows run). Fold test sizes here: 6255 / 6250 / 6258 / 6280 / 6258.

## Q1. Day context from HR and steps only (no new sensor): does it help?

### Takeaway
No. Every personally referenced day-context feature (longer 2–4 h windows, day so far since 06:00, since wake / morning, yesterday, previous evening) adds ≤ +0.002 AUROC to v1 for all three targets, with fold sds as large as the gain; "yesterday / previous evening" is slightly harmful for valence (−0.003, 0/5 folds). The only HR-and-steps-only features that help are those that need **no 7-day reference** (raw HR and raw step counts in the last 30/60 min, minutes since the last walking minute), and their gain is a coverage effect (see Q5 and the diagnostic below), not "day context".

### Cited Findings
**Definitions tested (all past-only, same resampling; family letter used in the tables)**
- A long windows: `z_hr_120`, `z_hr_240`, `z_log_steps_120`, `z_log_steps_240` (v1 grid reference).
- B day so far: since the most recent 06:00, `log1p(steps)`, mean HR, mean sedentary HR; known if ≥ 50 % of the 5-min slots are worn; z vs the same quantity at the same clock time on each of the 14 previous days (≥ 7 known).
- C since wake / morning (needs the v1 night estimate, i.e. Apple Watch sleep in the app): `log1p(steps)` and mean HR from wake to t, HR of the first 60 min after wake, steps of the first 120 min after wake; z vs the same elapsed span after wake on the previous 14 days (≥ 5 known nights).
- D yesterday / previous evening: yesterday's total steps (known if ≥ 60 % of 08:00–22:00 slots worn), yesterday's mean HR and mean sedentary HR 08:00–22:00, previous evening (18:00–24:00) HR and steps; z vs the 14 days before yesterday (≥ 7 known).
- F `log_min_since_walk` = log(1 + minutes since the last minute with ≥ 60 steps), capped at 12 h; unknown unless ≥ 50 % of the slots since then (or of the 12 h) are worn.
- Source of all definitions: [extract.py](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/extract.py).

**Δ AUROC vs v1 (13), mean ± sd over 5 folds (folds > 0)** — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)

| Added to v1 | n | arousal_high | valence_high | stress_high |
|---|---:|---|---|---|
| A long windows 2–4 h | 4 | +0.0008 ± 0.0019 (3/5) | +0.0006 ± 0.0012 (4/5) | +0.0011 ± 0.0015 (4/5) |
| B day so far (since 06:00) | 3 | +0.0019 ± 0.0024 (4/5) | −0.0003 ± 0.0029 (2/5) | −0.0023 ± 0.0021 (0/5) |
| C since wake / morning | 4 | +0.0008 ± 0.0010 (4/5) | +0.0005 ± 0.0012 (4/5) | +0.0015 ± 0.0021 (4/5) |
| D yesterday / previous evening | 5 | −0.0005 ± 0.0009 (1/5) | −0.0033 ± 0.0031 (0/5) | −0.0028 ± 0.0020 (1/5) |
| F minutes since walking | 1 | +0.0031 ± 0.0046 (3/5) | +0.0021 ± 0.0044 (4/5) | −0.0005 ± 0.0041 (4/5) |
| A+B+C+D+F together | 17 | +0.0038 ± 0.0058 (4/5) | +0.0000 ± 0.0017 (3/5) | −0.0022 ± 0.0036 (2/5) |
| R1 raw `log1p(steps)` 30/60 min, no reference | 2 | +0.0030 ± 0.0037 (4/5) | **+0.0128 ± 0.0064 (5/5)** | +0.0001 ± 0.0053 (3/5) |
| R2 raw mean HR 30/60 min, no reference | 2 | +0.0086 ± 0.0108 (4/5) | **+0.0122 ± 0.0056 (5/5)** | −0.0002 ± 0.0041 (3/5) |

- Balanced-accuracy deltas follow the same pattern (A–D within ±0.003; R1 / R2 valence +0.008 / +0.009) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Single-feature screen (each feature alone added to v1): no referenced day-context feature exceeds +0.0021 for arousal (best: `z_sedhr_since6` +0.0021 ± 0.0021, 5/5; `z_hr_since6` +0.0020 ± 0.0023, 4/5) or +0.0008 for valence (`z_hr_wake60`); top single features are all un-referenced: arousal `raw_hr_30` +0.0086 ± 0.0108 (4/5), valence `raw_log_steps_60` +0.0126 ± 0.0065 (5/5), `raw_hr_30` +0.0122 ± 0.0057 (5/5) — [LOCAL-SINGLE](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_singles.txt)
- Morning answers only (local time < 12:00; 3,627 answers = 11.6 %; models fitted on all rows, scored on morning test rows): arousal v1 0.561 ± 0.015 vs time-only 0.528 ± 0.019, and B / C / D add −0.0010 / −0.0002 / −0.0021; valence v1 0.512 ± 0.027 (below time-only 0.520 ± 0.035), A–F together +0.0113 ± 0.0092 (4/5), but from a v1 base that is itself below time-only; stress A–F together −0.0159 ± 0.0050 (0/5) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Redundancy (pooled Pearson r, rows where both known): `z_hr_120` vs `z_hr_60` +0.876; `z_hr_since6` vs `z_hr_60` +0.383; `z_steps_since6` vs `z_log_steps_60` +0.387; `z_hr_yday` vs `z_hr_30` +0.064; `log_min_since_walk` vs `z_log_steps_60` −0.577 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Coverage problem: the day-context z-scores are unknown for 57–72 % of answers pooled (B 0.635, C 0.69–0.72, D 0.57–0.60), vs 0.47–0.48 for v1-style window z-scores and 0.06–0.37 for raw window values (table in Q6) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Where raw values help (diag; models fitted on all rows, scored on subsets): answers with v1 `z_hr_30` unknown but HR present (21.0 % of answers): + raw R1+R2 gives arousal +0.0276 ± 0.0285 (4/5), valence +0.0455 ± 0.0283 (5/5), stress +0.0067 ± 0.0206 (3/5); answers with `z_hr_30` known (51.6 %): arousal +0.0025 ± 0.0094 (3/5), valence +0.0156 ± 0.0177 (3/5), stress +0.0004 ± 0.0165; answers without any HR (27.4 %): −0.0007 for all three; first 7 days of each participant (35.1 %): arousal +0.0140 ± 0.0179, valence +0.0301 ± 0.0178 (5/5) — [LOCAL-DIAG](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/diag.txt)
- By wave, R1+R2 valence gain: D-1 +0.0308 ± 0.0104 (5/5), D-2 +0.0114 ± 0.0123 (4/5); arousal D-1 +0.0100, D-2 +0.0057 — [LOCAL-DIAG](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/diag.txt)

### Inferences
- "More context" in the form of personally referenced day-level summaries does not carry measurable extra information on EmoPhone beyond the 15–60 min windows already in v1; the extra coverage loss (a 14-day same-clock reference needs 7 good days) cancels whatever signal there is.
- The real lever is the v1 rule that a z-score needs 7 days of history: about half of the answers (and every answer of a new user's first week) get median-imputed HR and step z-scores. Adding the same windows **un-referenced** (raw HR in bpm and raw log steps) recovers signal mostly on exactly those answers. In the app this matters even more than in EmoPhone: a new user has no history at all, so raw windows would be the only HR/steps information during week 1.
- Raw HR mixes between-person HR level with within-person change; it still helps because the label is within-person and the model only needs the within-person slope. A cleaner alternative (not tested) would be a z-score whose reference becomes ready earlier (e.g. 2–3 days) or a population-level reference until the personal one is ready.
- The morning subset is small (11.6 %) and noisy; no morning-specific variant is worth a model change on this evidence.

### Gaps
- The relaxed-reference alternative (z ready after 2–3 days) was not measured; it might capture the same coverage gain with features that are more comparable across people.
- Sleep is estimated from Fitbit HR + steps in EmoPhone, so the since-wake features use an estimated wake time; Apple Watch measured sleep could behave differently.
- Fold-wise sd of 5 folds is a weak test; no participant-level bootstrap or repeated splits were run.

## Q2. Resting / sedentary HR and HR residual after steps

### Takeaway
No gain. Sedentary HR (readings with no step in that minute and the 10 minutes before) and an HR residual after removing the effect of recent steps add −0.0005 to +0.0002 AUROC to v1 for all three targets; replacing v1's HR by sedentary HR lowers arousal AUROC by 0.004 (1/5 folds better). Apple's `HKHeartRateMotionContext.sedentary` tag would give the same information directly, but it is not worth a model change on this evidence.

### Cited Findings
- E1 `z_sedhr_30/60/120`: mean of sedentary readings in the window (sedentary = resampled HR reading with 0 steps in its minute and the previous 10 min), z vs the v1 grid of the same quantity — [extract.py](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/extract.py)
- E2 `zres_hr_30/60`: per person, OLS of HR on [1, log1p(steps in the reading minute + 10 min before), log1p(steps in the 60 min before)] fitted on that person's readings of the 14 days before t (≥ 100 readings, ≥ 7 days); feature = mean residual of the readings in the window / residual sd — [extract.py](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/extract.py)
- Δ AUROC vs v1: E1 arousal −0.0002 ± 0.0009 (3/5), valence −0.0004 ± 0.0012 (2/5), stress +0.0001 ± 0.0019 (3/5); E2 arousal −0.0003 ± 0.0006 (2/5), valence +0.0002 ± 0.0004 (4/5), stress −0.0005 ± 0.0008 (2/5); E1 + E2: −0.0004 / −0.0002 / +0.0002 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- v1 with the 4 HR features replaced by `z_sedhr_30/60/120`: arousal 0.559 ± 0.014, Δ −0.0041 ± 0.0033 (1/5); valence Δ −0.0002 ± 0.0026; stress Δ +0.0013 ± 0.0033 (3/5) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Day-level sedentary HR (resting-HR proxy): `z_sedhr_yday` −0.0001 (arousal) and `z_sedhr_since6` +0.0021 ± 0.0021 (arousal, 5/5) as single additions — [LOCAL-SINGLE](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_singles.txt)
- Redundancy: r(`z_sedhr_60`, `z_hr_60`) = +0.789; r(`zres_hr_30`, `z_hr_30`) = +0.676 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Unknown share pooled: `z_sedhr_30` 0.613, `z_sedhr_60` 0.538, `z_sedhr_120` 0.491, `zres_hr_30` 0.484 (v1 `z_hr_30` ≈ 0.48) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Apple: `HKHeartRateMotionContext.sedentary` = "the user has been still for at least 5 minutes prior to the heart rate sample"; `.active` = "the user was in motion during the heart rate sample"; `.notSet` = "could not be determined", identical to the metadata key being absent; key `HKMetadataKeyHeartRateMotionContext` (iOS 11 / watchOS 4) — [Apple: sedentary](https://developer.apple.com/documentation/healthkit/hkheartratemotioncontext/sedentary), [Apple: active](https://developer.apple.com/documentation/healthkit/hkheartratemotioncontext/active), [Apple: notSet](https://developer.apple.com/documentation/healthkit/hkheartratemotioncontext/notset), [Apple: HKMetadataKeyHeartRateMotionContext](https://developer.apple.com/documentation/healthkit/hkmetadatakeyheartratemotioncontext)
- Apple: `restingHeartRate` is "an estimation of the user's lowest heart rate during periods of rest"; "a resting heart rate sample is different than a sedentary heart rate sample"; "the system estimates the resting heart rate by analyzing sedentary heart rate samples throughout the day" — [Apple: restingHeartRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate)

### Inferences
- At 1 reading / 5 min and z-scored against a personal reference, "HR at rest" and "HR adjusted for steps" carry nearly the same information as plain HR (r 0.68–0.79), and losing the non-sedentary readings costs coverage. Removing the step effect may even remove useful signal: being active is part of feeling activated.
- iOS equivalent if ever wanted: filter `heartRate` samples whose `HKMetadataKeyHeartRateMotionContext` = sedentary (1) instead of the "no steps in 10 min" proxy; daily `restingHeartRate` for a "yesterday" variant. No new permission beyond heart rate.

### Gaps
- My sedentary proxy uses 10 min without steps (Apple: ≥ 5 min still, from the accelerometer); the share of Apple Watch background readings tagged sedentary vs active vs notSet was not measured on a real watch.
- Apple's resting-HR algorithm is not public, so `z_sedhr_yday` is only a proxy for `restingHeartRate`.

## Q3. Intensity (Fitbit-Calorie → activeEnergyBurned / physicalEffort): anything beyond steps?

### Takeaway
No. Intensity z-scored like v1 (METs and share of minutes at Fitbit level ≥ 1, 15/30/60 min) adds nothing (−0.0015 to −0.0001); METs cannot replace steps (−0.002 to −0.003). The apparent gain of the full intensity family (+0.006 arousal, +0.012 valence, 5/5 for valence) comes from its raw, un-referenced members and disappears once raw step counts are in the model (+0.0018 arousal, −0.0007 valence on top of raw steps).

### Cited Findings
- File format (probe): `Fitbit-Calorie.csv` = one row per minute, `value` kcal/min including basal (≈ 0.83–1.10 kcal/min at rest), `mets` stored ×10 (10 = 1.0 MET), `level` 0–3 with level 0 on 86–89 % of minutes; rows exist even when the watch is not worn — [probe.txt](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/probe.txt). So METs / level were kept only on worn minutes (otherwise a removed watch looks like "1 MET, sedentary": unknown is not zero).
- Families: G1 z-scored = `z_mets_15/30/60`, `z_lvl1_share_30/60` (v1 grid reference); G2 raw = `lvl1_share_30/60` (share of worn minutes at level ≥ 1), `raw_mets_30/60` — [extract.py](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/extract.py)

| Comparison (Δ AUROC) | arousal_high | valence_high | stress_high |
|---|---|---|---|
| v1 + G (all 7 intensity features) vs v1 | +0.0058 ± 0.0061 (3/5) | +0.0115 ± 0.0086 (5/5) | +0.0001 ± 0.0072 (3/5) |
| v1 + G1 z-scored intensity vs v1 | −0.0004 ± 0.0006 (1/5) | −0.0001 ± 0.0016 (2/5) | −0.0015 ± 0.0017 (1/5) |
| v1 + G2 raw intensity vs v1 | +0.0054 ± 0.0043 (4/5) | +0.0089 ± 0.0045 (5/5) | −0.0014 ± 0.0075 (4/5) |
| v1 + R1 raw steps vs v1 | +0.0030 ± 0.0037 (4/5) | +0.0128 ± 0.0064 (5/5) | +0.0001 ± 0.0053 (3/5) |
| v1 + R1 + G2 vs v1 + R1 (intensity beyond steps) | +0.0018 ± 0.0020 (4/5) | −0.0007 ± 0.0028 (3/5) | −0.0015 ± 0.0026 (2/5) |
| v1 without its 3 step features vs v1 | −0.0012 ± 0.0018 (2/5) | −0.0034 ± 0.0019 (0/5) | −0.0017 ± 0.0018 (2/5) |
| v1 with `z_mets_15/30/60` instead of steps vs v1 | −0.0016 ± 0.0017 (1/5) | −0.0033 ± 0.0022 (0/5) | −0.0019 ± 0.0035 (2/5) |

Source: [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Redundancy: r(`z_mets_30`, `z_log_steps_30`) = +0.729, r(`z_mets_30`, `z_hr_30`) = +0.776, r(`lvl1_share_30`, `z_log_steps_30`) = +0.750 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Apple: `activeEnergyBurned` = active energy only ("should not include the resting energy"), "the system automatically records active energy samples on Apple Watch", cumulative, may be condensed/coalesced by HealthKit — [Apple: activeEnergyBurned](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/activeenergyburned)
- Apple: `physicalEffort` (iOS 17 / watchOS 10) in METs, discrete, "estimated and recorded automatically by Apple Watch" — [Apple: physicalEffort](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/physicaleffort)
- Apple: `appleExerciseTime` counts "every full minute of movement that equals or exceeds the intensity of a brisk walk" (closest to Fitbit level ≥ 2) — [Apple: appleExerciseTime](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/appleexercisetime)

### Inferences
- Intensity is a near copy of steps (and of HR) at this time scale; the new HealthKit read permissions (`activeEnergyBurned`, `physicalEffort`) are not justified by this evidence.
- If the team still wants intensity, the closest iOS computation of `lvl1_share_w` is the share of minutes in (t − w, t] covered by `activeEnergyBurned` samples with a rate above a light-activity threshold, and of `raw_mets_w` the time-weighted mean of `physicalEffort` samples; both need the "watch worn" mask from HR (unknown, not 0, when the watch is off).

### Gaps
- Whether Apple Watch records `physicalEffort` all day or mainly during workouts / walking was not verified (Apple's page only says "recorded automatically"); its coverage outside workouts is unknown.
- Fitbit kcal includes basal energy; the mapping of Fitbit "level 1" to an Apple threshold was not calibrated.

## Q4. Activity type from the phone (ActivityEvent / ActivityTransition → CMMotionActivityManager)

### Takeaway
Small, consistent-in-sign gains for valence and arousal from "share of the last 60 min still / on foot" (single features +0.002 to +0.006, mostly 5/5 folds), none from "in vehicle". As a family, transitions (the closest analogue of Core Motion activity segments) give valence +0.0040 ± 0.0029 (4/5) and arousal +0.0010; Activity events give arousal +0.0022 and valence +0.0001. The phone signal is unknown for 16–17 % (transitions) to 40 % (events, 53 % in D-2) of answers. Not worth a new permission on this evidence alone.

### Cited Findings
- Format (probe): `ActivityEvent.csv` = Android activity-recognition results, 8 confidences in 0–1 summing to 1 (Still, Unknown, InVehicle, OnBicycle, OnFoot, Walking, Running, Tilting), median event gap ≈ 15–23 s, 90th percentile 23–223 s; argmax shares ≈ still 45–56 %, unknown 17–31 %, tilting 9–20 %, on foot 6–12 %, vehicle 2–8 %. `ActivityTransition.csv` = one row per transition (`typeEnter`, `typeExit`), median gap 3–15 min, enters ≈ still 32–44 %, walking 39–44 %, vehicle 9–21 % — [probe.txt](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/probe.txt)
- Definitions: H1 per minute = argmax class of the last event, held ≤ 30 min (Unknown / Tilting = "other"); H2 per minute = last entered state, held ≤ 12 h; features = share of known minutes still / on foot (OnFoot + Walking + Running) / in vehicle over the last 30 and 60 min, unknown if < 50 % of the window is known — [extract.py](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/scripts/extract.py)
- Unknown share (D-1 / D-2 / pooled): H1 30 min 0.174 / 0.530 / 0.413, 60 min 0.155 / 0.516 / 0.398; H2 30 min 0.165 / 0.161 / 0.162, 60 min 0.171 / 0.169 / 0.170. No ActivityEvent at all in the last 60 min for 32.9 % of answers (mean known share 0.569); for transitions 14.3 % (mean 0.829) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Δ AUROC vs v1: H1 arousal +0.0022 ± 0.0042 (3/5), valence +0.0001 ± 0.0020 (3/5), stress +0.0014 ± 0.0028 (4/5); H2 arousal +0.0010 ± 0.0022 (3/5), valence +0.0040 ± 0.0029 (4/5), stress +0.0024 ± 0.0049 (3/5); H1 + H2: +0.0021 / +0.0028 / +0.0025 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Best single activity features: arousal `act_still_60` +0.0036 ± 0.0010 (5/5), `act_still_30` +0.0027 ± 0.0013 (5/5); valence `tr_still_60` +0.0058 ± 0.0032 (5/5), `tr_foot_60` +0.0049 ± 0.0022 (5/5), `act_foot_60` +0.0027 ± 0.0012 (5/5); stress `tr_still_60` +0.0020 ± 0.0028 (4/5); vehicle shares −0.0010 to +0.0012 — [LOCAL-SINGLE](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_singles.txt)
- Scored only on answers where H1 is known (18,369): arousal +0.0046 ± 0.0065 (3/5), valence +0.0040 ± 0.0053 (4/5), stress +0.0046 ± 0.0031 (5/5) — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Redundancy: r(`act_foot_30`, `z_log_steps_30`) = +0.487; r(`act_vehicle_30`, `z_log_steps_30`) = +0.048 and with `z_hr_30` +0.024; events vs transitions: vehicle r = +0.783, on foot r = +0.826 — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt)
- Apple: `CMMotionActivityManager` "can ask for notifications when the current type of motion changes or … gather past motion change data"; requires `NSMotionUsageDescription` and a user prompt — [Apple: CMMotionActivityManager](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [Apple: NSMotionUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription)
- Apple: `CMMotionActivity` flags (stationary, walking, running, automotive, cycling, unknown) "aren't mutually exclusive" (e.g. automotive + stationary at a red light), all may be false; each has a `confidence` and a `startDate` — [Apple: CMMotionActivity](https://developer.apple.com/documentation/coremotion/cmmotionactivity), [Apple: confidence](https://developer.apple.com/documentation/coremotion/cmmotionactivity/confidence)
- Apple: `queryActivityStarting(from:to:to:withHandler:)` returns historical activity; "the system stores only the last seven days worth of activity data at most"; delays "of up to several minutes" are expected — [Apple: queryActivityStarting](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/queryactivitystarting(from:to:to:withhandler:))

### Inferences
- Phone activity type is the only new sensor family with a consistent sign, and it is not a copy of the watch (vehicle is uncorrelated with steps and HR); but the effect size (≈ +0.003–0.006 AUROC) is below the fold sd of v1 itself.
- iOS computation: `queryActivityStarting(from: t − 60 min, to: t)`; each `CMMotionActivity` holds from its `startDate` until the next one; per minute take the flag with priority automotive > cycling > running/walking > stationary (handles the non-exclusive flags), drop `confidence == .low` and all-false/unknown items; share = minutes per class / known minutes; unknown if < 50 % of the hour is covered or the query errors (`CMErrorUnknown` = no samples).
- Unknown on iOS has a different meaning: Core Motion keeps recording while the phone lies on a desk, so "phone not carried" shows up as "stationary", not as unknown. EmoPhone's unknown rate (16–40 %) therefore overstates iOS missingness, but the iOS "still" share is contaminated by phone-left-behind time. Only the 7-day history limit matters for references, which these features do not use.

### Gaps
- No data on how often students' iPhones are not carried; the contamination of "stationary" cannot be measured in EmoPhone (Android logging stops differently).
- D-2's low ActivityEvent coverage (53 % unknown) is not explained by the documentation I have.

## Q5. Best combined set, coefficients, and over-fitting check

### Takeaway
The best set is the leanest: v1 + 4 **un-referenced** window values (`raw_hr_30`, `raw_hr_60`, `raw_log_steps_30`, `raw_log_steps_60`), 17 features, no new sensor or permission. Valence gains a robust +0.016 AUROC (5/5 folds, also when the families are chosen inside the training folds: +0.0156 ± 0.0065, 5/5); arousal gains +0.003 to +0.009 depending on how the set is chosen, with fold sd ≈ 0.01 (3–4/5 folds); stress gains nothing. Adding phone activity type and minutes since walking on top brings nothing more; adding all 60 candidates is no better than the 17. Nested CV picks very strong L2 (C ≈ 1e-4 to 3e-3) for v1 and for the larger sets alike, with unchanged AUROC: the larger set does not over-fit visibly, but it does not need the extra features either.

### Cited Findings
**AUROC mean ± sd over the 5 folds; Δ paired vs v1 on the same folds** — [LOCAL-Q5 (20-feature set)](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_q5_P.txt), [LOCAL-Q5 (17-feature set)](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_q5_P0.txt)

| Model | arousal_high | valence_high | stress_high |
|---|---|---|---|
| time only (3), C = 1 | 0.534 ± 0.009 | 0.534 ± 0.004 | 0.543 ± 0.012 |
| v1 (13), C = 1 | 0.563 ± 0.012 | 0.542 ± 0.017 | 0.540 ± 0.011 |
| v1 + raw HR/steps (17), C = 1 | 0.571 ± 0.018, Δ +0.0084 ± 0.0104 (4/5) | 0.559 ± 0.024, Δ +0.0171 ± 0.0086 (5/5) | 0.541 ± 0.019, Δ +0.0004 ± 0.0124 (3/5) |
| v1 + raw HR/steps + `tr_still_60`, `tr_foot_60`, `log_min_since_walk` (20), C = 1 | 0.571 ± 0.016, Δ +0.0079 ± 0.0108 (3/5) | 0.558 ± 0.021, Δ +0.0164 ± 0.0070 (5/5) | 0.541 ± 0.022, Δ +0.0009 ± 0.0144 (3/5) |
| v1 + ALL 47 new candidates (60), C = 1 | 0.572 ± 0.018, Δ +0.0092 ± 0.0126 (3/5) | 0.551 ± 0.022, Δ +0.0091 ± 0.0064 (4/5) | 0.541 ± 0.020, Δ +0.0006 ± 0.0127 (3/5) |
| Forward family selection **inside each training fold** (inner 4-fold GroupKFold, stop when inner gain < 0.002), C = 1 | 0.566 ± 0.017, Δ +0.0034 ± 0.0090 (3/5) | 0.557 ± 0.022, Δ +0.0156 ± 0.0065 (5/5) | 0.536 ± 0.019, Δ −0.0041 ± 0.0125 (3/5) |
| Families picked per outer fold | [R2, G2], [R2], [R2], [R2], [H1] | [R2, R1], [R1, R2], [R2, R1], [R2, R1], [R1] | [R1, R2, C, H2], [C, H2], [C, H2], [H1], [G, R2] |

- The 17- and 20-feature sets were defined after seeing the family results on these same folds (optimistic); the inside-fold forward selection is the honest estimate of "pick the best families", and it reproduces the valence gain exactly and about 40 % of the arousal gain — [LOCAL-Q5](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_q5_P.txt)

**Nested C (L2 strength chosen by inner 4-fold GroupKFold on the training participants, grid 1e-4 … 3)** — [LOCAL-Q5](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_q5_P.txt)

| Model, nested C | arousal_high | valence_high | stress_high |
|---|---|---|---|
| v1 (13) | 0.562 ± 0.010; C = [3e-4, 3e-4, 1e-3, 1e-3, 3e-3] | 0.543 ± 0.017; C = [1e-3, 3e-4, 1e-4, 3e-4, 1e-4] | 0.541 ± 0.011; C = [3e-3, 1e-3, 1e-3, 3e-3, 0.03] |
| v1 + raw HR/steps (17) | 0.570 ± 0.015, Δ +0.0088 ± 0.0098 (4/5); C = [1e-3, 3e-4, 1e-3, 1e-3, 1e-3] | 0.559 ± 0.024, Δ +0.0157 ± 0.0073 (5/5); C = [0.01, 1e-3, 1e-3, 1e-3, 1e-4] | 0.540 ± 0.018, Δ −0.0008 ± 0.0119 (3/5); C = [0.03, 1e-3, 3e-4, 3e-3, 0.03] |
| 20-feature set | 0.570 ± 0.014, Δ +0.0086 ± 0.0107 (3/5); C = [3e-4, 3e-4, 1e-3, 1e-3, 3e-4] | 0.559 ± 0.022, Δ +0.0157 ± 0.0063 (5/5); C = [1e-3, 3e-4, 1e-3, 1e-3, 1e-4] | 0.540 ± 0.021, Δ −0.0002 ± 0.0140 (3/5); C = [3, 1e-3, 3e-4, 0.3, 0.01] |
| ALL (60) | 0.571 ± 0.012, Δ +0.0093 ± 0.0095 (3/5); C = [1e-3, 1e-4, 3e-4, 3e-4, 1e-3] | 0.553 ± 0.024, Δ +0.0098 ± 0.0091 (4/5); C = [3e-4, 3e-4, 1e-4, 1e-3, 1e-4] | 0.539 ± 0.019, Δ −0.0016 ± 0.0128 (3/5); C = [3e-3, 1, 3e-4, 1, 3] |

**Standardized coefficients of the recommended 17-feature set (mean ± sd over the 5 fold models, C = 1), top 9 by |mean|** — [LOCAL-Q5 P0](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_q5_P0.txt)
- arousal_high: `raw_hr_30` +0.138 ± 0.024, `z_hr_15` +0.123 ± 0.012, `sleep_unknown` +0.109 ± 0.022, `z_hr_30` −0.089 ± 0.033, `hour_sin` −0.073 ± 0.009, `hour_cos` +0.049 ± 0.008, `raw_log_steps_60` +0.048 ± 0.018, `raw_hr_60` +0.028 ± 0.031, `raw_log_steps_30` +0.027 ± 0.013.
- valence_high: `raw_log_steps_60` +0.158 ± 0.022, `raw_hr_30` +0.157 ± 0.032, `hour_cos` +0.114 ± 0.010, `z_log_steps_60` −0.099 ± 0.016, `z_hr_30` −0.081 ± 0.022, `sleep_unknown` +0.066 ± 0.031, `weekend` +0.061 ± 0.004, `z_log_steps_15` +0.056 ± 0.008, `z_hr_60` +0.055 ± 0.020.
- stress_high: `raw_hr_60` +0.140 ± 0.020, `hour_cos` −0.119 ± 0.010, `weekend` −0.109 ± 0.009, `z_hr_60` −0.087 ± 0.032, `raw_log_steps_30` −0.065 ± 0.015, `hour_sin` −0.063 ± 0.010, `z_log_steps_30` +0.060 ± 0.021, `raw_log_steps_60` −0.055 ± 0.036, `raw_hr_30` −0.053 ± 0.036.

**Standardized coefficients of the 20-feature set (17 + `tr_still_60`, `tr_foot_60`, `log_min_since_walk`), mean ± sd over the 5 fold models, C = 1** — [LOCAL-Q5](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_q5_P.txt)
- arousal_high: `raw_hr_30` +0.134 ± 0.023, `z_hr_15` +0.117 ± 0.012, `sleep_unknown` +0.105 ± 0.022, `z_hr_30` −0.083 ± 0.030, `hour_sin` −0.072 ± 0.009, `hour_cos` +0.053 ± 0.008, `log_min_since_walk` −0.053 ± 0.010, `raw_hr_60` +0.027 ± 0.025, `z_hr_60` −0.027 ± 0.015, `weekend` −0.025 ± 0.012, `raw_log_steps_60` +0.025 ± 0.017, `z_sleep_min` +0.020 ± 0.010, `tr_foot_60` +0.019 ± 0.020, other |coef| ≤ 0.017.
- valence_high: `raw_hr_30` +0.161 ± 0.030, `raw_log_steps_60` +0.156 ± 0.021, `hour_cos` +0.115 ± 0.011, `z_log_steps_60` −0.098 ± 0.015, `z_hr_30` −0.082 ± 0.022, `sleep_unknown` +0.068 ± 0.032, `weekend` +0.059 ± 0.003, `z_log_steps_15` +0.059 ± 0.007, `tr_still_60` −0.053 ± 0.025, `z_hr_60` +0.051 ± 0.020, `zb_hr_30` −0.049 ± 0.017, `z_sleep_min` +0.036 ± 0.009, `log_min_since_walk` +0.023 ± 0.019, other |coef| ≤ 0.019.
- stress_high: `raw_hr_60` +0.146 ± 0.020, `hour_cos` −0.122 ± 0.010, `weekend` −0.109 ± 0.008, `z_hr_60` −0.082 ± 0.031, `hour_sin` −0.066 ± 0.011, `z_log_steps_30` +0.056 ± 0.019, `raw_log_steps_30` −0.056 ± 0.013, `raw_hr_30` −0.053 ± 0.037, `zb_hr_30` +0.053 ± 0.025, `z_hr_30` −0.001 ± 0.062 (sign-unstable), others smaller.

### Inferences
- Recommendation for the proposal: one change, no new permission — add `raw_hr_30`, `raw_hr_60`, `raw_log_steps_30`, `raw_log_steps_60` (bpm and log steps of the same windows the app already computes, without the personal reference) to the 13 v1 features, and add a second output `valence_high` (the same 17 inputs reach 0.559 for valence vs 0.534 time-only, +0.025, close to v1's margin for arousal, +0.029). Keep stress as a user-chosen situation (no input set beats time-only for stress: 0.541 vs 0.543).
- The positive `raw_hr` coefficients next to negative or small `z_hr_30/60` coefficients show the model uses raw HR as the HR signal whenever the z-scores are imputed; the opposite-sign pairs (raw vs z of the same window) are partly a collinearity artifact and should not be read one by one.
- `sleep_unknown` has a large positive coefficient for arousal (+0.105) and valence (+0.068): unknown nights are associated with higher-than-usual ratings. This is a missingness effect (watch off at night) that will not transfer to Apple Watch users who wear the watch differently; worth flagging, not exploiting.
- The strong regularization chosen by nested CV (C ≈ 3e-4 to 1e-3 instead of 1) costs nothing in AUROC for v1 (0.562 vs 0.563) and makes the 17-feature model's coefficients smaller; with 191 participants the larger sets do not over-fit at C = 1 either, but stress models with 60 features pick unstable C (3e-4 to 3), a sign that there is no stable signal to fit.
- Arousal remains weak: +0.008 at best, with 1–2 folds out of 5 going the other way; before a D-3 confirmation it should be presented as "probably small gain", valence as "consistent gain".

### Gaps
- The 17-feature set has not been tested on D-3 (reserved for the team's single confirmation).
- Arousal's per-fold differences have sd ≈ 0.01; 5 folds cannot separate +0.003 from +0.009. Repeated splits were not run.
- No interaction or non-linear model was tried; gradient boosting was worse than logistic regression on v0 (PROJECT.md §6.5) and was not retested.

## Q6. Coverage and the exact iPhone / Apple Watch computation of each new feature

### Takeaway
Raw (un-referenced) HR and step windows are unknown only when the watch is off (6–8 % of D-1 answers, 36–37 % of D-2 where many participants have empty Fitbit files), versus 43–51 % for every personally referenced z-score; all day-context z-scores are unknown for 57–72 %. Everything in Q1–Q2 and the recommended raw windows can be computed from the HealthKit HR and step samples the app already reads (the "yesterday" family needs 16 days instead of 14); intensity needs new HealthKit read types, activity type needs the Motion & Fitness permission.

### Cited Findings
**Share unknown (D-1 / D-2 / pooled)** — [LOCAL-FAM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/features/out/eval_families.txt); v1 reference values from [docs/PROJECT.md §6.4 table](/Users/clement/Hanyang/Harmony/docs/PROJECT.md) (`z_hr_30` 0.428 / 0.511)

| Feature | Unknown D-1 / D-2 / pooled | iPhone / Apple Watch computation (t = now; windows = whole minutes before the current minute) | New permission? |
|---|---|---|---|
| `raw_hr_30`, `raw_hr_60` | 0.078 / 0.369 / 0.274; 0.064 / 0.362 / 0.264 | mean bpm of HealthKit `heartRate` samples (Apple Watch source), resampled to the first sample of each 5-min clock slot, start date in [t − w, t); unknown without a sample | no |
| `raw_log_steps_30`, `raw_log_steps_60` | 0.077 / 0.369 / 0.274; 0.063 / 0.362 / 0.264 | log(1 + Σ `stepCount` counted by sample start date in [t − w, t)); 0 if ≥ 1 HR sample but no steps; unknown if neither (v1 rule) | no |
| `z_hr_120/240`, `z_log_steps_120/240` | ≈ 0.41 / 0.50 / 0.47 | v1 rule with w = 120 / 240 min (grid 08:00–23:30 of the 14 previous days, ≥ 7 days) | no |
| `z_steps_since6`, `z_hr_since6`, `z_sedhr_since6` | 0.621 / 0.641 / 0.635 | since the last 06:00: log1p(steps), mean HR, mean sedentary HR; known if ≥ 50 % of 5-min slots have an HR or step sample; z vs the same quantity at t − k days, k = 1…14 (≥ 7 known) | no |
| `z_steps_since_wake`, `z_hr_since_wake`, `z_hr_wake60`, `z_steps_wake120` | 0.64–0.68 / 0.72–0.73 / 0.69–0.72 | wake = end of the last Apple Watch `sleepAnalysis` asleep block of the night (the app's `NightSummary`); quantity over [wake, t) (or its first 60 / 120 min); z vs the same elapsed span after wake on the 14 previous days with a known night (≥ 5) | no (sleep already read) |
| `z_steps_yday`, `z_hr_yday`, `z_sedhr_yday`, `z_hr_prev_evening`, `z_steps_prev_evening` | 0.58–0.61 / 0.57–0.60 / 0.57–0.60 | yesterday 00–24 h steps (known if ≥ 60 % of 08–22 h slots worn), mean HR / sedentary HR 08–22 h, 18–24 h HR / steps; z vs the 14 days before yesterday (≥ 7); needs 16 days of samples | no |
| `log_min_since_walk` | 0.116 / 0.403 / 0.309 | log(1 + minutes since the end of the last `stepCount` sample with cadence count / duration ≥ 60 steps/min), capped at 720; unknown if < 50 % of 5-min slots since then worn | no |
| `z_sedhr_30/60/120` | 0.575 / 0.632 / 0.613 (30 min); 0.437 / 0.517 / 0.491 (120 min) | same as v1 HR windows but only `heartRate` samples with `HKMetadataKeyHeartRateMotionContext` = sedentary (1) (Apple: still ≥ 5 min before) | no |
| `zres_hr_30/60` | 0.428 / 0.511 / 0.484; 0.419 / 0.505 / 0.477 | per user OLS of resampled HR on [1, log1p(steps 10 min before), log1p(steps 60 min before)] over the 14 previous days (≥ 100 samples, ≥ 7 days); mean residual in window / residual sd | no |
| `z_mets_15/30/60`, `raw_mets_30/60` | z: ≈ 0.42–0.43 / 0.50–0.51 / 0.48; raw: 0.06–0.07 / 0.36–0.37 / 0.26–0.27 | time-weighted mean of `physicalEffort` (METs) over the window, only where the watch is worn (HR present) | yes: HealthKit read `physicalEffort` (iOS 17+) |
| `lvl1_share_30/60`, `z_lvl1_share_30/60` | raw: 0.071 / 0.366 / 0.270; z: 0.42 / 0.51 / 0.48 | share of worn minutes covered by `activeEnergyBurned` above a light-activity rate (or `appleExerciseTime` minutes for a brisk threshold) | yes: `activeEnergyBurned` / `appleExerciseTime` |
| `act_still/foot/vehicle_30/60` (events) | 0.174 / 0.530 / 0.413 (30); 0.155 / 0.516 / 0.398 (60) | `CMMotionActivityManager.queryActivityStarting(t − w, t)`: each activity holds until the next; priority automotive > cycling > walking/running > stationary; drop low confidence; share of covered minutes; unknown if < 50 % covered | yes: Motion & Fitness (`NSMotionUsageDescription`) |
| `tr_still/foot/vehicle_30/60` (transitions) | 0.165 / 0.161 / 0.162 (30); 0.171 / 0.169 / 0.170 (60) | same query; transitions = changes of the dominant flag | yes: Motion & Fitness |

- Apple: `stepCount` "the system automatically records samples on iPhone and Apple Watch"; "sample data may be condensed and/or coalesced by HealthKit" — [Apple: stepCount](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/stepcount)
- Apple: Core Motion history is limited to "the last seven days worth of activity data at most" — [Apple: queryActivityStarting](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/queryactivitystarting(from:to:to:withhandler:))
- The app already re-reads the raw HR and step samples of the last 14 days (+1 h) at each computation, in memory — [docs/PROJECT.md §6.7](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)

### Inferences
- The recommended raw windows cost no new permission and no extra history: they are intermediate values (`hr_w`, `log_steps_w`) the app's `FeatureBuilder` already computes before z-scoring, so the Swift change is to expose them; the golden fixtures and `model_params.json` would need the 4 extra inputs (PROJECT.md §6 contract: retrain + update fixtures).
- Apple Watch step samples are multi-minute intervals, not per-minute counts like Fitbit; "steps by sample start date" (v1 rule) can shift a few steps across a window edge, and a per-minute cadence (needed for `log_min_since_walk`) must be derived as count / duration — a source of Python ↔ Swift mismatch to cover in fixtures if that feature were kept (it is not recommended).
- If Motion & Fitness were ever added, Core Motion's 7-day limit is irrelevant for the tested features (60-min windows), but a personal reference of activity shares would be capped at 7 days.

### Gaps
- No Apple Watch data were available to measure real unknown rates of the raw windows; EmoPhone's D-2 rate (36 %) is driven by participants with empty Fitbit files and says little about Apple Watch users.
- The share of Apple Watch HR samples tagged sedentary / active / notSet, and whether `physicalEffort` is recorded outside workouts, were not checked on a device.
