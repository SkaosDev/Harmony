# In-the-wild datasets pairing consumer wearables with self-reported affect, stress or mood (status as of November 2026)

Scope note: facts below come from the cited pages (dataset papers, official repositories, data pages). Where I could only see a search-engine snippet or summary and not the page itself, the line says "(snippet)". Lines under "Inferences" are my judgement, not facts from a source. The Apple Watch specifics (HR about one sample every 4–5 min outside workouts, sparse SDNN, and so on) come from the brief, not from a source.

---

## 1. Which candidate datasets exist, and what do they contain (population, N, duration, devices, signal resolution)?

### Takeaway
Only a handful of open or requestable datasets combine a consumer wrist wearable with repeated in-the-moment affect labels: EmoPhone (the team's own), K-EmoPhone, LifeSnaps, TILES-2018/2019 and Tesserae. Two recent additions are relevant: the EmoPhone paper itself (arXiv, Sept 2026) and OpenMHC (2026), the first large open dataset of real Apple Watch/HealthKit data, although it has no momentary affect labels. The ETRI lifelog sets are Korean, but they are tiny (2023/2024, Galaxy Watch) or use a research device (2020, Empatica E4).

### Cited Findings

**EmoPhone (team's current dataset; now described in a 2026 paper)**
- 3 annual waves (D-1, D-2, D-3) at one Korean university: 282 distinct participants (297 participant-waves) and 53,139 ESM responses in total (10,259 / 21,042 / 21,838). Mean span was 22.5 / 31.7 / 30.2 days. Prompts were sent 15 / 12 / 10 times a day and drew about 7 responses per active day — [EmoPhone arXiv 2609.16581v2](https://arxiv.org/html/2609.16581v2)
- Fitbit Inspire HR in all waves: heart rate at 1 Hz; steps, calories and distance at 1/60 Hz (per minute). **A Polar H10 chest sensor was also deployed for assigned sub-periods in D-1 and D-2.** Smartphone sensing used ABC Logger on Android, and keystroke sensing was added from D-2 — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v2)

**K-EmoPhone (KAIST, Sci Data 2023)**
- 77 students over 7 days; 5,582 self-reported affect states. Devices were Android phones plus a Microsoft Band 2 — [Sci Data](https://www.nature.com/articles/s41597-023-02248-2)
- MS Band 2 streams: HR at 1 Hz, skin temperature at 1 Hz, EDA (skin resistance) at 5 Hz, step count and distance at 1 Hz, and wrist acceleration. Participants wore the band from 10 AM to 10 PM only (not during sleep) — [Sci Data](https://www.nature.com/articles/s41597-023-02248-2)
- The MS Band 2 companion app stopped working on 31 May 2019, so the device can no longer be used — [Sci Data](https://www.nature.com/articles/s41597-023-02248-2)

**LifeSnaps (Sci Data 2022, Fitbit Sense)**
- n = 71 participants (24 in Sweden, 10 in Italy, 25 in Greece, 12 in Cyprus), recruited through university mailing lists. Data cover more than 4 months in two rounds, with about 8 weeks per participant. More than 35 data types range from second to daily granularity, for over 71 M rows — [Sci Data](https://www.nature.com/articles/s41597-022-01764-x)
- Fitbit Sense data types (32): steps, sleep (including sleep phases), physical activity, heart rate, HRV, EDA responses, ECG, SpO2, VO2max, nightly temperature, respiratory rate and Fitbit stress indicators. Mean Fitbit engagement was 41.37 days per user — [Sci Data](https://www.nature.com/articles/s41597-022-01764-x)
- Released as raw MongoDB BSON plus CSV aggregates at daily and hourly granularity; 615 MB zip — [Zenodo 7229547](https://zenodo.org/records/7229547)

**TILES-2018 (USC, Sci Data 2020)**
- 212 volunteer hospital workers at USC Keck Hospital, 10 weeks each, in 3 waves — [Sci Data](https://www.nature.com/articles/s41597-020-00655-3)
- Fitbit Charge 2 worn day and night. HR samples are aggregated over intervals of less than 1 min, with non-uniform spacing. Steps are per minute. Daily summaries include resting HR and sleep with 4 stages (awake, light, deep, REM). An OMsignal ECG garment was worn at work, plus an audio-feature badge, beacons and phone usage logs — [Sci Data](https://www.nature.com/articles/s41597-020-00655-3)

**TILES-2019 (USC, Sci Data 2022)**
- 57 medical residents on a 3-week ICU rotation at LAC+USC. Fitbit Charge 3: HR at non-uniform intervals of about 5 s to 15 min depending on activity, steps per minute, and a daily summary with sleep stages. Also a proximity sensor and an audio-feature recorder — [Sci Data](https://www.nature.com/articles/s41597-022-01636-4)
- Collection ran from November 2019 to April 2020, partly during the first COVID wave (snippet) — [PMC12449669](https://pmc.ncbi.nlm.nih.gov/articles/PMC12449669)

**Tesserae (Notre Dame and others, Garmin)**
- 757 information workers across the US, measured through smartwatches, a phone agent, beacons and social media (snippet) — [tesserae.nd.edu](https://tesserae.nd.edu/)
- In a Tesserae analysis, 657 participants wore a fitness tracker and completed 14,695 EMAs over 8 weeks (snippet) — [JMIR Hum Factors 2022 / PMC9389384](https://pmc.ncbi.nlm.nih.gov/articles/PMC9389384/)

**GLOBEM (U. Washington, PhysioNet; NeurIPS D&B 2022)**
- 4 yearly datasets (2018–2021), 10 weeks each in the spring quarter: 705 person-years from 497 unique undergraduates at one US R1 university. Fitbit plus an AWARE phone app; on average 77.5 ± 8.9 days per person per year — [PhysioNet](https://physionet.org/content/globem/1.1/)
- **Only derived features are released** (RAPIDS daily features over morning / afternoon / evening / night / 7- and 14-day segments): location, screen, calls, Bluetooth, steps and sleep. No raw time series — [PhysioNet](https://physionet.org/content/globem/1.1/)

**PMData (Simula, MMSys 2020, Fitbit Versa 2)**
- Fitbit Versa 2 plus the PMSys sports-logging app plus Google Forms. Sources disagree on size: the Simula page says 12 persons over 3 months, and the paper says 16 persons over 3 or 5 months (snippet) — [Simula PMData](https://datasets.simula.no/pmdata)
- Fitbit files: heart_rate.json (bpm at given times), steps per minute, sleep.json split into light, deep, REM and awake periods, resting HR per day, and minutes in HR zones — [HF mirror of the dataset card](https://huggingface.co/datasets/wellness10/PMData_sports_logging_dataset)

**NetHealth (Notre Dame)**
- An undergraduate cohort that entered Notre Dame in fall 2015 and was followed to 2019; each participant received a Fitbit HR (snippet) — [NetHealth](https://sites.nd.edu/nethealth/)
- **Raw minute-by-minute HR is not released.** Only daily mean and SD of HR, a compliance score and daily sleep summaries are available — [NetHealth Fitbit page](https://sites.nd.edu/nethealth/fitbit-data/)

**ETRI Lifelog datasets (Korea)**
- 2020: 22 subjects, 616 days, over 10,000 h of data, with Empatica E4 (PPG, EDA, skin temperature), phone sensing and a Withings sleep mat. 10,372 user labels with emotional states and 590 days of sleep quality — [ETRI Journal 2022 (KoreaScience)](https://koreascience.or.kr/article/JAKO202258262128219.page?lang=en)
- 2023 (used in the 2024 challenge): the training set is the 2020 data (Empatica E4). The 2023 validation and test data used a **Galaxy Watch4 or Watch5** for HR (bpm), steps (walking and running) and light intensity, plus a phone and a Withings mat. Validation (IDs 1–4) and test (IDs 5–8) come from the same cohort under different random IDs — [ETRI challenge 2024 arXiv 2403.16509](https://arxiv.org/html/2403.16509v1)
- 2024: 10 participants and 700 days (May–Dec 2024), with smartphones, smartwatches and under-mattress sleep sensors. The paper says this is up from 4 participants and 220 days in the 2023 set — [ETRI Lifelog 2024 arXiv 2508.03698](https://arxiv.org/html/2508.03698v1)

**OpenMHC (MyHeart Counts, Stanford; NeurIPS 2026 D&B poster) — Apple Watch / HealthKit**
- 11,894 shareable participants (out of 16,993), with over 67 M participant-hours of wearable data. There are up to 19 minute-resolution channels from iPhone and Apple Watch via HealthKit: steps, distance, flights, exercise time, stand time, heart rate, active energy, sleep stages and workout types. Seven sparse HealthKit variables (including HRV, resting HR and VO2max) are released separately — [OpenMHC arXiv 2607.16235](https://arxiv.org/html/2607.16235)
- The paper states that "the Apple Watch does not record heart rate every minute"; zero minutes are treated as missing. It also notes that HealthKit does not mark missingness explicitly — [OpenMHC](https://arxiv.org/html/2607.16235)

**Intern Health Study (Michigan)**
- Fitbit sleep and steps plus daily mood in an app. One analysis covers 2,602 interns and 168,311 Fitbit days (snippet) — [PMC10829990](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10829990/)

**Homekit2020 (Evidation)**
- More than 14 million hours of minute-level multimodal Fitbit data, plus symptom reports and laboratory PCR influenza results — [PMLR 2023](https://proceedings.mlr.press/v209/merrill23b.html)

**Welltory COVID-19**
- HRV measurements from Bluetooth HR monitors or smartphone-camera PPG, data from connected gadgets (Apple Watch, Garmin via Google Fit or Apple Health), and symptom and test reports. CSV files are on GitHub — [Welltory hrv-covid19 README](https://github.com/Welltory/hrv-covid19)
- A Welltory-affiliated preprint used only 14 eligible COVID subjects (snippet) — [medRxiv](https://www.medrxiv.org/content/10.1101/2021.07.02.21259891v1)

**All of Us**
- The Registered Tier includes Fitbit data from participants who opted to share it; one source says more than 8,000 participants (snippet, count likely outdated) — [All of Us data tiers](https://www.researchallofus.org/?p=2914); [Wearables article](https://support.researchallofus.org/hc/en-us/articles/20281023493908)

**Other datasets found (2021–2026)**
- *WatchAnxiety* (arXiv, Sept 2025): socially anxious college students (N = 91; 72 after exclusions), Samsung Galaxy Watch 5 / 5 Pro, about 9 days on average. The model used heart rate only. Data release not stated — [arXiv 2509.13725](https://arxiv.org/html/2509.13725v1)
- *Loneliness & well-being in Finnish immigrants* (UC Irvine / Turku, Dryad 2025): 39 participants over 28 days, with Oura Ring, **Samsung Galaxy Watch Active 2** and AWARE phone data, plus questionnaires (PHQ-9, PSS, UCLA Loneliness). Licence CC0 — [UCI page](https://futurehealth.uci.edu/resources/dataset-loneliness-and-well-being-in-finnish-immigrants/); [Dryad](https://datadryad.org/dataset/doi:10.5061/dryad.qz612jmrn)
- *WARN-D* (Leiden): about 2,000 Dutch students followed for 2 years, with a Garmin vívosmart 4 and daily smartphone EMA in the first 3 months (snippet) — [Garmin blog](https://www.garmin.com/en-AU/blog/?p=2709); [protocol](https://cpe.psychopen.eu/index.php/cpe/article/download/10075/10075.html?inline=1)
- *DAPPER* (Sci Data 2021, China): 142 participants over 5 days, 88 of whom wore a custom wristband (HR, GSR). ESM 6 times a day plus an end-of-day DRM (snippet) — [Sci Data](https://www.nature.com/articles/s41597-021-00945-4)
- *GalaxyPPG* (Sci Data 2025, KAIST): Galaxy Watch 5 plus Empatica E4, 24 participants. Daily activities and a stress test in a semi-naturalistic protocol, not in-the-wild EMA (snippet) — [PMC12119839](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12119839/)
- *BEmotion*: smartwatch PPG HR and IBI plus accelerometer, collected at job fairs, 44 participants (snippet) — [ACM](https://doi.org/10.1145/3820253.3820282)
- *DiversityOne* (782 participants, 8 countries, 350k self-reports) and the *College Experience Study* (Dartmouth, 215 participants, weekly EMA) are **phone-only**, with no wearable — [EmoPhone Table 1](https://arxiv.org/html/2609.16581v2); [CES arXiv 2503.08002](https://arxiv.org/pdf/2503.08002)

### Inferences
- Only EmoPhone, K-EmoPhone, LifeSnaps, TILES-2018 and Tesserae have at least about 50 participants, a consumer wrist wearable worn for weeks, and repeated affect or stress self-reports. Every other dataset fails at least one of these.
- No dataset with both momentary affect labels and real Apple Watch data surfaced. OpenMHC is the only large source of real Apple Watch HealthKit data, and its labels are sparse well-being surveys (see §2).
- The Polar H10 sub-periods inside EmoPhone D-1/D-2 are an under-used resource. They give beat-to-beat ground truth for building an SDNN-like feature comparable to Apple's sparse SDNN.

### Gaps
- Tesserae Garmin model and its exact HR/HRV resolution: not verified from a primary page.
- PMData: exact N and duration conflict (12 vs 16 people; 3 vs 5 months); Fitbit HR sampling interval not verified.
- ETRI 2024 watch model and sampling rates: the nanum.etri.re.kr pages could not be fetched (connection refused).
- All of Us Fitbit granularity (minute-level HR or not) and current participant count: support pages returned 403.
- Homekit2020 participant count and the Synapse access steps: the GitHub README returned 404; not verified.
- DAPPER and BEmotion: access route and licence not verified.

---

## 2. Labels: which items, what scale, how often, momentary or retrospective?

### Takeaway
Only EmoPhone and K-EmoPhone have dimensional, many-times-a-day momentary valence, arousal and stress. LifeSnaps has 3 categorical mood EMAs a day. TILES-2018 has one daily momentary stress and anxiety item plus PANAS-short. TILES-2019 and Tesserae have stress EMAs. Most others have daily or weekly labels, or none.

### Cited Findings
- **EmoPhone**: valence (very negative to very positive), arousal (very calm to very excited), stress, attention, task disturbance, mental load, ChangedValence/ChangedArousal, and duration of the current emotion. D-3 adds 8 custom affect-intensity items (e.g., happy, angry, depressed) and rescales stress and disturbance — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v2)
- **K-EmoPhone**: ESM up to 16 prompts a day at random times between 10 AM and 10 PM, about every 45 min on average and at least 30 min apart. Each prompt expired after 10 min. Valence and arousal were rated on 7-point scales, alongside stress, attention, task disturbance and emotion change — [Sci Data](https://www.nature.com/articles/s41597-023-02248-2)
- **K-EmoPhone class balance** after binarising (>0 = HIGH, 2,619 usable responses): arousal 1,033 HIGH vs 1,586 LOW; valence 1,556 vs 1,063; stress 917 vs 1,702 — [Sci Data](https://www.nature.com/articles/s41597-023-02248-2)
- **LifeSnaps**: a SEMA3 "Context and Mood" EMA 3 times a day (morning, afternoon, evening), asking for location and current feeling as categorical choices (e.g., HAPPY, TENSE/ANXIOUS, TIRED, SAD), plus a daily step-goal EMA. There are more than 15 K EMA self-reports in total, step-goal ones included. **PANAS and S-STAI were collected weekly** by e-mail; S-STAI was administered on a 5-point scale by error and rescaled — [Sci Data](https://www.nature.com/articles/s41597-022-01764-x)
- **TILES-2018**: daily single-item stress ("Overall, how would you rate your current level of stress?") and anxiety ("…how anxious you feel at the moment"), plus PANAS-short (5 PA + 5 NA). These sit inside a job, health or personality survey sent once a day at 6 am, noon or 6 pm and expiring after 4 h (71 surveys over 10 weeks). Released EMA files are scored items, and raw answers to specific questions were removed for privacy — [Sci Data](https://www.nature.com/articles/s41597-020-00655-3)
- **TILES-2019**: a one-item current-stress survey at 12:15 pm (open 4 h) and an end-of-day survey at 6:15 pm on stressors, work and sleep. Compliance was 77.2% (midday) and 69.7% (end of day). PANAS was asked for the past week — [Sci Data](https://www.nature.com/articles/s41597-022-01636-4)
- **Tesserae**: EMAs on perceived stress, anxiety, positive affect and negative affect (14,695 EMAs from 657 people over 8 weeks) (snippet) — [PMC9389384](https://pmc.ncbi.nlm.nih.gov/articles/PMC9389384/)
- **GLOBEM**: PHQ-4, PSS-4 and PANAS (10-item) as a **weekly EMA** (years 2–4), plus pre/post long surveys. The benchmark label is depression — [PhysioNet](https://physionet.org/content/globem/1.1/)
- **PMData**: a daily wellness report with fatigue, mood, readiness, sleep duration, sleep quality, soreness (and area) and stress. Fatigue, mood, soreness, stress and sleep quality are on a 1–5 scale; readiness is 0–10 on the page vs 1–10 in the paper. About 975 reports, 44–112 per participant (snippet) — [Simula PMData](https://datasets.simula.no/pmdata)
- **ETRI 2020**: user labels include 2D arousal–valence emotional states on seven-point Likert scales (snippet of the nanum release) — [nanum ETRI 2020](https://nanum.etri.re.kr/share/schung/ETRILifelogDataset2020)
- **ETRI 2023/2024 challenge targets** are **daily**: Q1 sleep quality right after waking; Q2 emotional state before sleep (2023), replaced by fatigue before sleep in 2024; Q3 stress before sleep. Q1–Q3 are binarised against each participant's own mean — [arXiv 2403.16509](https://arxiv.org/html/2403.16509v1); [arXiv 2508.03698](https://arxiv.org/html/2508.03698v1)
- **OpenMHC**: "Mental Well-being" survey items "How about depressed/happy/worried?", life satisfaction and "things are worthwhile", each 0–10 and binned into 4 classes. These serve as static prediction targets, not momentary labels — [OpenMHC](https://arxiv.org/html/2607.16235)
- **Intern Health Study**: a single daily mood item, "On a scale of 1 (lowest) to 10 (highest), how was your mood today?" (snippet) — [search result; PMC10084890](https://pmc.ncbi.nlm.nih.gov/articles/PMC10084890)
- **WatchAnxiety**: EMA "I feel…" with a 1–10 slider from "not at all anxious" to "very anxious" (snippet) — [arXiv 2509.13725](https://arxiv.org/html/2509.13725v1)
- **WARN-D**: wearable and EMA measures agreed well for sleep, more weakly for tiredness, and stress measures mostly did not line up (781 students) (snippet) — [search summary of 2025 validation paper; protocol page](https://cpe.psychopen.eu/index.php/cpe/article/download/10075/10075.html?inline=1)
- **NetHealth, Homekit2020, Welltory**: no momentary affect labels. Homekit2020 has flu symptom reports and PCR results; Welltory has COVID symptoms and test results — [PMLR](https://proceedings.mlr.press/v209/merrill23b.html); [Welltory README](https://github.com/Welltory/hrv-covid19)

### Inferences
- Label match to "arousal above the person's usual level":
  - **K-EmoPhone** matches EmoPhone exactly: same lab, same 7-point items, same binarisation approach. It can be pooled directly.
  - **LifeSnaps** needs a mapping from mood categories to an arousal proxy (e.g., tense/anxious or happy = higher activation; tired or relaxed = lower). That is a lossy, debatable mapping that would have to be documented.
  - **TILES-2018** stress and anxiety "at the moment" can serve as a stress output and a weak arousal proxy, but only once a day.
- For new outputs: valence + arousal + stress are available only in EmoPhone and K-EmoPhone. Stress alone is available in TILES-2018/2019, Tesserae, PMData (daily) and ETRI 2023/24 (daily, before sleep).

### Gaps
- Full list of LifeSnaps mood categories (only HAPPY, TENSE/ANXIOUS, TIRED and SAD seen) and the exact count of mood EMAs, as distinct from step-goal EMAs.
- TILES-2018 stress and anxiety response scales (number of points) not retrieved.
- ETRI 2020 label frequency: about 10,372 labels over 616 days (≈ 17 per day, my calculation), but the trigger (per activity change or by schedule) is not verified.
- WARN-D EMA frequency: "daily" per snippet, not verified on a primary page.

---

## 3. Access, approval time and licence

### Takeaway
Downloadable today without approval: LifeSnaps (CC BY 4.0), PMData (CC BY-NC 4.0), the Welltory CSVs, and the UCI Finnish immigrants dataset (CC0). Signed DUA: TILES-2018/2019, Tesserae (DUA plus proposal; only a social-media corpus is currently listed), K-EmoPhone (Zenodo request plus EULA), EmoPhone (credentialed Dataverse plus DUA), OpenMHC (click-through DUA, non-commercial). Credentialed: GLOBEM (PhysioNet plus CITI training). Institution-level: All of Us (the institution needs a DURA, which takes months).

### Cited Findings
- **LifeSnaps**: open on Zenodo under Creative Commons Attribution 4.0 International. The paper adds a code of conduct, notably no attempts at re-identification — [Zenodo](https://zenodo.org/records/7229547); [Sci Data](https://www.nature.com/articles/s41597-022-01764-x)
- **K-EmoPhone**: Zenodo record with files restricted. Access needs a Zenodo request and a separate user-agreement (EULA) form with a justification, and requests may be refused — [Zenodo 7606611](https://zenodo.org/records/7606611)
- **EmoPhone**: code under Apache-2.0 and documentation under CC BY 4.0. Data files are under credentialed access with a dataset-specific DUA (no re-identification, no redistribution) — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v2)
- **TILES-2018/2019**: a signed DUA (no de-anonymisation, no sharing with non-signers) submitted at tiles-data.isi.edu. One account covers both, but each dataset needs its own DUA — [TILES-2018](https://www.nature.com/articles/s41597-020-00655-3); [TILES-2019](https://www.nature.com/articles/s41597-022-01636-4)
- **Tesserae**: certain fully de-identified elements are shared with qualified researchers under a DUA. The page lists only the "Social Media Corpus" as available. **Note dated Dec 2025: "the usage of LLMs is disallowed on the data."** — [Tesserae data sharing](https://tesserae.nd.edu/data-sharing/)
- **GLOBEM**: PhysioNet credentialed access. Users must be a credentialed user, complete CITI "Data or Specimens Only Research" training and sign the DUA. Licence: PhysioNet Credentialed Health Data License 1.5.0 — [PhysioNet](https://physionet.org/content/globem/1.1/)
- **PMData**: licensed Attribution-NonCommercial 4.0 International (snippet) — [Simula PMData](https://datasets.simula.no/pmdata)
- **OpenMHC**: free via Harvard Dataverse (full set doi:10.7910/DVN/XNBITM; 5% subset doi:10.7910/DVN/RIKSK4) behind a click-through Stanford DUA. Personal, non-commercial research only. Each user registers individually, and no portion may be distributed, published or reproduced without written permission. The DUA's derivative-works clause is cut off in my extract — [OpenMHC](https://arxiv.org/html/2607.16235)
- **All of Us**: international researchers may register, but only after their institution signs a Data Use and Registration Agreement (DURA), which can take several months — [All of Us support FAQ](https://support.researchallofus.org/hc/en-us/articles/35013049400468)
- **NetHealth**: Fitbit activity and sleep summaries can be downloaded. Linked survey, Fitbit and communication data require a request describing the project and a promise not to share (snippet) — [NetHealth](https://sites.nd.edu/nethealth/)
- **Intern Health Study**: survey data (pre-internship plus quarterly PHQ-9 and GAD-7) are on openICPSR (project 129225). No public release of the Fitbit or daily-mood data was found (snippet) — [Princeton DSS catalog](https://dss.princeton.edu/catalog/resource5529)
- **ETRI**: 2020 and 2024 releases are hosted on nanum.etri.re.kr; the 2024 paper calls them publicly available for research — [arXiv 2508.03698](https://arxiv.org/html/2508.03698v1)
- **WARN-D**: the protocol says a data-sharing protocol was being developed, to be ready around 2025/2026. No published version was found (snippet) — [WARN-D protocol](https://cpe.psychopen.eu/index.php/cpe/article/download/10075/10075.html?inline=1)
- **MyHeart Counts (original 2019 release)**: users register through Synapse and fill out an application before approval — [Stanford Medicine 2019](https://med.stanford.edu/news/insights/2019/04/myheart-counts-health-data-released-for-external-research.html)
- **UCI Finnish immigrants**: Dryad, CC0 — [UCI](https://futurehealth.uci.edu/resources/dataset-loneliness-and-well-being-in-finnish-immigrants/)

### Inferences
- Feasibility within 1–4 weeks:
  - **Days**: LifeSnaps, PMData, UCI Finnish, Welltory, OpenMHC (click-through).
  - **Likely 1–4 weeks, approval time not published**: TILES-2018/2019, K-EmoPhone.
  - **Uncertain or slow**: Tesserae (proposal; wearable data not currently listed), GLOBEM (CITI training plus credentialing, usually days to a few weeks), All of Us (months via the institution's DURA).
  - **Not available**: Intern Health Fitbit/mood, WARN-D.
- Publishing a trained model:
  - CC BY (LifeSnaps) clearly allows it with attribution.
  - CC BY-NC (PMData) and OpenMHC are non-commercial only. OpenMHC's "no publication of any portion without permission" plus its derivative-works clause need careful reading before shipping a model in an app.
  - The TILES and K-EmoPhone DUAs/EULAs were not read in full. Check them before bundling a Core ML model trained on them.
- Tesserae's ban on LLM use is worth noting if any pipeline step would involve an LLM. Harmony's Worker only sees song titles, so this probably does not apply.

### Gaps
- Typical approval times for TILES, K-EmoPhone and Tesserae: none published.
- Full text of the TILES DUA, the K-EmoPhone EULA and the OpenMHC derivative-works clause (does a trained model count as a derivative?): not retrieved.
- ETRI nanum licence or terms of use and any registration requirement: page unreachable.
- Welltory licence: no licence file was seen in the README extract.

---

## 4. Published baselines for affect or stress prediction (with evaluation split)

### Takeaway
Published subject-independent results on consumer-wearable momentary affect sit around AUROC 0.55–0.60 or macro-F1 around 0.53–0.54. The EmoPhone paper's own best within-wave cross-user arousal AUROC is 0.584, which is close to the team's 0.57. Within-user (personalised, temporal) evaluation does better (arousal AUROC 0.609 in EmoPhone).

### Cited Findings
- **EmoPhone benchmark** (stratified 5-fold group split by participant within each wave):
  - Best arousal AUROC 0.584 ± 0.022 (MCD), valence 0.576 (MCC), stress 0.554 (SHOT).
  - Cross-wave (train on one wave, test on another): arousal 0.564 (IRM), stress 0.525.
  - Within-user temporal: arousal 0.609, stress 0.627, valence 0.601 (XGBoost).
  - Domain generalisation (DG) and domain adaptation (UDA) methods did not significantly beat the strongest supervised model after Holm correction.
  — [EmoPhone arXiv](https://arxiv.org/html/2609.16581v2)
- **K-EmoPhone**: leave-one-subject-out (LOSO) CV on 47 participants (2,619 responses), XGBoost and Random Forest with SMOTE-NC. Macro-F1 was 0.53 for valence and 0.54 for arousal. Previous affect was the most important feature; for arousal, extraversion and social-app use mattered — [Sci Data](https://www.nature.com/articles/s41597-023-02248-2)
- **WatchAnxiety** (Galaxy Watch 5, HR only): 60.4% balanced accuracy for state anxiety. External validation on TILES-18 gave 38.5% recall and 58.9% specificity over 10,095 EMAs (snippet; split type not verified) — [arXiv 2509.13725](https://arxiv.org/html/2509.13725v1)
- **Tesserae HRV vs perceived stress**: models explained on average 1% (SD 0.5%) of the variance (marginal R²), and 2.2% for the 8 AM–6 PM window. The authors conclude that wearable HRV alone is not sufficient to detect stress in naturalistic settings (snippet) — [PMC9389384](https://pmc.ncbi.nlm.nih.gov/articles/PMC9389384/)
- **LifeSnaps**: a medRxiv preprint (2025) used daily Fitbit data from 38 participants to predict happy vs tense/anxious-or-sad vs neither days with multinomial elastic net. It used 5-fold CV (not stated as participant-held-out) and reports "relatively modest accuracy" (snippet; numbers not retrieved) — [medRxiv](https://medrxiv.org/content/10.1101/2025.02.13.25322254v1)
- **LifeSnaps S-STAI**: an MDPI 2025 paper predicts state and trait anxiety from Fitbit plus surveys (snippet; numbers and split not retrieved) — [MDPI Appl Sci 15(19):10519](https://www.mdpi.com/2076-3417/15/19/10519)
- **GLOBEM**: 18 algorithms on depression detection (cross-dataset or cross-year). The best, "Reorder", improved balanced accuracy over the majority baseline by 25.2% within a single dataset but only 9.7% across datasets. The authors note a significant drop from single-dataset to cross-dataset (Δ 7.6 ± 6.7%) (snippet) — [GLOBEM arXiv](https://arxiv.org/pdf/2211.02733)
- **ETRI 2024**: the paper presents a baseline for sleep-quality prediction with SHAP feature importance; numbers not retrieved — [arXiv 2508.03698](https://arxiv.org/html/2508.03698v1)

### Inferences
- The team's AUROC of about 0.57 (logistic regression, 13 features, participants held out) is already within 0.01–0.02 of the EmoPhone authors' best deep and domain-adaptation models in the same setting. More data from a *different* population is unlikely to push cross-person AUROC much above about 0.6. Tesserae (≈1% variance explained by HRV) and WARN-D (stress EMA vs wearable mostly misaligned) point the same way.
- The clearest headroom shown in the literature is per-user adaptation: the EmoPhone temporal benchmark beats within-wave by +0.025 to +0.07 AUROC depending on label. For an app this suggests on-device personalisation, for example updating the user's personal baseline or few-shot recalibration from in-app feedback, rather than a larger population model.
- K-EmoPhone's top feature was the previous affect report. Harmony has no affect self-report at inference time, so published results that use previous-label features overstate what the app can achieve.

### Gaps
- No LOSO baseline for momentary affect on LifeSnaps or TILES-2018 was found in the time available.
- WatchAnxiety's split type and data availability are not verified.
- GLOBEM per-algorithm absolute numbers (only relative Δ seen).

---

## 5. Fit for the Harmony app (Apple Watch signal equivalence, label match, population match)

### Takeaway
For widening inputs and outputs within 1–4 weeks, the most practical additions are K-EmoPhone (best label and population match, small), LifeSnaps (open now, richest Fitbit signals with Apple equivalents, weaker labels) and TILES-2018 (DUA, adds a daily stress and anxiety output). OpenMHC is the only source of real Apple Watch HealthKit data, useful to calibrate sampling and missingness, not as a label source. The rest are poor fits or inaccessible.

### Cited Findings
- Heart-rate resolution varies:
  - EmoPhone Fitbit Inspire HR: 1 Hz — [EmoPhone](https://arxiv.org/html/2609.16581v2)
  - K-EmoPhone MS Band 2: 1 Hz, 10 AM–10 PM only — [K-EmoPhone](https://www.nature.com/articles/s41597-023-02248-2)
  - TILES Fitbit: non-uniform, under 1 min (2018) or about 5 s–15 min (2019) — [TILES-2018](https://www.nature.com/articles/s41597-020-00655-3); [TILES-2019](https://www.nature.com/articles/s41597-022-01636-4)
  - Apple Watch in OpenMHC: not every minute — [OpenMHC](https://arxiv.org/html/2607.16235)
- Sleep stages:
  - Fitbit in TILES gives 4 stages (awake, light, deep, REM) — [TILES-2018](https://www.nature.com/articles/s41597-020-00655-3)
  - LifeSnaps includes sleep phases, nightly temperature, respiratory rate and SpO2 — [LifeSnaps](https://www.nature.com/articles/s41597-022-01764-x)
  - OpenMHC has Apple sleep stages as binary minute channels — [OpenMHC](https://arxiv.org/html/2607.16235)
- K-EmoPhone's own paper notes that commercial Fitbit, Garmin and Apple wearables offer sensing similar to the MS Band 2, but some modalities are missing — [K-EmoPhone](https://www.nature.com/articles/s41597-023-02248-2)
- The 2023 ETRI Galaxy Watch data include light intensity, which is the closest analogue among these datasets to Apple's "time in daylight" — [arXiv 2403.16509](https://arxiv.org/html/2403.16509v1)
- Population:
  - EmoPhone and K-EmoPhone: Korean university students — [EmoPhone](https://arxiv.org/html/2609.16581v2); [K-EmoPhone](https://www.nature.com/articles/s41597-023-02248-2)
  - LifeSnaps: university-mailing-list recruits in Sweden, Italy, Greece and Cyprus — [LifeSnaps](https://www.nature.com/articles/s41597-022-01764-x)
  - TILES: hospital workers and medical residents — [TILES-2018](https://www.nature.com/articles/s41597-020-00655-3)
  - Tesserae: US information workers — [Tesserae](https://tesserae.nd.edu/)
  - GLOBEM: US undergraduates — [PhysioNet](https://physionet.org/content/globem/1.1/)
  - ETRI: Korean adults; the 2024 set was run with Chungnam National University Hospital (snippet) — [arXiv 2508.03698](https://arxiv.org/html/2508.03698v1)

### Inferences (judgement: comparison and ranking)

| Dataset | Wearable / Apple-equivalent signals | Affect labels (freq.) | N / span | Access (est. time) | Fit for Harmony |
|---|---|---|---|---|---|
| EmoPhone (current) | Fitbit Inspire HR: HR 1 Hz, steps/min; Polar H10 sub-periods | V/A/stress + more, ~7/day momentary | 282 / ~4 wk ×3 waves | Credentialed DUA (have it) | Baseline; already near published ceiling |
| **K-EmoPhone** | MS Band 2: HR 1 Hz, skin temp, EDA (no Apple equiv.), steps; daytime only, so no sleep | V/A/stress 7-pt, up to 16/day momentary | 77 / 7 days, 5,582 ESM | Zenodo request + EULA (~1–3 wk?) | **Best label + population match**; small; no sleep features, so test the subset of features without sleep |
| **LifeSnaps** | Fitbit Sense: HR, HRV, sleep stages, nightly temp, resp. rate, SpO2, steps (EDA/ECG no Apple equiv.) | Categorical mood 3/day; PANAS + S-STAI weekly | 71 / ~8 wk | Open, CC BY 4.0 (now) | **Best signal match**; label mapping to arousal is a judgement call; good external test set |
| **TILES-2018** | Fitbit Charge 2: HR <1 min, steps/min, 4-stage sleep | Stress, anxiety "now" + PANAS-short, ~1/day | 212 / 10 wk | DUA (~1–4 wk?) | Good for a **stress output**; daily cadence, so a weaker arousal proxy; non-student |
| TILES-2019 | Fitbit Charge 3: HR 5 s–15 min, steps/min, sleep | Midday stress (1/day) + end-of-day | 57 / 3 wk | DUA (same portal) | Small; marginal |
| Tesserae | Garmin (HR/HRV; model unverified) | Stress, anxiety, PA, NA EMAs | 657–757 / 8+ wk | DUA + proposal; wearable data not listed | Potentially strong but access uncertain and slow |
| OpenMHC | **Real Apple Watch/iPhone HealthKit**, 19 min-level channels; sparse HRV, RHR | Well-being 0–10 (sparse, static) | 11,894 | Click-through DUA, non-commercial | Use for Apple-like sampling and missingness simulation, normalisation priors, self-supervised pretraining; **not** for momentary labels |
| ETRI 2020 | Empatica E4 (research device) | V/A 7-pt emotion labels, ~17/day | 22 / 616 days | nanum registration | Korean + V/A labels, but research device; HR only transferable |
| ETRI 2023/2024 | Galaxy Watch4/5 (2023): HR, steps, light; Withings mat | Daily sleep quality, stress/emotion before sleep | 4 (2023), 10 (2024) | nanum | Too few people; daily labels |
| GLOBEM | Fitbit features only (steps, sleep) | Weekly PHQ-4/PSS-4/PANAS | 497 | PhysioNet credentialed + CITI | Poor: weekly labels, features only |
| PMData | Fitbit Versa 2: HR, steps/min, sleep stages | Daily mood, stress, fatigue, readiness (1–5) | 12–16 / 3–5 mo | Open, CC BY-NC | Tiny; daily; athletes |
| UCI Finnish immigrants | Oura + Galaxy Watch Active 2 | Questionnaires (+ daily check-ins, unverified) | 39 / 28 days | Open, CC0 | Small; similar to the weak UCI set already tested |
| WatchAnxiety | Galaxy Watch 5, HR | State anxiety 1–10 EMA | 72 / ~9 days | Unknown | Not known to be released |
| NetHealth | Fitbit daily summaries only | No momentary affect | ~700 (unverified) | Partly open | Poor |
| Intern Health | Fitbit sleep/steps | Daily mood 1–10 | ~2,600 | Fitbit/mood not public | Unavailable |
| Homekit2020 | Fitbit minute-level | Flu symptoms, PCR | Large | Synapse | No affect labels |
| Welltory | Mixed (camera PPG, Apple Watch, Garmin) | COVID symptoms | Small | GitHub CSV | No affect labels |
| All of Us | Fitbit | COPE mood surveys (2020–21) | >8,000 Fitbit users | Institution DURA (months) | Not feasible in 1–4 weeks |
| WARN-D | Garmin vívosmart 4 | Daily EMA (3 months) | ~2,000 | Sharing protocol not yet published | Watch for a future release |

- **Apple-equivalence rule (judgement)**: build every candidate feature from streams that can be degraded to Apple Watch cadence.
  - Subsample 1 Hz or 5 s HR to one reading per 4–5 min, at random offsets, before computing z-scores.
  - Aggregate steps to the same windows as in the app.
  - Map Fitbit's light/deep/REM/wake onto Apple's core/deep/REM/awake.
  - Treat Fitbit nightly temperature and respiratory rate (LifeSnaps) as stand-ins for Apple sleeping wrist temperature and sleeping respiratory rate.
  - Exclude EDA, ECG, SpO2 spot checks, RRI streams and skin temperature at 1 Hz (K-EmoPhone): Apple gives third-party apps no continuous equivalent.
  - OpenMHC can provide realistic Apple Watch HR gaps and timing to make this degradation faithful.
- **Multi-output (judgement)**: a valence + arousal + stress model can be trained on EmoPhone and K-EmoPhone pooled (same instrument family). TILES-2018 can add a stress/anxiety head and serve as external validation. LifeSnaps can act as an out-of-population test for a coarse "activated vs not" proxy.
- **Expected gain (judgement)**: given the published ceilings in §4, adding datasets mainly buys robustness and an honest external test, not a large AUROC jump. Personalisation on the device is the more promising lever.

### Gaps
- No dataset with Apple Watch data **and** momentary affect EMA was found to be publicly released. Small Apple Watch EMA studies (e.g., a 2025 arXiv college stress study, 2505.15974) do not state any data release.
- Whether the K-EmoPhone ESM timestamps line up with any sleep data: none, since the band was worn 10 AM–10 PM, so sleep features would be "unknown" for every K-EmoPhone sample.
- Tesserae Garmin signals (does it include HRV/stress score, sleep stages, minute HR?): not verified on a primary page.
- Ages and student status of LifeSnaps participants: not retrieved (only recruitment via university mailing lists).
