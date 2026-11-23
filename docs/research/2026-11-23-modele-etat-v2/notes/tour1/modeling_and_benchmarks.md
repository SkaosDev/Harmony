# Modelling and benchmarks: how well can self-reported arousal / valence / stress / mood be predicted from passive wearable (+ phone) data in daily life, and which approaches really help (state as of Nov 2026)

Reference point used throughout (team's own results, not a literature source): StandardScaler + logistic regression, 13 hand-crafted watch features, target = arousal above the person's own mean, AUROC 0.563 (5-fold group CV) and 0.576 (held-out wave); time-only baseline 0.534; HistGradientBoosting 0.558; stress as target about 0.54.

Protocol abbreviations: LOSO = leave-one-subject-out; group CV = folds that hold out whole users; "temporal / within-user" = the same users appear in train and test (chronological split); "random split" = samples shuffled, so the same users are in train and test; "hybrid" = part of the test user's labelled data is added to training.

## 1. Benchmarks: what do published studies get for momentary or daily self-reports from consumer wearables (+ phone) in the wild?

### Takeaway
Under subject-independent evaluation, in-the-wild momentary affect prediction sits at AUROC about 0.52-0.60 (macro-F1 about 0.43-0.54). The EmoPhone benchmark (the team's own dataset, the same per-user-mean target) puts the best cross-user arousal model at 0.584 and the best held-out-wave arousal model at 0.564. The team's 0.563 / 0.576 is already at that level. Numbers of 0.75-0.98 come from within-subject or "hybrid" splits, or from lab-induced stress, and cannot be compared with these.

### Cited Findings
**EmoPhone multi-wave benchmark (arXiv 2609.16581, Sept 2026). The same dataset and target as the team's.**
- 3 waves: D-1/D-2/D-3 recruited 102/112/114 participants (92/99/106 kept after quality control), with 10,259 / 21,042 / 21,838 ESM responses, i.e. 6.70 / 6.99 / 7.03 responses per active day. Sensors: Fitbit Inspire HR (heart-rate file at 1 Hz, steps per minute) plus the Android phone through ABC Logger — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Binary targets use a user-specific mean split: a response above that participant's own mean for that label is HIGH. This is the team's definition — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Three protocols: (a) "temporal" = per-user chronological 60/20/20 split, within-user. (b) "within-wave" = stratified 5-fold split grouped by user, no user overlap, with per-user z-scoring of features. (c) "cross-wave" = train on one or two waves, test on a held-out wave (9 directions) — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Best AUROC per label (Table 6), mean ± SD:

| Label | Temporal (within-user) | Within-wave (users held out) | Cross-wave (wave held out) |
|---|---|---|---|
| Stress | XGB 0.628 ± 0.016 | SHOT 0.554 ± 0.018 | MASF 0.525 ± 0.013 |
| Arousal | XGB 0.609 ± 0.035 | MCD 0.584 ± 0.022 | IRM 0.564 ± 0.020 |
| Valence | XGB 0.601 ± 0.031 | MCC 0.576 ± 0.010 | Fish 0.541 ± 0.008 |
| Disturbance | SAINT 0.555 ± 0.005 | SHOT 0.558 ± 0.009 | CSD 0.537 ± 0.012 |
| Mean | 0.598 | 0.568 | 0.542 |

  — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- The authors describe a "label-dependent difficulty ladder". Stress shows the biggest fall from the temporal to the cross-wave setting. Arousal is the most robust shared label under user and wave shift — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Within-user (temporal) results on D-3-only labels: angry 0.673, sad 0.607, content 0.601, cheerful 0.599, happy 0.593, relaxed 0.585, anxious 0.575, depressed 0.548 — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Features: the benchmark uses the Zhang et al. (2024) pipeline over phone and wearable streams, with immediate-past windows of 15 and 30 min plus longer windows. Prior ESM labels are not used as features — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)

**K-EmoPhone (Scientific Data 2023; 77 students, 7 days, 5,582 ESM responses).**
- LOSO over the 47 participants left after preprocessing, XGBoost / random forest, labels binarised at a fixed threshold of 0 (not the per-user mean). Macro-F1 0.53 for valence and 0.54 for arousal. The authors call this "comparable" to lab LOSO results such as DEAP (macro-F1 0.60 valence / 0.53 arousal) and to a peripheral-physiology dataset (0.39 / 0.38) — [K-EmoPhone, Sci Data](https://www.nature.com/articles/s41597-023-02248-2)

**Zhang et al., "A Reproducible Stress Prediction Pipeline with Mobile Sensor Data" (IMWUT 8(3), Sept 2024; K-EmoPhone + a new DeepStress dataset).**
- K-EmoPhone stress, LOSO: baseline AUC-ROC 0.518; 0.556 after dropping each user's first day; best sensor-only 0.580 (adds features aggregated over the whole of yesterday). Previous ESM label alone gave 0.570; sensors + previous label gave 0.568 — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- Binarising at each user's own mean gave AUC 0.524, against 0.539 with one global mean. Per-user z-scoring of features gave 0.536, against the 0.556 baseline 2 — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- DeepStress (n = 24, about 566 labels per user): 0.563 AUC with an SVM on sensors only, 0.616 when the last ESM label is added as a feature. The authors name "overfitting and distribution shifts across users" as the main limits — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)

**SWEET (Smets et al., npj Digital Medicine 2018; 1,002 office workers, 5 days, chest patch + wrist sensor).**
- Random forest, LOSO, 3-class self-reported stress: mean F1 0.43 (95% CI 0.05-0.86), against 0.36 for always predicting the majority class. Per subject, 216 had F1 < 0.33 (chance), 249 were in between and 103 had F1 > 0.66. The authors say the performance of the general model "does not allow use in practice yet" — [Smets et al. 2018](https://www.nature.com/articles/s41746-018-0074-9)

**Meegahapola et al. (IMWUT 6(4), Dec 2022; 678 students, 8 countries, 329K self-reports; phone sensing only, no wearable).**
- Population-level models (leave about 20% of users out, i.e. group 5-fold), country-specific, two-class valence, AUROC: China .51, Denmark .41, India .46, Italy .55, Mexico .62, Mongolia .49, Paraguay .48, UK .56 — [Meegahapola et al. 2022](https://arxiv.org/pdf/2211.03009)
- "Hybrid" models, which add 50% of each test user's data (stratified, not chronological) to training, reach .78-.98. Tested in a new country: .46-.55 population-level and .66-.73 hybrid — [Meegahapola et al. 2022](https://arxiv.org/pdf/2211.03009)
- The same paper cites earlier work: 66% accuracy for population models, about 75% for hybrid and 94% for user-level models (LiKamWa et al.). A model trained on student populations (0.82) fell to AUROC 0.57 on a US-wide population — [Meegahapola et al. 2022](https://arxiv.org/pdf/2211.03009)

**GLOBEM (NeurIPS 2022 Datasets & Benchmarks; 4 yearly cohorts of 155 / 218 / 137 / 195 students; depression detection from phone + Fitbit).**
- Balanced accuracy, single dataset (past→future) vs leave-one-dataset-out: Chikersal et al. 0.649 → 0.536; Reorder (best overall) 0.626 → 0.547; ERM-Transformer 0.584 → 0.509; ERM-LSTM 0.565 → 0.512; Saeb et al. 0.557 → 0.536. The authors conclude that "these algorithms can barely generalize across datasets" — [GLOBEM](https://arxiv.org/pdf/2211.02733)

**Daily (next-day) mood/stress, within-subject split.**
- Jaques et al. 2017 (SNAPSHOT, 69 students, 1,895 days, 0-100 scales, 60/20/20 split of samples with the same people in train and test). Next-day MAE for mood / stress / health: GP 16.0 / 17.2 / 16.7; neural network 15.0 / 17.1 / 16.5; personalised MTL-NN 13.0 / 14.1 / 12.9. They note that earlier mood classifiers reached "55-76%" accuracy, and that MoodScope rose from 66% (generic) to 93% (person-specific, about two months of labels) — [Jaques et al. 2017](http://proceedings.mlr.press/v66/jaques17a/jaques17a.pdf)

**Lab versus field contrast, with the same model and subject-wise splits.**
- Pulse-PPG (raw 50 Hz PPG foundation model, field-trained): binary stress AUROC on WESAD (lab) 0.969 with a linear probe and 0.985 fine-tuned; on MOODS (field, smartwatch) 0.569 and 0.591 — [Pulse-PPG](https://arxiv.org/pdf/2502.01108)
- The authors: "high accuracies for stress classification has been reported on lab data … but they do not generalize to the field settings", and "models trained using larger field datasets report low performance" — [Pulse-PPG](https://arxiv.org/pdf/2502.01108)

**Reviews.**
- Systematic review of ML stress monitoring from wearables (arXiv 2209.15137): only a minority of the 33 studies used LOSO; most used 10-fold CV — [Systematic review](https://arxiv.org/pdf/2209.15137)
- 2021-2025 review of multimodal wearable stress detection: LOSO "is hardly employed". It concludes that "current models, despite their accuracy, are not yet suitable for real-world implementation" (seen through the search snippet only) — [ResearchGate review](https://www.researchgate.net/publication/400176932_Multimodal_Wearable-Based_Stress_Detection_Using_Machine_Learning_A_Systematic_Review_of_Validation_Protocols_and_Generalization_Gaps_2021_-_2025)

### Inferences
- The team's arousal model (0.563 group CV, 0.576 held-out wave, 13 watch-only features) matches the best published EmoPhone cross-user arousal (0.584 ± 0.022 within-wave) within one standard deviation. That benchmark used hundreds of phone + wearable features, 29 model families and Optuna tuning. The team's model sits above the best cross-wave arousal average (0.564), though the team reports one direction and the benchmark averages nine. On this dataset and target, there is no evidence of a large unexploited margin.
- Arousal is the best-supported target. In EmoPhone it beats valence and stress under user and wave shift. This matches the team's stress result of about 0.54.
- Per-user-mean targets are harder than global thresholds (Zhang: 0.524 vs 0.539). They are still the right choice for "more or less activated than usual", but they remove the easy between-person signal. Do not compare them with studies that use global thresholds.
- Realistic ceilings for population models (my judgement): AUROC about 0.55-0.60 for momentary arousal; about 0.52-0.56 for stress or valence across cohorts. Anything above 0.65 in the literature almost always comes from within-subject, hybrid, random-split or lab data.

### Gaps
- I did not find extracted AUROC benchmarks for momentary affect on LifeSnaps, TILES-2018, Tesserae or StudentLife under LOSO. (TILES and Tesserae papers mostly report correlations or daily targets; I did not verify their numbers, so none are given.)
- The EmoPhone benchmark has no logistic-regression baseline and no wearable-only feature ablation, so the team's 13-feature watch-only result has no exact published counterpart.
- The full text of the 2021-2025 multimodal review was not read; no pooled LOSO numbers were found.

## 2. Model complexity: do deep or sequence models, or more hand-crafted features, beat LR / boosting under leave-subject-out?

### Takeaway
No. When users or cohorts are held out, every model family (boosted trees, MLP, ResNet, Transformers for tabular data, TabNet, SAINT) lands within about 0.02-0.04 AUROC. Boosted trees win only in the within-user setting. Domain-generalisation and adaptation methods add about +0.01 within a cohort and nothing measurable across cohorts. More features bring small gains (+0.02 AUC), mostly from longer time windows.

### Cited Findings
- EmoPhone within-wave (users held out), mean AUROC over 20 (label × wave) rows (Table 26, ranks 7-29): DAN 0.566, MixStyle 0.559, GroupDRO 0.558, MLP 0.554, TabTransformer 0.546, ResNet 0.541, SAINT 0.537, DCN 0.535, FT-Transformer 0.535, XGB 0.519, TabNet 0.519, LightGBM 0.518 — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- EmoPhone within-wave family means over the 4 shared labels: unsupervised domain adaptation 0.570, domain generalisation 0.560, plain baselines 0.556. DG objectives "do not consistently improve over plain MLP" when each user is a domain — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- EmoPhone cross-wave ranking (Table 35, ranks 6-28): VREx 0.537, GroupDRO 0.537, MASF 0.536, XGB 0.535, LightGBM 0.533, FT-Transformer 0.531, SAINT 0.531, MLP 0.524, TabTransformer 0.523, TabNet 0.505. Family means fall within a 0.013 AUROC band. Multi-source pooling gives "modest, label-dependent gains", which go mostly to the baseline models — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- EmoPhone within-user (temporal): "gradient-boosted trees (XGBoost, LightGBM) lead in most cells", with neural tabular models competitive on a handful — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- GLOBEM: deep ERM models (1D-CNN 0.568, LSTM 0.565, Transformer 0.584 single-dataset) did not beat the hand-crafted Chikersal et al. pipeline (0.649). All of them fell to about 0.50-0.55 cross-dataset — [GLOBEM](https://arxiv.org/pdf/2211.02733)
- Zhang et al. 2024 (K-EmoPhone, LOSO): the model type has "some … impact though limited". Tuning model complexity, regularisation and early stopping brought only a "minor improvement" (DeepStress 0.537 after tuning). Adding yesterday's whole-window features raised AUC from 0.556 to 0.580. Changing the immediate-past window (5 / 10 / 30 / 45 min) moved AUC between 0.518 and 0.546 — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- OpenMHC (Apple HealthKit data, 11,894 participants, held-out participants): "carefully tuned classical baselines like XGBoost remain highly competitive"; "well-crafted simple models remain highly competitive with, and often outperform, more complex architectures". On the 5 mental well-being outcomes, the skill score against a linear / logistic reference (age, sex, BMI + hourly mean/SD) was LSM-2 reimplementation +1.6, MultiRocket +1.6, WBM reimplementation -2.6, XGBoost (495 hand-crafted features) -6.7, GRU-D -7.1. The confidence intervals are about ±5, so no method clearly beats the linear model on these targets — [OpenMHC](https://arxiv.org/pdf/2607.16235)

### Inferences
- The team's HistGradientBoosting result (0.558 vs LR 0.563) is exactly what the literature predicts. In cross-user settings, boosted trees fit person-specific idiosyncrasies that do not transfer. In EmoPhone, XGB/LGB rank near the bottom within-wave even though they rank first within-user.
- A deep sequence model on minute-level HR is unlikely to gain more than about 0.01-0.02 AUROC, which is inside the fold-to-fold SD (about 0.02). It would cost Core ML conversion, missing-data handling and overfitting risk with only about 300 training users. This is my judgement, but it is consistent with EmoPhone, GLOBEM, OpenMHC and Zhang.
- "13 inputs" is not the bottleneck. EmoPhone uses far more inputs (phone + wearable, several windows) for the same ceiling. The two feature additions with documented gains are (a) longer look-back context (yesterday's or the whole day's aggregates, +0.024 AUC in Zhang) and (b) the user's most recent self-report (+0.05 AUC on DeepStress). The app can only approximate (b), through an optional check-in or implicit feedback.

### Gaps
- No study found that compares LR with deep models on Apple-Watch-rate HR (one sample every ~5 min) for momentary affect.
- Full per-label cross-user tables for each EmoPhone model were not extracted; the top 6 ranks of Table 26 were not visible in the extracted text.

## 3. Multi-output: does multi-task learning (arousal + valence + stress), or ordinal regression instead of binary, improve each target?

### Takeaway
I found no in-the-wild, subject-independent evidence that joint arousal + valence + stress training improves any single target. The well-known "multitask" gains (Jaques/Taylor) treat each *person* as a task: that is personalisation, not multi-output, and was measured within subject. A valence output is sensible for the app (songs have positivity scores), but its expected AUROC is about 0.54-0.58, so it should be a weak, separate signal. It is not a reason for a bigger model.

### Cited Findings
- Jaques et al. 2017: "we treat predicting tomorrow's mood for a single person as one task". The personalised MTL-NN cut next-day MAE from 15.0 / 17.1 / 16.5 (NN) to 13.0 / 14.1 / 12.9 (mood / stress / health) and raised ICC from .262 / .422 / .373 to .441 / .621 / .613. The split is 60/20/20 with the same participants in train and test, so this is within-subject — [Jaques et al. 2017](http://proceedings.mlr.press/v66/jaques17a/jaques17a.pdf)
- Han et al. (IMWUT 8(4), Dec 2024) evaluated deep personalisation techniques (fine-tuning, cluster-specific models, multi-task with user/cluster as task) on five *lab* datasets (AMIGOS, ASCERTAIN, WESAD, CASE, K-EmoCon) with unseen users and limited data. The in-the-wild K-EmoPhone was not among them — [Han et al. 2024](https://ic.kaist.ac.kr/publications/papers/han2024systematic.pdf)
- Correlations between labels in K-EmoPhone: arousal–valence r = 0.386, valence–stress r = -0.591 (pooled) — [K-EmoPhone](https://www.nature.com/articles/s41597-023-02248-2)
- In EmoPhone, the negative valence–stress correlation "strengthens monotonically from D-1 to D-3". Valence is less predictable than arousal across users (0.576 vs 0.584 within-wave; 0.541 vs 0.564 cross-wave) — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Ordinal targets: Jaques et al. used regression on 0-100 ordinal scores instead of discarding the middle 40% of scores, as earlier work had done. Zhang et al. found that removing neutral states (AUC 0.543) "may yield overly optimistic results that are unrealistic in real-world situations" — [Jaques et al. 2017](http://proceedings.mlr.press/v66/jaques17a/jaques17a.pdf); [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)

### Inferences
- A second output for valence (or a "positivity relative to usual" head) is cheap if done as a second independent logistic regression on the same 13 features. A shared-trunk multi-task network would add complexity for no documented gain. Valence and stress correlate strongly (r about -0.6), so a stress head mostly duplicates a valence head.
- With valence AUROC about 0.54-0.58, the app should use it at most as a small tilt on song positivity, with the situation (wind-down, wake-up…) and explicit user choice dominating. Because of the "never show a named emotion" rule, any valence estimate should stay internal.
- Ordinal regression (e.g. predicting the deviation from the personal mean on the original scale, then thresholding) keeps more information and gives a graded "how much more activated" score useful for queue intensity. Its expected effect on AUROC is small (judgement). A cheap way to get a graded score without changing the model: report the calibrated LR probability instead of a hard label.

### Gaps
- No paper found that tests multi-task arousal + valence + stress against single-task under LOSO on in-the-wild ESM data, including the EmoPhone benchmark, which trains each label separately.
- No direct evidence on ordinal versus binary targets for in-the-wild momentary affect under LOSO.

## 4. Personalisation compatible with "no per-user model from scratch": what works, and how many labels does it need?

### Takeaway
Personalisation is where the large published gains sit, but the realistic ones are much smaller than the headline numbers. Leak-free partial personalisation on K-EmoPhone added less than 2% AUC with about 70 labels per user, and about 5% with about 566 labels per user. The 0.76-0.98 "hybrid" AUROCs use 50% of each test user's data, randomly split. The best fit for this app is a population model with per-user baselines (already done through the z-scores), plus a light per-user bias/calibration update and a feedback-driven policy for the music.

### Cited Findings
- Zhang et al. 2024: "partial personalization is improving model performance even in LOSO settings. On K-EmoPhone, the improvement is limited to less than 2% in AUC-ROC but around 5% on the DeepStress dataset, probably due to many more labels per user (70 vs. 566)". Random (non-chronological) partial personalisation "could be overly optimistic, failing to consider the temporal order". The abstract concludes: "self-report labels for target users are key to enhancing performance in user-independent scenarios" — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- Zhang et al. 2024: on DeepStress, user-grouped "personalized models" performed worse than generalised ones, possibly because Big-Five personality data were missing for grouping users — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- Meegahapola et al. 2022: population-level AUROC .41-.62 became .78-.98 with "hybrid" models (50% of each test user's labelled data, stratified, added to training). Country-specific personalisation beat multi-country personalisation by 2% (two-class) to 5% (three-class) — [Meegahapola et al. 2022](https://arxiv.org/pdf/2211.03009)
- Jaques et al. 2017: personalisation through one task per person (MTL-NN) or a domain-adapted GP cut MAE by about 12-18% relative to non-personalised models, within subject — [Jaques et al. 2017](http://proceedings.mlr.press/v66/jaques17a/jaques17a.pdf)
- OSF preprint, 2026 (308 adults, 66% with a psychiatric diagnosis, 15 days of EMA, 23,560 observations, passive phone sensing). Mixed-effects regression-tree boosting (MERT) was compared with pooled, fully personalised and linear mixed models. "Cluster-mean centering enabled pooled ML models to match personalized models". Best overall R² about 0.36-0.49 and within-person (idiographic) R² 0.16-0.26 on held-out data. Seen through abstract and snippets only; the two snippets disagree on the lower bound, 0.36 vs 0.38 — [OSF preprint](https://osf.io/2g8dp_v1)
- Zhu, Yang & Thompson, JMIR mHealth 2026 (linear mixed-effects): adding smartphone features gave "a modest and significant improvement" for momentary negative affect, none for positive affect (seen through the snippet only) — [JMIR mHealth 2026](https://mhealth.jmir.org/2026/1/e90970)
- SWEET: physiological stress responses "strongly differ among subjects". Subjects with a larger physiological dynamic range and more imbalanced stress reports were predicted better — [Smets et al. 2018](https://www.nature.com/articles/s41746-018-0074-9)

### Inferences
- The team's features are already "personal-baseline normalised" (z-scores against a 14-day personal baseline). The literature (cluster-mean centering, per-user z-scoring in the EmoPhone benchmark) supports this as the main zero-label form of personalisation. Keep it. Note: Zhang found per-user feature z-scoring alone gave 0.536 vs 0.556 on K-EmoPhone, so its benefit is not guaranteed. It is mostly required for portability across devices (see Q6).
- A light personalisation compatible with the team's constraints (judgement): keep the population LR weights fixed and learn only a per-user intercept (and possibly a temperature / slope) online, from (a) optional one-tap "more or less energy than usual?" check-ins and (b) implicit feedback (a skipped high-energy song while the model predicted high arousal is weak evidence of an error). This is a 1-2 parameter update, Bayesian-shrunk toward 0, so day 1 equals the population model. With the K-EmoPhone evidence (<2% AUC with about 70 labels), expect it to matter more for calibration and user experience than for AUROC within a 2-week pilot.
- Personalising the *music policy* (e.g. a contextual bandit, or simple per-situation running averages over song energy/positivity with the arousal score as context) is probably worth more than personalising the affect model. Skip/like signals arrive many times per session; affect labels do not.
- Expected label needs: published hybrid gains assume tens to hundreds of labels per user (70-566 in Zhang; 50% of a user's data in Meegahapola). A 2-week pilot at roughly 1-3 check-ins per day gives 15-40 labels per user. That is enough to estimate an intercept, not enough to fine-tune a network.

### Gaps
- No study found that quantifies AUROC gain against the number of labels (e.g. 5 / 10 / 20 / 50) for intercept-only calibration on in-the-wild momentary affect.
- No study found that uses music skips or likes as implicit labels for affect-model calibration.
- The full text of the OSF mixed-effects preprint was not read (paywall / 403 on the journal version).

## 5. Wearable foundation models (LSM / LSM-2, Apple WBM and PPG models, PaPaGei, Pulse-PPG, NormWear, OpenMHC): inputs, availability, gains on stress / affect, Core ML feasibility on HealthKit data

### Takeaway
None of these models gives a demonstrated gain on momentary arousal / valence / stress self-reports in the field. The best field stress result (Pulse-PPG, raw PPG) is AUROC 0.57-0.59. The models needing raw PPG / ECG / EDA cannot be fed from HealthKit at third-party level. Google's and Apple's models are closed. The only open model trained on Apple HealthKit-type data (the OpenMHC reimplementations of LSM-2 / WBM) shows no clear skill over a linear model on mood-type outcomes, and loses most of its advantage at coarse resolution. Not a realistic option before 29 Nov 2026.

### Cited Findings
- **LSM-2 (Google, arXiv 2506.05321):** pre-trained on 40 million hours (3.58M person-days) of data. Input: 26 minute-level features from 5 sensors (PPG-derived, accelerometer, EDA, altimeter, temperature) over 1,440 minutes. Downstream binary anxiety (self-reported, person-level), AUROC: supervised ResNet 0.709, LSM-1 0.743, LSM-2 0.758. Removing the accelerometer cut anxiety performance by about 11% — [LSM-2](https://arxiv.org/pdf/2506.05321); [Google Research blog](https://research.google/blog/lsm-2-learning-from-incomplete-wearable-sensor-data/)
- OpenMHC states that for LSM-1 / LSM-2 and Apple WBM, "neither model weights nor training code have been publicly released" — [OpenMHC](https://arxiv.org/pdf/2607.16235)
- **Apple WBM (arXiv 2507.00191):** 162K participants, about 15 billion hourly measurements of 27 HealthKit quantities, weekly windows (168 hours). Targets are health states (e.g. pregnancy, sleep, infection-type tasks), not momentary affect. The authors are "unable to release model weights and code due to the specifics of the informed consent" — [Apple WBM](https://arxiv.org/pdf/2507.00191)
- **Apple PPG/ECG foundation models (ICLR 2024):** trained on raw Apple Watch PPG and ECG from about 141K participants in the Apple Heart and Movement Study — [Apple biosignal FM](https://arxiv.org/pdf/2312.05409)
- **PaPaGei (ICLR 2025):** "the first open foundation model for PPG"; code and weights at github.com/nokia-bell-labs/papagei-foundation-model. Pre-trained on clinical PPG (VitalDB, MIMIC-III, MESA; 13.5K participants), input resampled to 125 Hz. On the ECSMP mood-disturbance task, AUROCs across the compared models range from 0.41 to 0.56, with wide CIs (e.g. 0.56 [0.33-0.77]) — [PaPaGei](https://arxiv.org/pdf/2410.20542)
- **Pulse-PPG (open source, github.com/maxxu05/pulseppg):** raw 50 Hz PPG, field-trained (100-day study, 120 participants). Binary field stress (MOODS) AUROC 0.569 (linear probe) and 0.591 (fine-tuned), against 0.969 / 0.985 on lab WESAD — [Pulse-PPG](https://arxiv.org/pdf/2502.01108)
- **NormWear (arXiv 2412.09758):** open code. Works on raw multivariate physiological signals (wavelet / spectrogram tokenisation). Evaluated on lab affect sets such as WESAD (scores about 66-76 across methods) — [NormWear](https://arxiv.org/pdf/2412.09758)
- **OpenMHC (arXiv 2607.16235, v4 Nov 2026):** 11,894 participants and over 67M participant-hours from the My Heart Counts app via Apple HealthKit (iPhone + Apple Watch). 19 minute-level channels: phone and watch steps, distance, flights, watch heart rate, active energy, asleep / in bed, workout types. Participant-level splits 60/10/30. Open reimplementations and weights of LSM-2 and WBM on Hugging Face (huggingface.co/MyHeartCounts), code on GitHub. The dataset requires a click-through Data Use Agreement — [OpenMHC](https://arxiv.org/pdf/2607.16235)
- OpenMHC results: LSM-2 best overall (aggregate skill +16.5 vs XGBoost +12.3, relative to linear). On mental well-being (Feel Depressed / Happy / Worried, Life Satisfaction, Things Worthwhile; 0-10 survey answers, person-level) the best skill is only +1.6 (CI roughly -4 to +7). Training LSM-2 on hourly instead of minute-level data lowered aggregate skill from +16.6 to +4.5: "the greatest drop in LSM-2 came from switching from minute-level input resolution to hourly". WBM needed a fallback to the linear model for 62.7% of evaluation instances, because of weekly wear-time criteria. Gemini LLMs (zero / few-shot) "generally underperform baselines" — [OpenMHC](https://arxiv.org/pdf/2607.16235)

### Inferences
- Input requirements against what the app has: PaPaGei / Pulse-PPG / NormWear / Apple biosignal models need raw PPG (or ECG / EDA). To my knowledge, third-party apps cannot read Apple Watch raw PPG through HealthKit. This is an inference, not verified in a source here. LSM-2 needs 26 minute-level channels, including EDA and temperature, that Apple Watch does not expose that way. The OpenMHC LSM-2 reimplementation uses HealthKit channels, but at minute resolution. Apple Watch background HR at about 1 sample / 5 min is sparser than that, and OpenMHC shows coarse resolution erases most of the gain.
- Core ML: a frozen ViT-MAE encoder plus a linear probe could in principle be converted. But (a) the pre-training population (US, older, health-study volunteers), targets (person-level health and well-being) and resolution do not match momentary affect; (b) the mental well-being skill is about 0 even in-domain; (c) the licence for the Hugging Face weights was not checked. Expected gain on the team's target: about 0 ± 0.02 AUROC (judgement). Effort: weeks. Not viable before the 29 Nov milestone.
- Possibly useful later: OpenMHC as an Apple HealthKit-native dataset for checking device realism of the features (HR sampling, sleep coding). It has no momentary affect labels.

### Gaps
- No published result of any wearable foundation model on K-EmoPhone / EmoPhone momentary labels.
- Licence terms of the OpenMHC Hugging Face weights were not checked.
- Apple's 2025-2026 papers were not checked for any affect or stress downstream task beyond those listed.

## 6. Device and population shift (Fitbit-trained model on Apple Watch; Korean students to other users)

### Takeaway
Shift is the main documented reason for the in-the-wild ceiling. Even with the same device and population, a different year costs EmoPhone about 0.03 AUROC (0.568 → 0.542 mean). A new country drops mood models to chance (0.46-0.55). No direct Fitbit-to-Apple-Watch affect study was found. The strongest mitigations available are per-user baseline normalisation (already used) and training on Fitbit data degraded to match Apple Watch sampling.

### Cited Findings
- EmoPhone: within-wave (users held out) mean best AUROC 0.568 → cross-wave (another year's cohort) 0.542. Stress falls most, arousal least (0.584 → 0.564) — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Meegahapola et al.: country-agnostic population models score 0.46-0.55 AUROC in a new country. Continent-specific models beat multi-country models in Europe, which the authors attribute to cultural similarity producing similar phone sensor data — [Meegahapola et al. 2022](https://arxiv.org/pdf/2211.03009)
- GLOBEM: cross-dataset (other cohort years, pre/post COVID) depression detection falls to about 0.50-0.55 balanced accuracy for all 18 algorithms. The best (Reorder) gains 9.7% over baseline cross-dataset — [GLOBEM](https://arxiv.org/pdf/2211.02733)
- Zhang et al. 2024 name "distribution shifts across users" as a main limit to performance — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- OpenMHC warns that, even inside the HealthKit ecosystem, data span 16 Apple Watch generations, and that models might exploit device generation — [OpenMHC](https://arxiv.org/pdf/2607.16235)
- EmoPhone's released Fitbit Inspire HR heart-rate stream is at 1 Hz and steps at 1/60 Hz (per-minute) — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Cross-device evidence nearby but not affect-specific: a 2026 npj Digital Medicine study shows accuracy loss when clinical single-lead ECG models move to Apple Watch recordings — [npj Digit Med 2026](https://www.nature.com/articles/s41746-026-02919-5). In a physiological emotion-recognition study, models trained on lab-grade devices transferred "reasonably" to commercial wearables, with the reverse weaker (search snippet only) — [FEEL arXiv](https://arxiv.org/pdf/2604.05926)
- Vendors compute HRV differently (Apple SDNN vs others RMSSD, different windows), so raw values are not comparable across brands. This is a commercial blog, not peer-reviewed — [Thryve blog](https://www.thryve.health/blog/wearable-data-normalization)

### Inferences
- The team's design (z-scores against a 14-day personal baseline, HR compared with the same 3-hour block, log-step z-scores) already removes most device offsets, because each user is compared with themselves on the same device.
- The remaining shift is in *sampling density*. A 15-minute window holds hundreds of Fitbit HR samples (1 Hz file) but about 3 Apple Watch samples. So the variance of the 15/30-min HR z-scores is much larger on Apple Watch, and the LR weights learnt on Fitbit will be miscalibrated. Cheap mitigation (judgement): when building the training features, subsample Fitbit HR to about one reading per 5 min (with random phase and gaps) and retrain. Then check on the held-out wave that AUROC does not collapse. Optionally drop or merge the 15-min window if it becomes too noisy.
- Sleep: Fitbit and Apple sleep staging differ. Using sleep *duration* z-scored against the personal baseline (as the team does) plus the "unknown" flag is the robust choice. Avoid stage-level features.
- Population: if the pilot users are also Korean university students, the population shift is mild compared with the device shift. A ≤5-user pilot cannot measure AUROC reliably anyway (about 15-40 labels per user), so it should be framed as a feasibility and user-experience test.

### Gaps
- No peer-reviewed study found that trains an affect or stress model on Fitbit and tests it on Apple Watch data (or the reverse).
- No study found on the effect of HR sampling rate (1 Hz vs about 0.003 Hz) on momentary affect prediction.

## 7. Alternative targets that may be more predictable and still useful

### Takeaway
Daily-level targets tied to sleep and activity (next-day physical fatigue or sleepiness) show higher LOSO AUROCs (about 0.66-0.75) than momentary affect, though from a single, recent study. Among momentary ESM labels, arousal is already the most transferable. For a music app, predicting the user's own feedback (skip / like) from context and behaviour is probably more useful than predicting affect (judgement; see Gaps on skip-prediction evidence).

### Cited Findings
- Frontiers in Digital Health 2026 (LOSO; 3,062 nights; three consumer / research sleep trackers): next-day physical fatigue AUC 0.75 in healthy adults (mainly respiratory rate and REM duration); mental fatigue 0.66; daytime sleepiness 0.66 in a neurodegenerative-disease group. The authors call it preliminary. Seen through the search snippet only — [Frontiers Digital Health 2026](https://www.frontiersin.org/journals/digital-health/articles/10.3389/fdgth.2026.1752629/full)
- EmoPhone: arousal is the most stable label across users and waves. Task disturbance is near chance in every setting — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Li et al. (IMWUT 2022) studied personalising music recommendations from low-cost smart-bracelet data without explicit annotations — [Li et al. IMWUT 2022](https://JiayuLi-997.github.io/files/IMWUT2022-LiJY-Ubiquitous_Rec.pdf)
- Contextual bandits have been deployed for music-streaming personalisation (carousel recommendation) — [Bendada et al., arXiv 2009.06546](https://arxiv.org/abs/2009.06546)
- MusicalHeart (SenSys 2012) chose music to steer the listener toward a target heart rate, using past responses to music — [MusicalHeart](https://cps.cse.wustl.edu/images/2/26/MusicalHeart-SenSys2012-CameraReady.pdf)

### Inferences
- For the "wake-up" and "low energy" situations, a daily or morning signal (last night's sleep vs personal baseline, hours since wake) is better supported and easier to explain than a momentary arousal estimate. It also uses data Apple Watch measures well. The team already has these features; the app logic could lean on them directly instead of only through the arousal classifier.
- A useful reframing (judgement): keep the arousal model as a *context feature*, and make the decision variable "which energy / positivity band does this user accept now?". Learn it online from skips / likes per situation. This uses the most plentiful signal in the app and gives personalisation without per-user training from scratch.

### Gaps
- The fatigue / sleepiness study was seen through a search snippet only; its numbers should be checked in the full text before they go into the report.
- A search summary attributed to "Meggetto et al. 2023" the finding that users' behaviour features predict music skips better than content or context features. I could not locate or open the original paper, so this is unverified and not cited above.
- No dataset found with both momentary affect labels and music-listening feedback with wearables, so "predict feedback directly" has no offline benchmark for this app.

## 8. Overall answer: would a bigger / multi-output model be clearly better? Ranked options for this app

### Takeaway
Evidence says no. On the team's own dataset and target, the best published cross-user arousal AUROC (0.584 ± 0.022; 29 model families including Transformers and domain adaptation; phone + wearable features) is within noise of the team's 13-feature LR (0.563 group CV / 0.576 held-out wave). Deep, boosted and foundation models do not beat simple models when users or cohorts are held out. Multi-output adds outputs, not accuracy. The real gains in the literature come from per-user information (labels or feedback) and from choosing more predictable targets.

### Cited Findings
- Best EmoPhone cross-user arousal 0.584; cross-wave 0.564; model families within 0.013 AUROC cross-wave — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v1)
- Simple models "remain highly competitive with, and often outperform, more complex architectures" on Apple HealthKit data; mental well-being skill about 0 for all methods — [OpenMHC](https://arxiv.org/pdf/2607.16235)
- Partial personalisation: <2% AUC with about 70 labels per user (K-EmoPhone), about 5% with about 566 (DeepStress); last self-report as a feature +0.05 AUC (DeepStress) — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
- Field PPG foundation model: binary stress AUROC 0.57-0.59 in the field vs 0.97-0.99 in the lab — [Pulse-PPG](https://arxiv.org/pdf/2502.01108)

### Inferences
Ranked modelling options for this app. Expected gains are my estimates, anchored on the cited numbers; AUROC deltas are for the per-user-mean arousal target under group CV.

| Rank | Option | Expected gain | Effort | Main risks |
|---|---|---|---|---|
| 1 | **Keep LR; make it device-realistic.** Retrain on Fitbit HR subsampled to Apple Watch rate (~1 / 5 min, random gaps); re-check group CV and held-out wave; report bootstrap CIs | Protects the 0.56-0.58 on real Apple Watch data, which might otherwise fall toward the time-only 0.534; ±0 on paper | Low (days) | The 15-min window may become pure noise (then drop it) |
| 2 | **Per-user online intercept / calibration** from optional one-tap "energy vs usual" check-ins, shrunk toward 0 (day 1 = population model) | +0.00-0.02 AUROC within 2 weeks; better calibration and user trust | Low-medium (Swift only; no retraining) | Too few labels in the pilot; check-in burden; must not show emotion words |
| 3 | **Feedback-driven music policy** (per-situation running preference or a small contextual bandit over energy / positivity, with arousal probability as context) | Not measurable as AUROC; the likely largest impact on perceived fit | Medium | Cold start; confounds (skips for reasons unrelated to mood); evaluation with ≤5 users is anecdotal |
| 4 | **Add 1-3 longer-context features** (e.g. yesterday's / today-so-far HR and step aggregates vs baseline) | +0.01-0.02 (Zhang: +0.024 AUC) | Low-medium (must update PROJECT.md §6, golden fixtures, Swift) | Feature-parity bugs between Python and Swift; small gain vs fold SD |
| 5 | **Use calibrated probability / graded score** instead of a hard binary; optional ordinal / regression variant | Better queue grading; ≈0 AUROC | Low | Over-interpreting small probability differences |
| 6 | **Second independent LR head for valence ("positivity vs usual")** | Valence AUROC likely about 0.54-0.58; no gain for arousal | Low | Weak signal steering positivity; keep internal |
| 7 | **Domain-generalisation / adaptation MLP** (e.g. GroupDRO, DAN) | +0.00-0.01 within cohort, ≈0 across waves | High (Core ML MLP, tuning) | Overfitting; complexity before the deadline |
| 8 | **Boosting / deep sequence models on minute-level HR** | ≈0 (HGB 0.558 already; EmoPhone XGB/LGB rank low cross-user) | Medium-high | Overfitting to users; Apple Watch HR too sparse for sequence models |
| 9 | **Wearable foundation models** (OpenMHC LSM-2 weights; PaPaGei / Pulse-PPG need raw PPG) | ≈0 ± 0.02; no affect evidence | Very high | Inputs not available from HealthKit at the needed resolution; licence; on-device size |

- Answer to the teammate: a bigger model with more inputs and outputs is not "clearly better" on any published in-the-wild benchmark under subject-independent evaluation. The ceiling is set by label noise, between-person differences and device / cohort shift, not by model size. The defensible upgrades are the cheap ones (ranks 1-5). Multi-output (rank 6) is a product decision, justified by songs having positivity scores, not by an accuracy gain.
- Reporting advice: give AUROC with bootstrap CIs over participants; always compare with the time-only baseline (0.534) and state the protocol. Differences below about 0.02 are inside the cross-fold / cross-dataset SD reported by EmoPhone (0.01-0.035).

### Gaps
- None of the ranked gains has been measured on Apple Watch data with momentary labels. The ranking rests on Fitbit / phone benchmarks plus judgement.
- No published estimate of how much personalisation from implicit music feedback improves either affect prediction or listening satisfaction.
