# LifeSnaps: is it worth adding to Harmony's state model? (download + aggregate-only checks, 23 Nov 2026)

Scope: Zenodo record 7229547 (v4) was downloaded and every number below was computed from it.
Only aggregates are reported here; no raw rows or per-participant values. My own scripts are in
`/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/scripts/`
and the aggregate outputs are in `/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/`.
The data and the private per-person tables I derived are in `/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/ext/lifesnaps/`.
Harmony's `ml/features.py` was imported read-only with bytecode writing off, and the repo is unchanged (`git status` is clean).
"Own analysis" sources below point to those output files (OUT = the out/ folder above).

## 1. Licence, access, files

### Takeaway
LifeSnaps v4 is open under CC BY 4.0, with no login and no restriction. It is one 615 MB zip, well under the 5 GB budget. The zip holds the raw MongoDB BSON dumps (needed for 5-s heart rate, per-minute steps and timed mood answers) and also preprocessed CSVs. The daily and hourly CSVs alone are not enough for Harmony: they lose about 22 % of the mood answers and have no sub-hour heart rate.

### Cited Findings
- Zenodo API, record 7229547: title "LifeSnaps: a 4-month multi-modal dataset capturing unobtrusive snapshots of our lives in the wild". Version 4, licence `cc-by-4.0`, access_right `open`, concept DOI 10.5281/zenodo.6826682. Single file `rais_anonymized.zip`, 615,037,493 bytes, md5 726afe263ab4b900a721eac19b2ca13a. The md5 of my download matched — [Zenodo API record 7229547](https://zenodo.org/api/records/7229547)
- Version history: v1 (6826683) and v2 (6832186) are `restricted` with no files; v3 (6832242, 643 MB) and v4 (7229547, 615 MB) are `open` under CC BY 4.0. Only v3/v4 are usable without a request — [Zenodo versions API](https://zenodo.org/api/records/7229547/versions)
- The Zenodo description says CSV files are provided "at daily and/or hourly granularity" for ease of use, and that the raw, complete data in MongoDB is "Recommended". It also says "all times are stored in local time, and user IDs are common across different collections" — [Zenodo record](https://zenodo.org/records/7229547)
- Zip contents, read from its central directory:
  - `csv_rais_anonymized/daily_fitbit_sema_df_unprocessed.csv` (2.1 MB) and `hourly_fitbit_sema_df_unprocessed.csv` (21.1 MB);
  - `mongo_rais_anonymized/fitbit.bson` (4,295 MB uncompressed, 611 MB zipped), `sema.bson` (10.7 MB) and `surveys.bson` (0.6 MB), each with a metadata.json;
  - `scored_surveys/` with breq, panas, personality, stai and ttm CSVs.

  The BSON was streamed out of the zip, not extracted — [Own analysis: OUT/zip_listing.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/zip_listing.txt)
- The paper (Yfantidou et al., Sci Data 9, 663, published 31 Oct 2022) describes two release formats: BSON exports of the raw data, and "CSV exports of daily and hourly granularity". It says "the CSV files are subsets of the MongoDB database presenting aggregated versions of the raw data". The article itself is CC BY 4.0 — [Scientific Data paper](https://www.nature.com/articles/s41597-022-01764-x)
- Code for anonymisation and for exploratory analysis (EDA) is on GitHub (Datalab-AUTH/LifeSnaps-Anonymization and LifeSnaps-EDA) — [paper, Code availability](https://www.nature.com/articles/s41597-022-01764-x); [LifeSnaps-EDA repo](https://github.com/Datalab-AUTH/LifeSnaps-EDA)
- Privacy treatment: age is released only as "below 30" vs the rest, BMI in 3 groups, height and weight withheld. The authors state the dataset is "12-anonymous under the normal threat model and at least 2-anonymous under the strongest one" — [paper](https://www.nature.com/articles/s41597-022-01764-x)
- The daily CSV's mood columns sum to 3,936 answers, against 5,028 usable mood answers in the raw `sema.bson`. So the CSV drops about 22 % of the labels — [Own analysis on the downloaded files]

### Inferences
- CC BY 4.0 allows reuse and adaptation, including in a course project and the report, with attribution (cite the Sci Data paper and the Zenodo DOI).
- A model trained on LifeSnaps can be shipped with the app as long as attribution is given. The data itself stays out of Git, like EmoPhone (CLAUDE.md hard rule).
- Working from the raw BSON is required for Harmony-style features. It needs no MongoDB server: pymongo's `bson` decoder, streaming from the zip, read all 71.3 M documents in about 5 min.

### Gaps
- The GitHub EDA repository page shows no explicit code licence. This only matters if code were reused, and none was.
- Whether Zenodo v3 and v4 differ in content (643 MB vs 615 MB) was not checked. v4 is the current one.

## 2. Inventory: signals, resolution, coverage, label instruments

### Takeaway
Heart rate is about every 5 s (far denser than Apple Watch, but it resamples cleanly to Harmony's 1 reading per 5 min). Steps are per minute. Sleep is measured with stages. The other Apple-like night signals are per night:
- HRV (RMSSD, Fitbit's definition, not Apple's SDNN) and respiratory rate: only 43 of 71 participants (36–37 of the 60 usable for modelling);
- SpO2: 28 participants (23 usable);
- skin temperature: 64–65 participants.

Mood is a single categorical choice, scheduled 3×/day. 5,028 usable answers from 63 participants, with a median of 65 per person and a very uneven distribution.

### Cited Findings
- Study: 71 participants in Greece (25), Sweden (24), Cyprus (12) and Italy (10), recruited by convenience or volunteer calls, no incentives. Two rounds: 24 May–26 Jul 2021 (n = 38) and 15 Nov 2021–17 Jan 2022 (n = 34); one person took part in both. Device: Fitbit Sense — [paper](https://www.nature.com/articles/s41597-022-01764-x)
- Time zones: Fitbit types exported in UTC "are converted to local time based on the participant's time zone, as declared in their Fitbit profile", with DST handled. A single time zone per participant is assumed, which fails when travelling: "this only applies to ~3% of participants and for a limited time period" — [paper](https://www.nature.com/articles/s41597-022-01764-x)
- Paper Table 2, Fitbit part:
  - Heart Rate: "< 1-minute", 69 users, 48,720,040 rows; Resting Heart Rate: 71 users, 12,362 rows;
  - Sleep: "Daily", 66 users, 4,141 rows;
  - Nightly (Computed) Temperature: "Daily", 67 users, 3,568 rows, described as "variation from a 3-day baseline";
  - Wrist Temperature: 61 users, 4,372,238 rows;
  - HRV details: "5-Minute", 44 users, 225,987 rows;
  - Stress Score: 36 users; Mindfulness EDA: 39 users.

  The paper also says heart rate is missing for 2 users and steps for about 3 % of users because of Fitbit export errors — [paper Table 2](https://www.nature.com/articles/s41597-022-01764-x/tables/3); [paper](https://www.nature.com/articles/s41597-022-01764-x)
- Measured in the raw data (aggregates):
  - `heart_rate`: 48,720,040 rows, 71 participants. Interval between readings: 5 s median (10th/90th percentile 5/15 s). Median 64 days with data per participant (IQR 54.5–76.5). After resampling to Harmony's first reading per 5-min slot, a median of 273 of 288 slots per day hold a reading.
  - `steps`: 3,010,529 rows, 71 participants, per minute (median interval 60 s), 64 % zero minutes. Paper Table 2 lists steps as "3-Minute"; the data are per minute.
  - `sleep`: 4,141 logs, 89.1 % main sleep, 3,522 with stages (deep/light/REM/wake) and 619 "classic". `dateOfSleep` equals the wake date in 100 % of main sleeps.
  - HRV, respiratory rate, SpO2 and computed temperature are keyed to the wake date (99.5 %, 99.7 %, 96.9 % and 99.9 % match a main-sleep wake date).

  — [Own analysis: OUT/resolution_checks.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/resolution_checks.json)
- Fitbit types and document counts found in `fitbit.bson`:

  | Type | Documents | Participants |
  |---|---:|---:|
  | Daily Heart Rate Variability Summary (rmssd, nremhr, entropy) | 2,475 | 43 |
  | Heart Rate Variability Details (5-min RMSSD during sleep; median 87 rows per night) | 220,512 | 43 |
  | Respiratory Rate Summary (full-sleep and per-stage breathing rate) | 3,000 | 43 |
  | Daily SpO2 (average, lower, upper) | 1,274 | 28 |
  | Computed Temperature (3,500 SKIN + 68 IDT) | 3,568 | 65 |
  | Wrist Temperature | 4,372,238 | 61 |
  | resting_heart_rate | 12,362 | 71 |
  | Stress Score | 1,911 | 37 |
  | mindfulness_eda_data_sessions | 16,070 | 23 |
  | estimated_oxygen_variation | 2,009,637 | 71 |

  Other types present: Afib ECG (11 participants), calories, distance, altitude, exercise, the active-minutes types, VO2 max and more.

  Computed Temperature holds absolute nightly skin temperature: 5th/50th/95th percentiles 32.11/33.87/34.92 °C. In resting_heart_rate, 63.8 % of rows are 0 or empty (about 2.8 rows per participant-day), which leaves 4,422 valid participant-days — [Own analysis: OUT/fitbit_types.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/fitbit_types.txt); [OUT/resolution_checks.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/resolution_checks.json)
- Nights per signal (participants / total nights / median nights per participant):

  | Signal | Participants | Nights | Median per participant |
  |---|---:|---:|---:|
  | Measured sleep | 69 | 3,551 | 58 |
  | Sleep stages | 63 | 3,357 | 57 |
  | Skin temperature | 64 | 3,359 | 57 |
  | RMSSD / non-REM HR | 43 | 2,475 | 58 |
  | Breathing rate | 43 | 2,495 | 59 |
  | SpO2 | 28 | 1,270 | 53.5 |
  | Resting HR (previous day) | 71 | 4,422 | 64 |

  These match the daily CSV coverage — [Own analysis: OUT/nights_inventory.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/nights_inventory.json)
- Coverage at the mood answers, with a past-only z-score (≥ 5 known nights in the 14 before; Harmony rule):

  | Signal | Answers with a known value | Participants |
  |---|---:|---:|
  | z_hr_30 | 76.2 % | 60 |
  | Resting HR (previous day) | 80.3 % | 60 |
  | Measured sleep | 72.8 % | 53 |
  | Skin temperature | 70.9 % | 52 |
  | Deep/REM share | 69.4 % | 52 |
  | Breathing rate | 48.1 % | 37 |
  | RMSSD | 47.7 % | 36 |
  | SpO2 | 29.2 % | 23 |

  — [Own analysis: OUT/results.json "coverage_at_answers"](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results.json)
- Harmony v1 features on LifeSnaps: share of answers with an unknown value is 24 % for z_hr_30, 23 % for z_log_steps_30, 29 % for z_sleep_min and 22 % for sleep_unknown (`ml/features.py` unchanged). EmoPhone D-1 has 43 % unknown for z_hr_30 (PROJECT.md §6) — [Own analysis: OUT/v1_coverage.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/v1_coverage.json)
- Label instrument: "Thrice a day (morning-afternoon-evening), we schedule the Context and Mood Survey … The mood choices include happy, rested/relaxed, tense/anxious, tired, alert, and sad, while an option neutral is added at the beginning of the first round upon request." There is also a daily Step Goal Survey. Weekly PANAS and S-STAI are sent by e-mail, plus entry/exit surveys (demographics, PAR-Q, IPIP, TTM, BREQ-2) — [paper](https://www.nature.com/articles/s41597-022-01764-x)
- Paper compliance: "~18% decrease in SEMA3 compliance" between entry and exit weeks, and "nearly 1 in 3 participants replied to more than 75% of the EMA surveys" — [paper](https://www.nature.com/articles/s41597-022-01764-x)
- Measured in `sema.bson`:
  - 15,380 scheduled EMAs (11,526 Context and Mood, 3,852 Step Goal), all `TRIGGER = scheduled`, 63 participants;
  - 5,037 Context and Mood surveys completed (43.7 %);
  - mood is one string per answer: RESTED/RELAXED 1,179, TIRED 1,126, NEUTRAL 822, HAPPY 789, TENSE/ANXIOUS 620, ALERT 345, SAD 147, plus 9 stray answers (SURPRISE, ANGER, SADNESS, FEAR, JOY, None) that were dropped;
  - 5,028 usable answers from 63 participants;
  - answers per participant: median 65 (10th percentile 6, IQR 20–147, max 200); 39 participants have ≥ 40 and 23 have ≥ 100;
  - 2.2 answers per answered participant-day; median 40 answered days per participant;
  - answer hours cluster at 10–12 h, 15 h and 20–22 h;
  - 4 participants used a single category; the median participant used 6 of 7.

  — [Own analysis: OUT/labels_summary.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/labels_summary.json)
- Weekly instruments, from `scored_surveys/`:
  - PANAS (positive/negative affect scores): 268 entries, 51 participants, median 5 per participant;
  - S-STAI (state anxiety score and category): 279 entries, 53 participants, median 6;
  - BREQ 92 / TTM 94 / IPIP personality 50 (entry/exit).

  — [Own analysis on the downloaded scored_surveys CSVs]
- Matching Apple Watch signals in HealthKit: HRV is stored as `heartRateVariabilitySDNN`, not RMSSD — [Apple Docs: heartRateVariabilitySDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn). The others are restingHeartRate ([Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate)), respiratoryRate ([Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/respiratoryrate)), oxygenSaturation ([Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/oxygensaturation)), a per-night appleSleepingWristTemperature ([Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature)) and sleep stages ([Apple Docs: HKCategoryValueSleepAnalysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis))

### Inferences
- Signal fit with Apple Watch:
  - Good, after personal z-scoring: resting HR, breathing rate, skin temperature (Fitbit gives absolute °C; Apple gives a per-night value, so both reduce to "deviation from my last 14 nights"), sleep duration and stage shares.
  - Weak for HRV: Fitbit nightly RMSSD and Apple's sparse SDNN are different statistics. Only the direction of a personal z-score could plausibly transfer.
  - Stress score, EDA and ECG have no Apple equivalent.
- LifeSnaps heart rate has the same nominal 5-s rate as EmoPhone's Fitbit (PROJECT.md §6.4), and after 5-min resampling it fits Harmony v1 exactly. More answers have a usable personal baseline: 76 % have a known z_hr_30, against 57 % in EmoPhone D-1. This is probably helped by about 2-month rounds against about 4-week waves, which makes the 7-day baseline rule easier to meet (not tested separately).
- The label set is smaller than EmoPhone's (5,028 answers vs 10,259 in D-1 alone) and very uneven across people: a quarter of participants have fewer than 20 answers.

### Gaps
- I did not measure the wrist-temperature sampling interval. Paper Table 2 lists it as "3-Minute", but the same table lists steps as "3-Minute" while the data are per minute, so the column may be unreliable.
- Coverage counts differ slightly from paper Table 2: I find 71 participants with heart-rate and step rows, against 69 and 68 in the paper. Possibly a few participants have only a handful of rows; not investigated.

## 3. Label mapping to activation and pleasantness

### Takeaway
The 7 categories map onto the circumplex defensibly:
- activation: ALERT and TENSE/ANXIOUS high; TIRED and RESTED/RELAXED low; SAD mildly low; HAPPY slightly high; NEUTRAL centre;
- pleasantness: HAPPY and RESTED/RELAXED pleasant; TENSE/ANXIOUS and SAD unpleasant; ALERT mildly pleasant; TIRED mildly unpleasant.

Applying Harmony's own label rule (above the person's own mean, `features.label_high`) gives balanced targets. The labels follow a strong time-of-day pattern, so the "time only" baseline is high on LifeSnaps.

### Cited Findings
- Mapping used (scores; `common.py`):
  - activation: ALERT +1, TENSE/ANXIOUS +1, HAPPY +0.5, NEUTRAL 0, SAD −0.5, RESTED/RELAXED −1, TIRED −1;
  - pleasantness: HAPPY +1, RESTED/RELAXED +1, ALERT +0.5, NEUTRAL 0, TIRED −0.5, TENSE/ANXIOUS −1, SAD −1.

  Targets: `act_high` / `val_high` = score above the participant's own mean (`features.label_high`, PROJECT.md §6.2). Strict variants keep only the unambiguous categories:
  - activation high = ALERT or TENSE/ANXIOUS, low = RESTED/RELAXED or TIRED;
  - pleasantness high = HAPPY or RESTED/RELAXED, low = TENSE/ANXIOUS or SAD.

  — [Own analysis: scripts/common.py](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/scripts/common.py)
- Resulting balance: act_high 49.1 % positive and val_high 53.4 % (5,028 answers). The strict activation label keeps 3,270 answers, 29.5 % high; the strict pleasantness label keeps 2,735 answers, 72.0 % pleasant — [Own analysis: OUT/labels_summary.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/labels_summary.json)
- Mean within-person category shares (between-person SD in brackets): RESTED/RELAXED 0.239 (0.187), TIRED 0.199 (0.134), HAPPY 0.161 (0.159), NEUTRAL 0.148 (0.193), TENSE/ANXIOUS 0.147 (0.166), ALERT 0.057 (0.083), SAD 0.049 (0.136). Response styles differ a lot between people, for example in how much they use NEUTRAL — [Own analysis: OUT/labels_summary.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/labels_summary.json)
- Time-of-day profile (answers from the 60 modelling participants):

  | Period | Answers | act_high share | TIRED | ALERT | TENSE/ANXIOUS |
  |---|---:|---:|---:|---:|---:|
  | Morning (5–12 h) | 1,449 | 0.582 | 12.6 % | 11.3 % | 17.5 % |
  | Afternoon (13–17 h) | 1,462 | 0.527 | 22.9 % | 9.0 % | 14.4 % |
  | Evening (18–23 h) | 1,950 | 0.396 | 28.6 % | 2.5 % | 7.8 % |

  — [Own analysis: OUT/extra_compact.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/extra_compact.txt)
- The paper notes that "TIREDNESS is a response that usually appears at the beginning of the week", "SADNESS appears on Mondays or in the middle of the week", and HAPPY is used more "on Fridays or during the weekends" and over Christmas — [paper](https://www.nature.com/articles/s41597-022-01764-x)

### Inferences
- The mapping is a judgement call; HAPPY, SAD, NEUTRAL and TIRED are the ambiguous ones. The strict variant gives the same qualitative results (section 4), so the conclusions do not hinge on the scores chosen.
- A single categorical choice is a much coarser and noisier activation measure than EmoPhone's 7-point arousal rating. "Tired" partly reflects time since waking, not affect.
- The strict variants are absolute (not person-relative) labels. Their high AUROCs (about 0.64–0.69) come mostly from between-person and time differences. They are not comparable with Harmony's person-relative target.
- "Never show a named emotion": the categories are only used offline as training targets. Nothing named reaches the user.

### Gaps
- No published validation maps these SEMA3 categories to arousal or valence. The circumplex placement rests on general circumplex theory (Russell 1980; Posner, Russell & Peterson 2005), which I did not re-fetch this round. A source should be added before the report cites the mapping.

## 4. Evidence: night signals vs next-day mood, and grouped cross-validation

### Takeaway
On LifeSnaps, previous-night signals carry almost no information about the momentary mapped labels:
- single-signal AUROCs range 0.47–0.53, mostly with confidence intervals including 0.5;
- day-level within-person Spearman |ρ| ≤ 0.10;
- adding all extended night signals to Harmony v1 changes grouped-CV AUROC by −0.001 ± 0.004 (5 folds) and −0.004 ± 0.006 (10 × 5 folds, 15/50 folds positive).

The only replicable gain is the same small heart-rate (and steps) effect Harmony already uses: +0.009 to +0.012 over time only. The faint night-signal leads worth keeping as hypotheses are sleep duration and deep-sleep share with pleasantness, and breathing rate with lower activation.

### Cited Findings
- Night signal alone vs momentary label: pooled AUROC, 95 % participant-bootstrap CI (B = 1,000), past-only 14-night z-scores (≥ 5 nights), unknown kept unknown. 60 modelling participants; 2,399–4,039 labels per signal; SpO2 1,467 labels from 23 participants.

  | Signal | Activation (act_high) | Pleasantness (val_high) |
  |---|---|---|
  | RMSSD | 0.500 [0.473, 0.527] | 0.495 [0.465, 0.525] |
  | Non-REM HR | 0.493 [0.466, 0.519] | 0.487 [0.463, 0.509] |
  | Resting HR (previous day) | 0.494 [0.467, 0.521] | 0.503 [0.479, 0.526] |
  | Deep share | 0.506 [0.487, 0.527] | 0.528 [0.506, 0.549] |
  | REM share | 0.515 [0.496, 0.532] | 0.524 [0.501, 0.546] |
  | Sleep efficiency | 0.502 [0.483, 0.522] | 0.499 [0.476, 0.52] |
  | Skin temperature | 0.496 [0.475, 0.516] | 0.490 [0.471, 0.51] |
  | Breathing rate | 0.473 [0.448, 0.499] | 0.496 [0.464, 0.523] |
  | SpO2 | 0.499 [0.463, 0.533] | 0.520 [0.488, 0.553] |
  | Measured sleep minutes | 0.507 [0.483, 0.532] | 0.528 [0.501, 0.559] |

  — [Own analysis: OUT/results_compact.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results_compact.txt)
- Day level (daily mean mapped score, centred within person, vs that night's z), pooled within-person Spearman with participant-bootstrap CI:
  - activation: breathing rate −0.087 [−0.148, −0.025] (1,078 days, 37 participants); resting HR (previous day) −0.049 [−0.097, −0.001]; RMSSD +0.021 [−0.041, 0.082]; skin temperature −0.036 [−0.080, 0.011]; sleep minutes −0.013 [−0.071, 0.043];
  - pleasantness: sleep minutes +0.096 [0.029, 0.160] (1,610 days, 53 participants); deep share +0.047 [−0.001, 0.094]; RMSSD −0.011 [−0.074, 0.050].

  — [Own analysis: OUT/results_compact.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results_compact.txt)
- Grouped 5-fold CV (GroupKFold by participant). Model = Harmony §6.3: median imputation, standardisation, logistic regression. 4,882 answers, 60 participants with heart-rate features. AUROC mean ± SD over folds (BA = balanced accuracy):

  | Feature set | Activation | Pleasantness |
  |---|---|---|
  | (i) time only | 0.588 ± 0.026 (BA 0.575) | 0.554 ± 0.010 |
  | (ii) time + HR + steps | 0.597 ± 0.017 | 0.546 ± 0.016 |
  | (ii) Harmony v1, 13 features (estimated sleep) | 0.600 ± 0.017 (BA 0.576) | 0.557 ± 0.022 |
  | (ii') Harmony v1, Fitbit-measured sleep in the 3 sleep slots | 0.595 ± 0.017 | 0.550 ± 0.017 |
  | (iii) (ii') + 9 night z-scores (RMSSD, non-REM HR, resting HR, deep share, REM share, efficiency, skin temperature, breathing rate, SpO2) | 0.594 ± 0.016 | 0.552 ± 0.014 |
  | (iv) time + measured sleep + night signals | 0.583 ± 0.025 | 0.556 ± 0.008 |

  Paired fold differences, activation (folds positive out of 5):
  - (ii) HR + steps − (i): +0.009 ± 0.010 (4/5);
  - (ii) Harmony v1 − (i): +0.012 ± 0.011 (4/5);
  - (ii') measured − estimated sleep: −0.005 ± 0.004 (1/5);
  - (iii) − (ii'): −0.001 ± 0.004 (3/5);
  - (iv) − (i): −0.005 ± 0.006 (1/5).

  Pleasantness:
  - (ii) HR + steps − (i): −0.008 ± 0.009 (0/5);
  - (ii) Harmony v1 − (i): +0.003 ± 0.020;
  - (iii) − (ii'): +0.002 ± 0.005.

  — [Own analysis: OUT/results.json "grouped_cv"](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results.json)
- Repeated grouped CV (10 random assignments of whole participants to 5 folds = 50 folds):
  - activation: time 0.588 ± 0.033; time + HR + steps 0.595 ± 0.036; v1 0.595 ± 0.035;
  - activation differences: v1 − time +0.0069 ± 0.0164 (37/50 folds > 0); HR + steps − time +0.0065 ± 0.0163 (35/50); measured − estimated sleep −0.0047 ± 0.0073 (11/50); + night signals −0.0038 ± 0.0060 (15/50);
  - pleasantness: HR + steps − time −0.0087 ± 0.0095 (9/50); + night signals +0.0007 ± 0.0089 (28/50).

  — [Own analysis: OUT/extra_checks.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/extra_checks.json)
- Strict (absolute) labels show the same pattern:
  - activation: time 0.680 ± 0.025 → v1 0.684 ± 0.025 → + night 0.679 ± 0.019;
  - pleasantness: time 0.638 ± 0.020 → v1 0.641 ± 0.030 → + night 0.632 ± 0.027.

  — [Own analysis: OUT/results.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results.json)
- For comparison, EmoPhone v1 CV (D-1 + D-2, 191 participants): time only 0.535 ± 0.017, time + HR 0.554 ± 0.012, 13 features 0.563 ± 0.010 — [Harmony docs/PROJECT.md §6.5](file:///Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- Harmony's HR-based sleep estimator vs Fitbit's own measured sleep, on the same answers:
  - z_sleep_min estimated vs measured: Spearman 0.45 (3,470 answers);
  - hours_since_wake estimated vs measured: Spearman 0.928 (3,834 answers);
  - "night unknown" agrees 94.6 % of the time.

  — [Own analysis: OUT/results.json "estimated_vs_measured_sleep"](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results.json)

### Inferences
- About 40 association tests were run, so at α = 0.05 about 2 nominally significant results are expected by chance. The three nominal ones should be pre-registered as hypotheses for the pilot, not used as features:
  - sleep minutes ↔ pleasantness, ρ = +0.096;
  - breathing rate ↔ lower activation, ρ = −0.087;
  - resting HR ↔ lower activation, ρ = −0.049.
- HRV is the signal the team hoped for, and it shows nothing here (AUROC 0.500). It is also the least portable to Apple Watch (RMSSD vs SDNN).
- On LifeSnaps, heart rate helps activation by about the same small amount as on EmoPhone (+0.007 to +0.012 AUROC). This replication of Harmony's core heart-rate signal, in another population with another Fitbit, is the most useful positive result of this round.
- Replacing the estimated sleep with measured sleep does not help (−0.005), even though Apple Watch provides measured sleep. Sleep is not where the predictive value lies for momentary labels.
- Activation AUROC is higher on LifeSnaps (0.60) than on EmoPhone (0.56–0.58), but the gain sits almost entirely in "time only" (0.588): fixed morning/afternoon/evening sampling plus "tired in the evening". It reflects the label construct and schedule, not better sensing.

### Gaps
- No mixed-effects models (statsmodels is not installed in the venv). Within-person effects were estimated by within-person centring and participant bootstrap instead.
- Weekly PANAS and S-STAI (about 5–6 per person) were not related to the night signals: too few points per person for within-person analysis.
- Night signals were tested as z-scores against the last 14 nights. Other encodings (raw deviation, 3-night means, Fitbit's "3-day baseline" temperature fields) were not tried.

## 5. External test of the frozen EmoPhone model (`model_params.json`)

### Takeaway
Feasible, and done: Harmony v1 features were computed on LifeSnaps with `ml/features.py` unchanged. Local wall-clock times were shifted by −9 h so that the module's Korea offset yields the right local hour.

The frozen 13-feature model fails: AUROC 0.471 [0.446, 0.497], below chance. The cause is mostly time of day: the frozen time block scores 0.416, because EmoPhone students are predicted more activated late in the day while LifeSnaps adults report "tired" in the evening. The frozen heart-rate terms alone transfer weakly, in the right direction (0.530). This matches the UC Irvine result (0.496): the full model does not transfer between populations; only the heart-rate component does, weakly.

### Cited Findings
- Frozen model on 4,882 answers from 60 participants, target act_high:

  | Model | AUROC [95 % CI] | Balanced accuracy | Mean AUROC on the 5 CV test folds |
  |---|---|---|---|
  | 13 features, estimated sleep (as trained) | 0.471 [0.446, 0.497] | 0.504 | 0.471 ± 0.036 |
  | Same, with Fitbit-measured sleep in the 3 sleep slots | 0.475 [0.447, 0.502] | — | — |
  | `time_only` block | 0.416 [0.387, 0.450] | — | — |

  — [Own analysis: OUT/results.json "frozen_emophone_external_test"](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results.json)
- Partial frozen models:
  - time features set to the EmoPhone training means: 0.501;
  - only the 4 HR terms active: 0.530;
  - HR + steps terms active: 0.526.

  Single-feature AUROCs on LifeSnaps: z_hr_15 0.538, z_hr_30 0.540, z_hr_60 0.545, zb_hr_30 0.532, z_log_steps_30 0.531, z_sleep_min 0.511, hours_since_wake 0.423 — [Own analysis: OUT/extra_compact.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/extra_compact.txt)
- Standardised coefficients, model fitted on LifeSnaps vs EmoPhone:

  | Feature | LifeSnaps | EmoPhone |
  |---|---:|---:|
  | hour_cos | −0.424 | +0.047 |
  | hour_sin | +0.045 | −0.063 |
  | sleep_unknown | −0.103 | +0.119 |
  | z_hr_15 | +0.120 | +0.122 |
  | zb_hr_30 | −0.262 | +0.047 |
  | z_hr_30 | +0.219 | −0.047 |

  — [Own analysis: OUT/extra_compact.txt](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/extra_compact.txt)
- Earlier Harmony results: frozen EmoPhone model on UC Irvine AUROC 0.496 (time only 0.504). "Chaque modèle ne gagne que sur ses propres données" ("each model only wins on its own data") — [Harmony docs/PROJECT.md §6.5](file:///Users/clement/Hanyang/Harmony/docs/PROJECT.md)

### Inferences
- The time-of-day prior is population- and instrument-specific, and its sign can flip. For the app this is a concrete risk: the "time only" fallback (§6.6 rule 3) could be confidently wrong for users whose daily rhythm differs from Korean students'.
- The heart-rate z-scores (higher heart rate than usual at the same time means more activated) are the one component that transfers to two other populations in the same direction (LifeSnaps 0.53–0.545 single-feature).
- The individual HR coefficients are unstable across datasets (z_hr_30 and zb_hr_30 swap signs), a sign of collinearity among the 4 HR features. A simpler single HR z-score would likely transfer better.
- This is an "external test" of a mismatched label: a categorical mood mapped to activation vs EmoPhone's arousal rating. A low score partly reflects the label mismatch, not only the model.

### Gaps
- Day-of-week and seasonal effects (round 1 is summer, round 2 winter) were not separated from the time-of-day effect.
- About 3 % of participants travelled across time zones (paper). Those periods were not excluded.

## 6. Decision: LifeSnaps for (a) external test, (b) extended-input training, (c) personal-model priors?

### Takeaway
- (a) Yes, as a secondary external test, if the team scores the heart-rate component and the time-only fallback separately, not just the full model. It has already shown that the time prior does not transfer.
- (b) No: the extended night signals add nothing measurable to momentary activation or pleasantness, and HRV is the wrong statistic for Apple.
- (c) Only in a limited way. Its per-person night-signal effects are indistinguishable from sampling noise, so the honest prior is "near zero". The personalisation check suggests personal data mostly calibrate how often a user is "above their usual", rather than ranking moments better than the population model, with 20–100 labels.

### Cited Findings
- Per-person heterogeneity of day-level correlations (participants with ≥ 10 days, median 42–46 days): the observed SD of per-person ρ mostly matches the SD expected from sampling noise alone (√(1.06/(n−3))):

  | Pair | Observed SD | Expected from noise |
  |---|---:|---:|
  | Activation ~ RMSSD | 0.179 | 0.211 |
  | Activation ~ resting HR | 0.207 | 0.211 |
  | Activation ~ skin temperature | 0.166 | 0.220 |
  | Activation ~ sleep minutes | 0.200 | 0.221 |
  | Activation ~ REM share | 0.244 | 0.218 |
  | Pleasantness ~ sleep minutes | 0.275 | 0.221 |
  | Pleasantness ~ breathing rate | 0.281 | 0.202 |

  The last two pairs are the only clear excesses — [Own analysis: OUT/extra_checks.json](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/extra_checks.json)
- Personalisation check. Setup: within each grouped-CV test fold, participants with ≥ 40 labels (38 people) are split in time order; the first half trains a personal logistic regression (C = 0.1, same features as (iii)) and the second half is the test.

  | Method | Mean per-person AUROC, activation | Pooled AUROC, activation | Mean per-person AUROC, pleasantness | Pooled AUROC, pleasantness |
  |---|---|---:|---|---:|
  | Population model only | 0.592 ± 0.130 | 0.585 | 0.558 ± 0.091 | 0.541 |
  | Personal model only | 0.568 ± 0.102 | 0.617 | 0.536 ± 0.108 | 0.626 |
  | Log-odds blend (prior weight k = 30 labels, chosen a priori) | 0.583 ± 0.097 | 0.626 | 0.544 ± 0.109 | 0.631 |

  — [Own analysis: OUT/results.json "personalisation_second_half"](file:///private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/v2/lifesnaps/out/results.json)
- Another group used LifeSnaps for mood: a medRxiv preprint (not peer-reviewed) used daily Fitbit data from 38 participants (about 1,200 person-days) and elastic net to separate sad/tense/anxious days from happy days, as a "proof of concept". Its performance figures could not be retrieved (medRxiv returned 403) — [medRxiv 2025.02.13.25322254, via search listing](https://medrxiv.org/content/10.1101/2025.02.13.25322254v1)

### Inferences
- (a) External test: worth keeping as a one-off frozen check, reported the way PROJECT.md §6.5 reports UC Irvine. It is the only open set with Apple-like night signals, and it already showed:
  - the full model fails (0.471);
  - the time block flips sign (0.416);
  - the HR terms transfer weakly (0.53).

  It should not decide model replacement (label mismatch, 60 people, schedule-driven time effects).
- (b) Training extended inputs: not justified by the evidence.
  - Adding the 9 night signals costs 0.001–0.004 AUROC on activation and gains 0.000–0.002 on pleasantness.
  - Coverage is poor for exactly the novel signals: RMSSD and breathing rate known for 48 % of answers, SpO2 for 29 %.
  - The HRV statistic differs from Apple's.
  - If the team still wants one extra input, the least weak candidate is measured sleep duration for pleasantness (day ρ = +0.096). Even that did not raise grouped-CV AUROC.
- (c) Priors for an on-device personal model:
  - LifeSnaps can supply priors for heart-rate effects (positive, small) and "near-zero, small-variance" priors for night-signal effects.
  - Within-person ranking: the population model was not beaten by a 20–100-label personal model, and blending did not help on average.
  - Pooled AUROC (which also rewards getting each person's base rate right) improved with personal data: 0.585 → 0.626 for activation.

  So the cheapest useful personalisation is a per-user intercept or threshold (calibrating how often "higher than usual" fires), not per-user slopes on night signals. That conclusion depends on this label construct and on the 38 people with enough labels.
- Overall: LifeSnaps is worth downloading and keeping as evidence (done), and worth a short paragraph in the report. It does not justify adding HRV, temperature, SpO2 or respiratory-rate inputs to the shipped model.

### Gaps
- The personalisation check uses one split rule (first half / second half) and one blend weight (k = 30), not tuned. A sweep over label counts (10, 20, 40, 80) would show how many labels a user must give before personal data help. Not done, to avoid tuning on this small set.
- The step-goal EMA (3,852 scheduled) and context answers (PLACE) were not used. Place could be an extra non-sensor context feature, but the app does not collect it.
