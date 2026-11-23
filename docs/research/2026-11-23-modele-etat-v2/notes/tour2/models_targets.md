# Targets, model families and output structures for Harmony's state model (offline experiments, EmoPhone D-1 + D-2)

All numbers below are new measurements from this round, made on EmoPhone D-1 + D-2 only (31,301 ESM answers, 191 participants; D-3 not opened). Setup shared by every experiment:
- Inputs are the 13 v1 features from `data/features/v1_D1.csv` and `v1_D2.csv`, in `ml/train.py` row order. Valence is joined from each wave's `EsmResponse.csv` on (participant = wave_pcode, t = actualTriggerTime, arousal, stress). D-2 has 22 duplicate (pcode, t) pairs. Rows with the same key have identical features, so pairing them by occurrence order is harmless. The recomputed `arousal_high` equals the stored one on every row.
- Labels are `{arousal,valence,stress}_high` = value > the person's own mean (the `label_high` rule). The continuous target is value − person mean.
- Evaluation uses the same 5 GroupKFold splits as `ml/train.py` (`train.folds`). Hyper-parameters are tuned, and stacks fitted, only inside the training participants of each outer fold (inner GroupKFold(4)). Each model is a pipeline of median imputation (unknown stays NaN until imputed by the training median), StandardScaler and the model.
- Results are reported as the fold mean ± sd (np.std over 5 folds). "Paired" means the fold-wise difference (mean ± sd, number of folds > 0).
- Scripts are in `/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/scripts/` and aggregate outputs in `.../v2/models/out/`. Nothing in the repo was modified.

## 1. Valence and stress as targets with the same 13 features (vs time-only)

### Takeaway
The 13 features beat time-only only for arousal (+0.029 AUROC, 5/5 folds). For valence the gain is small and not reliable (+0.008 ± 0.013, 3/5 folds). For stress it is nil (−0.002 ± 0.003): stress is predicted as well by the hour and weekend inputs alone. All three targets sit at AUROC 0.54–0.56.

### Cited Findings
- **Reproduction check.** Calling `ml/train.py`'s own functions on the current CSVs gives time-only 0.534 ± 0.009, time + HR 0.554 ± 0.010, and 13 features 0.563 ± 0.012 AUROC (BA 0.537 ± 0.007). PROJECT.md documents 0.535 ± 0.017, 0.554 ± 0.012, 0.563 ± 0.010 (BA 0.540 ± 0.004). The means match, but some sds differ: the CSVs may have been rebuilt after the documented run (CSV mtime 20 Nov 09:10–09:11), or library versions may differ. This was not investigated further. — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt); docs/PROJECT.md l.596–600
- **Base rates (D-1 + D-2).** arousal_high 0.464, valence_high 0.566, stress_high 0.462. — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt)
- **Results by target (LR C=1, current model):**

  | Target | Time-only AUROC | Time-only BA | 13 features AUROC | 13 features BA | Paired AUROC (13 − time) | Paired BA (13 − time) |
  |---|---|---|---|---|---|---|
  | arousal_high | 0.534 ± 0.009 | 0.506 ± 0.008 | 0.563 ± 0.012 | 0.537 ± 0.007 | +0.029 ± 0.005 (5/5) | +0.031 ± 0.014 (5/5) |
  | valence_high | 0.534 ± 0.004 | 0.500 ± 0.000 | 0.542 ± 0.017 | 0.512 ± 0.002 | +0.008 ± 0.013 (3/5) | +0.012 ± 0.002 (5/5) |
  | stress_high | 0.543 ± 0.012 | 0.509 ± 0.010 | 0.540 ± 0.011 | 0.516 ± 0.005 | −0.002 ± 0.003 (1/5) | +0.007 ± 0.011 (3/5) |

  For valence, the time-only BA of 0.500 ± 0.000 is not an error: every time-only valence probability is above 0.5, so it predicts "high" for everyone. — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt)
- **Standardized LR coefficients** (mean ± sd over the 5 training folds):
  - Arousal: driven by z_hr_15 +0.117 ± 0.014, sleep_unknown +0.123 ± 0.020 and hour_sin −0.080.
  - Valence: driven by hour_cos +0.106, sleep_unknown +0.085, z_hr_60 +0.060, weekend +0.054, z_log_steps_15 +0.054 and z_sleep_min +0.040.
  - Stress: driven by hour_cos −0.113 and weekend −0.109. Its HR and steps coefficients are ≤ 0.045 in absolute value, with sds of the same size.
  - — [q1b_coef.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1b_coef.txt)
- **External context (earlier notes, not re-checked here).** The EmoPhone benchmark's best users-held-out AUROCs are arousal 0.584 ± 0.022, valence 0.576 ± 0.010 and stress 0.554 ± 0.018, from hundreds of phone + wearable features. — [EmoPhone arXiv 2609.16581, Table 6, via earlier notes](https://arxiv.org/html/2609.16581v1)

### Inferences
- With watch-only features, valence is a weaker but usable output. Its signal is mostly time of day and weekend plus some HR-60/steps/sleep, and it is not reliably better than time-only. Stress, as a separate output, adds nothing over the clock. Together with the earlier finding that stress ≈ −valence within a person, this argues against a stress output.
- `sleep_unknown` has the largest arousal coefficient. Missingness itself carries signal: answers on days with no measured night are more often "above usual". The input/feature research should check whether this is a behaviour proxy (watch not worn) or an artefact, before it is "sold" as a body signal.

### Gaps
- No D-3 confirmation (reserved by design).
- The small sd discrepancy between the reproduced and documented baseline was not traced.

## 2. "Body mode": z_hr_30 known vs the app's real mixed behaviour

### Takeaway
When z_hr_30 is known (51.6% of answers), the 13-feature arousal model reaches 0.573 ± 0.013 AUROC, against 0.524 for time-only on the same rows (+0.049 ± 0.013, 5/5). The app's mixed rule (13 features when z_hr_30 is known, time-only otherwise) scores 0.561 ± 0.011 overall. That is the same as using the 13-feature model everywhere (−0.002 ± 0.005) and +0.027 over time-only. For valence, body mode gives +0.018 ± 0.016 over time-only (4/5 folds). For stress it gives nothing.

### Cited Findings
- z_hr_30 is known for 0.516 of D-1 + D-2 answers. Base rates on known/unknown rows: arousal 0.443 / 0.487, valence 0.551 / 0.581, stress 0.473 / 0.451. — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt)
- **Arousal:**
  - On known rows: 13-feature model trained on all rows 0.573 ± 0.013; trained on known rows only 0.572 ± 0.012 (paired −0.001 ± 0.002); time-only 0.524 ± 0.008. Paired 13 − time: +0.049 ± 0.013 (5/5).
  - On unknown rows: time-only 0.547 ± 0.016, 13 features 0.550 ± 0.020.
  - Mixed: AUROC 0.561 ± 0.011 and BA 0.518 ± 0.006. Paired vs 13 everywhere −0.002 ± 0.005 (1/5); vs time-only +0.027 ± 0.007 (5/5). — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt)
- **Valence:**
  - On known rows: 13 features 0.553 ± 0.012 vs time-only 0.536 ± 0.016, paired +0.018 ± 0.016 (4/5). The known-rows-only model gives 0.553 ± 0.011.
  - On unknown rows: time-only 0.534 vs 13 features 0.527.
  - Mixed: 0.544 ± 0.013; vs time-only +0.010 ± 0.010 (4/5). — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt)
- **Stress:** on known rows, 13 features 0.541 ± 0.020 vs time-only 0.544 ± 0.020 (paired −0.003 ± 0.001, 0/5). Mixed 0.540 ± 0.012. — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt)
- **Why the mixed BA is lower.** Mixed BA for arousal (0.518) is below the 13-feature BA (0.537) because the 95th percentile of time-only arousal probabilities is 0.503. Time-only almost never says "above usual" at the 0.5 threshold. — [q1_q2.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q1_q2.txt); [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)

### Inferences
- "Body mode" is the honest headline for the presentation: when the watch gives a recent heart rate, arousal discrimination is about 0.57 vs 0.52 from the clock (5/5 folds). The app's switch to time-only costs essentially nothing compared with always using the 13-feature model.
- A model trained only on body rows brings nothing (±0.001). Keep one model trained on all rows.
- The fallback produces probabilities that almost never cross 0.5 for arousal. Any threshold-based UI text should use a rank or base-rate threshold (see Q5), not 0.5.

### Gaps
- "Known" here means z_hr_30 known, which needs both HR in the 30-min window and a ready 14-day reference. The two causes were not separated.
- Apple Watch sampling density in real use was not simulated beyond the 5-min resampling already in v1.

## 3. Model families on the same 13 inputs

### Takeaway
No family beats plain LR C=1 by more than the fold sd of AUROC on any target. Arousal: every alternative is +0.000 or worse (HGB −0.005 ± 0.004, 0/5). Valence: the best is the mean ensemble at +0.005 ± 0.004 (4/5) against a fold sd of ≈0.02. Stress: the stack gives +0.008 ± 0.004 (5/5), consistent across folds but below the AUROC fold sd (≈0.01) and only +0.006 over time-only. Nested tuning always picked near-maximum shrinkage: the signal is weak and nearly linear.

### Cited Findings
- **Families compared** (all on the 13 v1 features, nested-tuned inside training participants):
  - LR with C tuned in {1e-3 … 3}.
  - LR + 8 hand-picked interactions: hour_sin/cos × z_hr_30, hour_sin/cos × z_log_steps_30, z_hr_30 × z_log_steps_30, hours_since_wake × z_hr_30, weekend × hour_sin/cos.
  - LR with all degree-2 terms.
  - HistGradientBoosting: depth {2,3,5} × iterations {50,150,400}, lr 0.05, min leaf 100.
  - MLP: hidden {(8), (16), (32,16)} × alpha {0.01, 0.1, 1, 3}.
  - Mean ensemble of the tuned LR, HGB and MLP.
  - Stack: a meta-LR on the inner out-of-fold logits of those three. — [q3_q5_q6_families.py](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/scripts/q3_q5_q6_families.py)
- **AUROC by family** (paired vs LR C=1 in parentheses):

  | Model | Arousal (LR C=1: 0.563 ± 0.012) | Valence (LR C=1: 0.542 ± 0.017) | Stress (LR C=1: 0.540 ± 0.011) |
  |---|---|---|---|
  | LR tuned C | 0.562 ± 0.011 (−0.000 ± 0.001) | 0.543 ± 0.018 (+0.001 ± 0.002) | 0.541 ± 0.011 (+0.000 ± 0.001) |
  | LR + 8 interactions | 0.562 ± 0.011 (−0.001 ± 0.002) | 0.543 ± 0.018 (+0.001 ± 0.003) | 0.543 ± 0.009 (+0.003 ± 0.002, 4/5) |
  | LR all pairwise | 0.560 ± 0.011 (−0.003 ± 0.003) | 0.542 ± 0.016 (+0.000 ± 0.004) | 0.543 ± 0.008 (+0.003 ± 0.007) |
  | HistGradientBoosting | 0.558 ± 0.012 (−0.005 ± 0.004, 0/5) | 0.545 ± 0.022 (+0.004 ± 0.009) | 0.547 ± 0.010 (+0.007 ± 0.004, 4/5) |
  | MLP | 0.562 ± 0.011 (−0.000 ± 0.003) | 0.544 ± 0.018 (+0.002 ± 0.002, 4/5) | 0.544 ± 0.008 (+0.003 ± 0.005) |
  | Mean ensemble | 0.562 ± 0.011 (−0.000 ± 0.002) | 0.546 ± 0.020 (+0.005 ± 0.004, 4/5) | 0.547 ± 0.010 (+0.007 ± 0.003, 5/5) |
  | Stack | 0.563 ± 0.011 (+0.000 ± 0.002) | 0.541 ± 0.018 (−0.001 ± 0.004) | 0.548 ± 0.009 (+0.008 ± 0.004, 5/5) |

  Every arousal variant is +0.024 to +0.029 over time-only (5/5). Stress variants are at most +0.006 ± 0.005 over time-only. — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)
- **Chosen hyper-parameters** (per outer fold, picked on inner folds only):
  - LR C = 0.001, the lowest value in the grid, in 10/10 arousal/valence folds and 4/5 stress folds of the tuned LR.
  - HGB: depth 2, 50 iterations in 9/10 arousal/valence folds.
  - MLP: alpha 1–3, the top of the grid, for arousal/valence.
  - — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)
- **External context (earlier notes, not re-checked here).** The EmoPhone paper's 29 models on about 10k features reach about 0.584 for arousal. — [EmoPhone arXiv 2609.16581 via earlier notes](https://arxiv.org/html/2609.16581v1)

### Inferences
- Model capacity is still not the bottleneck. For arousal, plain LR is the best choice and costs nothing in Core ML.
- A nonlinear stress model buys about +0.007 AUROC, but stress itself is barely above the clock. That is not worth an extra output or a heavier model.
- The tuning picked the edge of the grids, which suggests the models want to be as simple as possible. Wider grids would not change the conclusion: tuned LR is within ±0.001 of C=1.

### Gaps
- Only the v1 inputs were tested. Families could matter more once richer inputs exist (other researcher's scope).
- MLP results use one seed in the Q3 run. The 3-seed average in Q4 gives the same picture.
- HGB was run on median-imputed inputs (as required), not with native NaN handling.

## 4. Multiple outputs: separate, multi-task, chains, person-centred regression

### Takeaway
Joint training does not improve any target in a way that matters. The multi-task MLP is at most +0.002 AUROC over single-task MLPs (valence, 5/5 folds). Classifier chains are exactly neutral: with LR the upstream logit is a linear function of the same inputs, and with HGB they give ±0.001. Person-centred regression matches the classifiers on AUROC, slightly improves Spearman for arousal (+0.009 ± 0.007, 5/5), and gives a graded output, but with R² ≈ 0.005–0.016. The one large gain comes from an answered in-app item used as an input: +0.07 to +0.15 AUROC on another target.

### Cited Findings
- **Setup:** 3-seed-averaged MLPs, tuned on inner folds. The multi-task MLP (one network, 3 sigmoid outputs) is tuned on the mean inner AUROC of the three targets. HGB is fixed a priori (depth 3, 150 iterations). Ridge alpha is tuned on inner AUROC. — [q4_multioutput.py](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/scripts/q4_multioutput.py)
- **(a) Separate models:** LR C=1 gives arousal 0.563 ± 0.012, valence 0.542 ± 0.017, stress 0.540 ± 0.011. Single-task MLP gives 0.562 ± 0.010, 0.544 ± 0.018, 0.544 ± 0.010. — [q4.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4.txt)
- **(b) Multi-task MLP:**

  | Target | AUROC | Paired vs single-task MLP | Paired vs LR C=1 |
  |---|---|---|---|
  | Arousal | 0.563 ± 0.012 | +0.001 ± 0.002 (2/5) | |
  | Valence | 0.546 ± 0.019 | +0.002 ± 0.001 (5/5) | +0.004 ± 0.003 (5/5) |
  | Stress | 0.543 ± 0.009 | −0.001 ± 0.003 | |

  The chosen trunk was mostly (32,16) with alpha 1. — [q4.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4.txt)
- **(c) Chains and cross-target stacking** (upstream predictions from inner grouped out-of-fold models):
  - LR chain A→V→S vs LR separate: valence −0.000 ± 0.000, stress −0.000 ± 0.000.
  - LR cross-target stack: −0.001 to −0.000.
  - HGB chain or stack vs HGB separate: −0.001 to +0.000. — [q4.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4.txt)
- **(d) Person-centred continuous target:**

  | Model | Target | AUROC (paired vs LR) | Spearman (paired vs LR) | R² | Predicted 5–95% (scale points, −3..+3) | BA (threshold 0) |
  |---|---|---|---|---|---|---|
  | Ridge | Arousal | 0.559 ± 0.009 (−0.004 ± 0.009) | 0.112 ± 0.009 vs 0.102 (+0.009 ± 0.007, 5/5) | 0.015 ± 0.003 | −0.28 to +0.29 | 0.543 ± 0.009 |
  | Ridge | Valence | 0.545 ± 0.008 (+0.003 ± 0.011) | 0.081 vs 0.068 (+0.013 ± 0.016, 4/5) | 0.005 ± 0.004 | | |
  | Ridge | Stress | 0.541 ± 0.011 | | 0.006 | | |
  | HGB regressor | Stress | 0.551 ± 0.010 (+0.010 ± 0.011, 4/5) | | | | |

  — [q4.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4.txt)
- **In-app question upper bound** (one answered item added to the 13 features; LR C=1; answer coded raw or minus the person's past-only mean). This is an upper bound because the answer comes from the same survey as the target:
  - Valence: + arousal answer 0.626 ± 0.020 (+0.084 ± 0.023, 5/5); + stress answer 0.679 ± 0.016 (+0.138 ± 0.006, 5/5).
  - Arousal: + valence answer 0.644 ± 0.029 (+0.082 ± 0.023, 5/5); + stress answer −0.003.
  - Stress: + valence answer 0.693 ± 0.019 (+0.153 ± 0.014, 5/5); + arousal answer −0.003 to +0.005.
  - 96.9% of answers have ≥ 5 earlier answers for the past-only mean. — [q4b.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4b.txt); [q4.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4.txt)
- **External context (earlier notes).** No published in-the-wild, users-held-out test of multi-task arousal + valence + stress was found. — [modeling_and_benchmarks.md](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/research_notes/Exploiter%20EmoPhone%20et%20autres%20datasets/modeling_and_benchmarks.md)

### Inferences
- For "more outputs", the cheapest honest structure is separate small LRs per output on the same inputs. A shared multi-task network or a chain adds complexity for ≤0.004 AUROC.
- A chain is only useful when the upstream input is new information (an answered question), not a model prediction from the same inputs.
- Person-centred regression is attractive for presentation: it outputs "how much above or below usual" in scale points and gives the same ranking quality. It does not solve compression: 90% of predictions fall within ±0.3 of a 7-point scale.
- The in-app question is where "combined models" pay. One positivity/stress question is worth far more for the other targets than all watch features: +0.08 to +0.15 vs +0.008 for valence. The arousal and stress answers are nearly unrelated to each other.

### Gaps
- The question analysis is an upper bound. The answer comes from the same survey and moment as the target, so shared-method variance is included. Compliance, answer burden, and drift after repeated questions were not modelled.
- Ordinal models were not tested.

## 5. Probability spread and calibration; per-person rank of e0

### Takeaway
Every variant produces compressed probabilities: for arousal LR, 5–95% = 0.357–0.553 and IQR 0.43–0.51. Brier is only about 1% below the base-rate predictor (0.246 vs 0.249). ECE is about 0.02 for arousal and stress and about 0.04 for valence, the latter driven by fold-level base-rate shifts. No family widens the spread materially. A per-person, past-only rank of the predictions spreads e0 almost uniformly (5–95% = 0.03–0.98) at a small, non-significant AUROC cost (−0.005 ± 0.010). After about one day of answers (≥ 7 past predictions), 95.7% of moments have a rank.

### Cited Findings
- **Pooled out-of-fold percentiles (5/25/50/75/95):**
  - Arousal: time-only 0.402/0.440/0.473/0.492/0.503; LR C=1 0.357/0.428/0.467/0.508/0.553; HGB 0.376/…/0.522; MLP 0.373/…/0.532; stack 0.365/…/0.539; LR all pairwise 0.344/…/0.543.
  - Valence: LR 0.486/0.538/0.566/0.597/0.637.
  - Stress: LR 0.392/0.435/0.468/0.492/0.516. — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)
- **Brier:**

  | Target | Model Brier | Base-rate Brier |
  |---|---|---|
  | Arousal | 0.246 ± 0.001 for every 13-feature variant | 0.249 ± 0.001 |
  | Valence | 0.245 ± 0.003 | 0.246 ± 0.004 |
  | Stress | 0.247–0.248 | 0.249 |

  — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)
- **ECE (10 bins):** arousal 0.018–0.022, valence 0.039–0.041 (sd ≈ 0.017), stress 0.018–0.022, across all variants. The multi-task MLP gives 0.018 / 0.041 / 0.015. — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt); [q4.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q4.txt)
- **Per-person past-only rank** (rank of the current OOF probability among the same person's strictly earlier predictions at earlier ESM moments):
  - Coverage: 0.957 of rows have ≥ 7 past predictions, 0.878 have ≥ 20.
  - Arousal LR: rank 5/25/50/75/95 = 0.03/0.23/0.49/0.78/0.98, vs raw 0.356/0.427/0.466/0.508/0.555 on the same rows. Pooled AUROC: raw 0.563 ± 0.012, rank 0.558 ± 0.007, paired −0.005 ± 0.010 (2/5). Mean within-person AUROC: 0.562 raw vs 0.558 rank. With ≥ 20 past predictions: −0.006 ± 0.010.
  - Valence LR: rank 0.02/0.23/0.52/0.80/0.99; paired −0.005 ± 0.012 (≥ 7), −0.002 ± 0.013 (≥ 20).
  - Stress LR: −0.000 ± 0.007.
  - HGB and stack: rank − raw between −0.005 and +0.003.
  - — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)

### Inferences
- The compression is real information, not a bug: the model is only slightly better than the base rate. Feeding raw p to the queue as e0 means e0 barely moves (±0.1 around 0.47). The per-person rank is the simplest way to make e0 use the full energy range. It keeps ranking quality within noise, is past-only, needs no retraining, and lives on-device.
- The rank should be described as "relative to your recent moments", not as a calibrated probability.
- Recalibration such as Platt or isotonic would not widen the spread meaningfully, because the models are already near-calibrated (ECE ≈ 0.02) and close to the base rate.

### Gaps
- History here is predictions at past ESM moments (~7/day). In the app, history would be the app's own past predictions at whatever times it scores. Their distribution may differ (e.g., more night or idle moments). A grid-based history was not simulated.
- The minimum history (7 vs 20) and the cold-start fallback (e.g., 0.5 or raw p) were not optimised.

## 6. A 2-D state (energy × positivity): quadrant confusion

### Takeaway
A 2-D starting point is not meaningful beyond the energy diagonal. The arousal and valence predictions are strongly correlated with each other (Spearman 0.71), while the true labels are only weakly correlated (phi 0.225). The models collapse onto the "low/low vs high/high" diagonal. Quadrant accuracy is 0.31–0.32 vs a chance level of 0.27–0.28 (kappa ≈ 0.05). The off-diagonal quadrants (calm-positive, tense) are predicted with precision equal to their base rate.

### Cited Findings
- **True quadrant shares** (D-1 + D-2): lowA-lowV 0.288, lowA-highV 0.248, highA-lowV 0.146, highA-highV 0.318. — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)
- **Correlation of the two axes.** OOF LR C=1: Spearman(p_arousal, p_valence) = 0.713 (tuned LR 0.754, HGB 0.687, stack 0.632; time-only 0.551). True labels: phi 0.225. Spearman of p with the centred true value: arousal 0.103, valence 0.065. — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt); [q6b.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q6b.txt)
- **Quadrant agreement, LR C=1, by thresholding rule:**

  | Rule | Accuracy | Chance | Kappa | Opposite-quadrant rate (chance) | Notes |
  |---|---|---|---|---|---|
  | 0.5 | 0.294 ± 0.016 | 0.273 | 0.029 | 0.181 (0.204) | highA-lowV predicted 0.000 of the time, lowA-highV 61% |
  | Training base rate | 0.315 ± 0.012 | 0.276 | 0.054 | 0.242 (0.278) | predicted shares 0.368 / 0.111 / 0.137 / 0.384 |
  | Per-person past rank > 0.5 | 0.313 ± 0.012 | 0.276 | 0.051 | | 87.8% of rows |

  Tuned LR, HGB and stack give the same picture (accuracy 0.307–0.317, kappa 0.048–0.054). — [q3_q5_q6.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q3_q5_q6.txt)
- **Precision P(true quadrant | predicted quadrant)** (base-rate thresholds, 13 features):

  | Predicted quadrant | Precision | Base rate |
  |---|---|---|
  | lowA-lowV | 0.333 | 0.288 |
  | lowA-highV | 0.258 | 0.248 |
  | highA-lowV | 0.160 | 0.146 |
  | highA-highV | 0.368 | 0.318 |

  — [q6b.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q6b.txt)
- **Independent valence information.**
  - AUROC of p_valence for valence_high within true arousal strata: 0.530 ± 0.026 (arousal low) and 0.536 ± 0.018 (arousal high).
  - Off-diagonal score (logit p_V − logit p_A), calm-positive vs tense, on rows where the two labels differ: 0.538 ± 0.028 with 13 features vs 0.544 ± 0.017 with time-only. — [q6b.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/models/out/q6b.txt)

### Inferences
- From watch + time alone, the second axis mostly re-expresses the first ("activated, good moment" vs "flat, low moment"). A 2-D e0 would mostly place users on the diagonal, and its off-diagonal placements are no better than chance. A 2-D start is defensible only if positivity comes from an answered question (Q4: +0.08 to +0.14 AUROC), or as a weak tilt with a fixed, small weight.
- If the team wants a 2-D picture for the presentation, the honest version is: energy from the model (body mode), positivity from the user's one-tap answer or their skip/like behaviour, with the model's valence only as a weak prior.

### Gaps
- The 2-D analysis uses binary person-mean quadrants. A continuous 2-D error, such as distance in rank space, and its effect on the queue ordering were not measured.
- D-3 was not used, so cross-wave stability of the diagonal collapse is unknown.
