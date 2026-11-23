# Research-grade and lab affect/stress datasets: catalogue and transferability to an Apple Watch-only app (as of Nov 2026)

Scope note: this covers datasets recorded with research-grade wearables (Empatica E4, chest ECG patches and straps, RespiBAN, Shimmer, research wristbands with EDA) or in lab protocols. Consumer-only datasets (Fitbit, Garmin) are mentioned only where they carry evidence on device or setting transfer. "Verified" means read on the official page or dataset paper during this session. Anything taken only from a search-engine summary is marked "(search summary)".

---

## Q1. What exists: setting, N, duration, devices and signals, labels

### Takeaway
Almost every public research-grade dataset is either a **lab protocol** (WESAD, SWELL-KW, UBFC-Phys, VerBIO, CLAS, StressID, Stress-Predict, PhysioNet stress+exercise) or **video elicitation** (Emognition, EmoWear, CASE, DEAP/AMIGOS). Only a handful are **daily-life with self-reports**: DAPPER, SWEET (not public), SMILE, Nurse stress, LAUREATE, ADARP, MMASH (24 h, few labels), TILES (ECG shirt, DUA). Most are small (11–65 participants). Only DAPPER (88 with physiology) and SWEET (1,002) come near EmoPhone's scale, and SWEET is not openly available.

### Cited Findings

**Lab-induced stressor datasets**
- **WESAD** (Schmidt et al., ICMI 2018): 15 subjects (3 female), lab. Conditions: baseline (neutral reading), amusement (funny clips), stress (TSST), plus meditation. Chest device sampled at 700 Hz (ACC, ECG, EDA, EMG, RESP, TEMP); wrist device (E4) gives ACC, EDA, PPG, TEMP. — [Schmidt et al. review, ar5iv](https://ar5iv.labs.arxiv.org/html/1811.08854); conditions incl. meditation per [FEEL, arXiv 2604.05926](https://arxiv.org/html/2604.05926)
- **SWELL-KW** (Koldijk et al., ICMI 2014): office knowledge work with stressors (time pressure, email interruptions). Signals: computer logging, facial expressions, body posture, heart rate (variability), skin conductance. Labels: NASA-TLX task load, RSME mental effort, SAM emotion, perceived stress. — [SWELL-KW project page](https://cs.ru.nl/~skoldijk/SWELL-KW/Dataset.html) (search summary); DOI 10.17026/DANS-X55-69ZP — [B2FIND record](https://b2find.eudat.eu/dataset/370fa734-5919-5ad3-af17-c1a744337c55)
- **UBFC-Phys**: 56 participants, E4 (BVP, EDA) plus face video. Rest, then speech (interview) and arithmetic (countdown) tasks; labels come from the task. — [FEEL Table 1](https://arxiv.org/html/2604.05926)
- **VerBIO**: 49 participants, 344 public-speaking sessions in real and VR settings. E4 and Actiwave. Self-reported anxiety, plus a later version with time-continuous stress annotations from 4 annotators. — [FEEL](https://arxiv.org/html/2604.05926)
- **CLAS**: 62 participants, Shimmer3 GSR+. Tasks: video stimuli, math, logic problems, Stroop. Labels come from the stimulus. — [FEEL Table 1](https://arxiv.org/html/2604.05926)
- **ForDigitStress**: digital job-interview stressor, IOM biofeedback sensor, expert-annotated. — [FEEL Tables 8–9](https://arxiv.org/html/2604.05926)
- **StressID** (NeurIPS 2023 Datasets & Benchmarks): 65 participants, 11 tasks. Wearable ECG, EDA and respiration plus facial video and audio. Ratings of relaxation, stress, arousal and valence. — [StressID project page](https://project.inria.fr/stressid) (search summary); [NeurIPS paper](https://papers.neurips.cc/paper_files/paper/2023/file/5f09bfe6730e9627a9f800d01a8ad5cd-Paper-Datasets_and_Benchmarks.pdf)
- **Stress-Predict** (Iqbal et al., Sensors 2022): E4 PPG wristband, induced psychological stress. Includes respiratory rate estimated from PPG. N and protocol details not verified here. — [MDPI Sensors 22(21):8135](https://mdpi.com/1424-8220/22/21/8135/htm) (search summary)
- **Wearable Device Dataset from Induced Stress and Structured Exercise Sessions** (PhysioNet v1.0.1, June 2025; new release): E4 (BVP, ACC, TEMP, EDA). 36 volunteers in stress sessions (math and emotional tasks with rest periods; a Stroop test in v1, removed in v2), 30 in aerobic bike sessions, 31 in anaerobic (Wingate-style) sessions. Self-reported stress level per stage. — [PhysioNet page](https://physionet.org/content/wearable-device-dataset/1.0.1/)
- **Consumer-device lab study** (Amin, Mishra et al. 2025): 35 students, 3 standardised stress tasks, recorded at the same time on Biopac MP160, Polar H10, Empatica E4 and Garmin Forerunner 55s. — [arXiv 2505.05694](https://arxiv.org/html/2505.05694v1)

**Video or emotion elicitation (lab)**
- **Emognition** (Saganowski et al., Sci Data 2022): 43 participants, short film clips for 9 discrete emotions. Muse 2 (EEG), Empatica E4 (BVP, EDA, SKT, ACC), and a **Samsung Galaxy Watch (BVP, HR, ACC, GYRO)**, plus upper-body video. — [FEEL](https://arxiv.org/html/2604.05926); [Emognition GitHub README](https://github.com/Emognition/Emognition-wearable-dataset-2020/blob/main/README.md) (search summary)
- **EmoWear** (Sci Data 2024): 48–49 participants, E4, lab video stimuli, self-report. — [Nature Sci Data](https://www.nature.com/articles/s41597-024-03429-3) (search summary); [FEEL](https://arxiv.org/html/2604.05926)
- **CASE**: 30 participants, ThoughtTech lab sensors, video clips with continuous joystick valence/arousal annotation. — [FEEL Table 1](https://arxiv.org/html/2604.05926)
- **K-EmoCon** (Sci Data 2020): naturalistic paired debates with continuous emotion annotations. — [Nature Sci Data](https://www.nature.com/articles/s41597-020-00630-y) (search summary)
- **DEAP / AMIGOS / MAHNOB-HCI / ASCERTAIN**: lab, video-elicited. For example, Koelstra et al. (DEAP) report LOSO arousal/valence/liking accuracies of 57%/63%/59%. — [Schmidt review table](https://ar5iv.labs.arxiv.org/html/1811.08854)

**Daily life ("in the wild") with self-reports**
- **DAPPER** (Shui et al., Sci Data 2021, China): ESM/DRM data from 142 participants, physiology from 88, over 5 days. Custom wristband (Psychorus, HuiXin): PPG at 20 Hz turned into HR at 1 Hz (10-s window, manufacturer motion-artifact algorithm), GSR at 40 Hz (0.01 µS resolution), 3-axis ACC at 20 Hz, daytime only. ESM 6 times a day (spacing under 3 h) plus the Day Reconstruction Method. An HR value of 40 is a floor/invalid code (no valid PPG). — [Nature Sci Data](https://www.nature.com/articles/s41597-021-00945-4)
- **SWEET** (imec, Smets et al., npj Digit Med 2018): 1,002 office workers, 5 days. Chest patch (ECG 256 Hz, ACC 32 Hz) and imec Chillband wrist (SC 256 Hz, ST 1 Hz, ACC 32 Hz). EMA 12 times a day on a 5-point Likert scale, about 25 responses per subject. Answers were 50.4% "no stress" and 0.3% "extremely high", so the top 3 levels were merged into one. 18 features on 5-min windows with 4-min overlap. On average 86.4% of chest-patch data and 96.3% of Chillband data were of good quality. — [npj Digital Medicine](https://www.nature.com/articles/s41746-018-0074-9); sampling rates per [three-stage validation paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC11848792/)
- **SMILE**: 45 healthy participants (39 F / 6 M). Wrist device for EDA and skin temperature, chest device for ECG. Self-reported stress from 0 ("not at all") to 6 ("very") on random phone prompts. Released as **precomputed features** (5-min windows, 4-min overlap; handcrafted and deep ECG features) with about **one label per hour**. Large amounts are missing (only 17 of 2,070 training instances have features for the whole hour). — [Dair et al., arXiv 2208.04705](https://ar5iv.labs.arxiv.org/html/2208.04705)
- **Nurse stress dataset** (Hosseini et al., Sci Data 2022): 15 female nurses, about 1 week each, regular hospital shifts during COVID-19 (Apr–May and Nov–Dec 2020), about 1,250 h. E4 gives EDA, HR, TEMP, IBI, BVP, ACC. Labels are stress events (from detection followed by nurse confirmation) plus smartphone surveys on contributing factors. — [Dryad record](https://datadryad.org/dataset/doi:10.5061/dryad.5hqbzkh6f); [search summary of paper/Dryad](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9159985/)
- **LAUREATE** (Laporte, Gjoreski, Langheinrich, IMWUT 2023): 42 students (FEEL lists 44), 26 classes including exams, 13 weeks. E4 (EDA, PPG, ST, ACC) plus self-reports on lifestyle and emotional states (engagement and attention per FEEL). DOI 10.1145/3610892. — [USI dataset page](https://pc.inf.usi.ch/datasets/laureate/); [search summary](https://www.aminer.cn/pub/65254f7a939a5f4082cda5fd/laureate-a-dataset-for-supporting-research-in-affective-computing-and-human-memory); [FEEL](https://arxiv.org/html/2604.05926)
- **ADARP** (Sah et al. 2022): 11 people with alcohol use disorder (10 F), E4, about 14 days on average (range 7–17). EMA 4 times a day with PANAS-style items on stress, feeling overwhelmed and anxiety. — [arXiv 2206.14568](https://ar5iv.labs.arxiv.org/html/2206.14568) (search summary); [FEEL](https://arxiv.org/html/2604.05926)
- **MMASH** (PhysioNet 2020): 22 healthy young males, 24 h continuous. **Polar H7** beat-to-beat (RR) intervals plus ActiGraph wGT3X-BT (ACC, sleep, activity). PANAS at 10:00, 14:00, 18:00, 22:00 and 09:00 the next day. Daily Stress Inventory at bedtime; STAI-Y, PSQI, BIS/BAS; saliva cortisol and melatonin; activity log. — [PhysioNet MMASH](https://physionet.org/content/mmash/1.0.0/)
- **TILES-2018** (Sci Data 2020): hospital workers. Fitbit Charge 2 plus **OMsignal ECG garment** worn during work shifts, plus daily EMAs: a single stress item, a single anxiety item, PANAS-short. About 60% of garment recordings have at least 85% RR coverage. — [Nature Sci Data](https://www.nature.com/articles/s41597-020-00655-3)
- **Schmidt et al. in-the-wild study** (ISWC 2019): 11 subjects, E4 plus EMA (about every 2 h, plus manual entries). Exploratory only; no dataset release found. — [search summary of Uni-Siegen paper](https://www.eti.uni-siegen.de/ubicomp/papers/ubi_iswc2019.pdf)

**Activity–heart-rate confound**
- **PPG-DaLiA** (UCI, CC BY 4.0): E4 and RespiBAN during daily activities, built for PPG heart-rate estimation (no affect labels). — [UCI PPG-DaLiA](https://archive.ics.uci.edu/dataset/495/ppg-dalia) (search summary)
- **PhysioNet stress + exercise** (above): the only open dataset found with **both** psychological stress sessions and aerobic/anaerobic exercise sessions recorded on the same device and population. — [PhysioNet](https://physionet.org/content/wearable-device-dataset/1.0.1/)

### Inferences
- Lab "stress" in these datasets is a 5–15-min acute social or cognitive stressor (TSST, arithmetic, public speaking) done seated, compared with a seated baseline. That differs from EmoPhone's in-situ arousal ratings about everyday moments.
- Among the open daily-life datasets, **DAPPER** is closest to the app's setting: 1-Hz wrist HR and ACC, 6 ESM prompts a day, 5 days, 88 participants, which can be downsampled to Apple Watch density. The **Nurse** and **MMASH** datasets are the next most usable for HR-only work.

### Gaps
- AffectiveROAD: no official page or licence verified this session. From memory it is a driving study with E4 and Zephyr BioHarness and continuous observer stress annotation; treat as unverified.
- SWELL-KW participant count (25 is commonly cited) and the exact SAM/valence/arousal fields were not verified on the DANS page.
- DAPPER ESM item wording and scale (valence/arousal/PANAS) were not extracted. The paper confirms ESM 6 times a day but the item list was not read.
- Stress-Predict N (35 is commonly cited) and its exact protocol were not verified.
- No 2025–2026 Scientific Data release combining an EmbracePlus or research wristband with daily-life EMA was found. A 2025 arXiv study used an EmbracePlus with 3 EMAs a day in people with opioid use disorder, but describes it as a self-collected, non-public dataset. — [arXiv 2506.02256](https://arxiv.org/pdf/2506.02256)
- New 2024–2026 PhysioNet entries surfaced but not inspected: "QoL_Stress" ([PhysioNet](https://www.physionet.org/content/qol-stress/)), "Wearable Exam Stress" (E4 during exams, [PhysioNet](https://www.physionet.org/content/wearable-exam-stress/1.0.0/data/S3/Final/)), "consumer-grade-wearables" ([PhysioNet](https://physionet.org/content/consumer-grade-wearables/1.0.0/)). Also "DailySense" on Zenodo ([record](https://zenodo.org/records/10816004)). Their N, labels and licences were not checked.

---

## Q2. Access and licence (redistribution, publishing trained models)

### Takeaway
Only a few datasets can be downloaded at once under a permissive licence: **MMASH (ODbL)**, the **PhysioNet stress+exercise set (ODC-By)**, the **Nurse dataset (Dryad, open download)**, **EmoWear (Zenodo, open)**, **PPG-DaLiA (CC BY 4.0)** and probably **ADARP (Zenodo "open")**. **WESAD** is free but restricted to **non-commercial scientific use**. **Emognition, StressID, K-EmoCon** need a EULA or a request. **SWEET** is **not public** (formal agreement with imec / OnePlanet). DAPPER is on Synapse; the exact conditions were not verified.

### Cited Findings
- **WESAD**: The UCI listing (DOI 10.24432/C57K5T) points to the original site's acknowledgement policy. The Uni-Siegen page allows use for **scientific, non-commercial purposes**, with credit to the owners. UCI's CC BY 4.0 applies to PPG-DaLiA, **not** to WESAD. — [UCI WESAD](https://archive.ics.uci.edu/dataset/465/wesad); [Uni-Siegen WESAD page](https://www.eti.uni-siegen.de/ubicomp/home/datasets/icmi18/) (search summary)
- **SWELL-KW**: deposited at DANS (DOI 10.17026/DANS-X55-69ZP), flagged OpenAccess in a catalogue record. A CC BY-NC-SA 4.0 licence appears on a related record, unconfirmed for the data itself. — [B2FIND](https://b2find.eudat.eu/dataset/370fa734-5919-5ad3-af17-c1a744337c55) (search summary)
- **SWEET**: "available on request to the corresponding author… not publicly available due to them containing information that could compromise research subject privacy." — [npj Digit Med data availability](https://www.nature.com/articles/s41746-018-0074-9). A 2025 paper got it "under a formal agreement with IMEC, OnePlanet Research Center, Netherlands" and calls it "confidential". — [MethodsX 2025, Europe PMC](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC11848792/fullTextXML)
- **DAPPER**: data, README and MATLAB scripts hosted on **Synapse**; metadata on figshare (10.6084/m9.figshare.13803185). — [Nature Sci Data](https://www.nature.com/articles/s41597-021-00945-4)
- **Nurse stress**: Dryad DOI 10.5061/dryad.5hqbzkh6f, with `Stress_dataset.zip` (1.16 GB) and `SurveyResults.xlsx` directly downloadable. The abstract text still says "available upon request". — [Dryad](https://datadryad.org/dataset/doi:10.5061/dryad.5hqbzkh6f)
- **MMASH**: open access on PhysioNet under the **Open Data Commons Open Database License v1.0** (ODbL). — [PhysioNet MMASH](https://physionet.org/content/mmash/1.0.0/)
- **PhysioNet stress + exercise (2025)**: "Anyone can access the files", **Open Data Commons Attribution License v1.0**. — [PhysioNet](https://physionet.org/content/wearable-device-dataset/1.0.1/)
- **Emognition**: Harvard Dataverse DOI 10.7910/DVN/R9WAF4; **academic research only**; a signed EULA must be emailed from an academic address. — [search summary of GitHub README / Sci Data](https://github.com/Emognition/Emognition-wearable-dataset-2020/blob/main/README.md)
- **StressID**: EULA. The project site says only a person with a permanent academic position can sign. Licence is "Proprietary", non-commercial research only. — [StressID project page](https://project.inria.fr/stressid) (search summary)
- **EmoWear**: Zenodo DOI 10.5281/zenodo.10407278, no access restriction; re-identification prohibited. — (search summary of [Sci Data](https://www.nature.com/articles/s41597-024-03429-3))
- **K-EmoCon**: access by request on Zenodo (DOIs 10.5281/zenodo.3814370 / 3931963). The article's CC BY 4.0 covers the paper, not the data. — (search summary of [Sci Data](https://www.nature.com/articles/s41597-020-00630-y))
- **UBFC-Phys**: dat@UBFC lists CC BY-NC-SA; other sources say no licence is stated (conflict). — [dat@UBFC](https://search-data.ubfc.fr/FR-18008901306731-2022-05-05_UBFC-Phys-A-Multimodal-Dataset-For.html) (search summary)
- **ADARP**: Zenodo record 6640290 (v1.0, 13 June 2022), labelled "Dataset Open", about 1.5 GB. — [Zenodo](https://zenodo.org/records/6640290) (search summary; licence field not seen)
- **TILES-2018**: signed DUA required (no de-anonymisation, no sharing with non-signers). — [Nature Sci Data](https://www.nature.com/articles/s41597-020-00655-3)
- **Pulse-PPG** (pre-trained model, not a dataset): IMWUT 2025. Weights on Zenodo, code on GitHub, described as MIT-licensed. — [search summary of arXiv 2502.01108](https://arxiv.org/html/2502.01108v2)

### Inferences
- **Publishing a trained model**: CC0 (Dryad) and ODC-By (PhysioNet stress+exercise) allow it with at most attribution. ODbL (MMASH) applies share-alike to *derived databases*; a trained model is arguably a "Produced Work" needing only a notice, but this is a legal reading, not a verified one. WESAD's "non-commercial scientific" terms fit a course project but would block commercial release. EULA datasets (Emognition, StressID, TILES, K-EmoCon) usually forbid redistribution of data. Whether they allow publishing model weights needs a reading of each EULA.
- Dryad publishes all data under CC0 by policy. This is from background knowledge; the licence line was not captured from the Dryad page in this session.

### Gaps
- Exact licence text not verified for DAPPER (Synapse conditions), LAUREATE (no access terms on the USI page), ADARP (Zenodo licence field), SMILE (hosting and licence not found), CLAS, CASE, VerBIO, AffectiveROAD, Stress-Predict.
- Zenodo blocked automated fetches from this environment ("unusual traffic"), and PMC/MDPI returned 403, so several licence fields could only be read through search summaries.

---

## Q3. Published results and evaluation splits

### Takeaway
High numbers (80–99%) come from **lab** data, often with **random or window-level splits**. Under **leave-one-subject-out (LOSO)**, lab binary stress detection from HRV reaches about 0.81–0.95 F1. Under **subject-held-out evaluation in daily life**, results fall to about **0.45–0.72**. The same pipeline can drop from 91% (shuffled) to 59% (held-out challenge set).

### Cited Findings
- **WESAD (original)**: up to **80%** accuracy for 3 classes (baseline/stress/amusement) and up to **93%** for binary stress vs non-stress. These are best-case figures. — [Uni-Siegen / UCI summary](https://www.eti.uni-siegen.de/ubicomp/home/datasets/icmi18/) (search summary). A later LOSO reproduction lists the WESAD baselines as ECG-HRV **F1 0.813 / acc 0.854** and wrist BVP-HRV **F1 0.830 / acc 0.858**, and its own LOSO ECG-HRV MLP reaches F1 0.844 / acc 0.880. — [Stressor Type Matters, arXiv 2405.09563](https://arxiv.org/html/2405.09563)
- **SWELL-KW (LOSO, HRV)**: RFC F1 0.634 / acc 0.664, MLP F1 0.667 / acc 0.692; original Koldijk baseline acc 0.589. — [arXiv 2405.09563](https://arxiv.org/html/2405.09563)
- **VerBIO (LOSO, BVP-HRV)**: RFC F1 0.949 / acc 0.962. **ForDigitStress**: F1 about 0.81. — [arXiv 2405.09563](https://arxiv.org/html/2405.09563)
- **Three-stage validation (MethodsX 2025)** reports WESAD binary and 5-class accuracies of **99.78% ± 0.15** and **99.61% ± 0.32**. For SWEET it reused the WESAD-optimal *configuration and hyperparameters* on ECG, rather than testing a WESAD-trained model on SWEET. — [Europe PMC full text](https://www.ebi.ac.uk/europepmc/webservices/rest/PMC11848792/fullTextXML); [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S2215016125000536)
- **SWEET**: random forests with **LOSO** linking physiology to self-reported stress. Classifier performance varied strongly by subject; subjects with "blunted" physiological reactivity (worse self-reported health, higher depression/anxiety/stress) were in the low-performance group. The authors call for personalised models. — [npj Digit Med](https://www.nature.com/articles/s41746-018-0074-9) (headline accuracy not extracted)
- **SMILE**: ExtraTrees on a shuffled subset of the training data gave **90.77%** accuracy (F1 91.24). On the held-out challenge data the same approach gave **55.78%**, or **59.23%** with feature imputation. The authors attribute the gap to covariate shift. Per-feature hourly accuracies were 0.59–0.73. — [arXiv 2208.04705](https://ar5iv.labs.arxiv.org/html/2208.04705)
- **cStress** (Hovsepian et al., UbiComp 2015; AutoSense chest ECG + respiration, 1-min windows): trained on 21 lab participants. Independent lab test: recall **88.6%**, FPR **4.65%**. Week-long field study (20 participants) against EMA self-reports: accuracy **72%**. A third-party table gives lab LOSO F1 0.81, lab test F1 0.90, field F1 0.72. — [search summary of cStress paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC4631393). The Schmidt review instead quotes **92%** lab and **62%** field for the same work (conflict). — [Schmidt review](https://ar5iv.labs.arxiv.org/html/1811.08854)
- **Schmidt et al. in-the-wild E4 study (11 subjects)**: F1 scores "barely exceed 45%" for arousal, valence, stress and STAI targets. — [search summary of ISWC 2019 paper](https://www.eti.uni-siegen.de/ubicomp/papers/ubi_iswc2019.pdf)
- **Healey et al. (field study)**: none of the classifiers beat random guessing. — [Schmidt review](https://ar5iv.labs.arxiv.org/html/1811.08854)
- **DAPPER**: one third-party Transformer reports **71.5%** binary accuracy for positive vs negative affect (split not verified). — [search summary](https://pmc.ncbi.nlm.nih.gov/articles/PMC11820912)
- **FEEL benchmark (NeurIPS 2025; 19 datasets; E4-style EDA and PPG; binary arousal and valence)**: models trained on real-world datasets (ADARP, DAPPER, Nurse, LAUREATE) had poor *within-domain* performance, **max F1 = 0.49**. Hand-crafted features beat raw-signal models in 107 of 114 comparisons. — [FEEL](https://arxiv.org/html/2604.05926)
- **Garmin Forerunner 55s (consumer watch, HRV only, lab tasks, LOSO)**: AUROC **0.73** in scenario 1 and **0.961** in scenario 2 (rest vs mental arithmetic). A pre-trained model from an earlier study scored 0.748 and 0.968. E4 data generalised worse than Garmin. — [arXiv 2505.05694](https://arxiv.org/html/2505.05694v1)
- **Polar H7 HR strap, lab and free-living (26 participants)**: F1 about **0.87 in lab** and **0.66 in field**. — [search summary of MDPI Sensors 19(17):3805](https://www.mdpi.com/1424-8220/19/17/3805); the full text (via Europe PMC) confirms a free-living arm calibrated on lab data
- **Systematic review (2021–2025)**: identifies a "significant lab-to-field gap" and notes few studies quantify it. — [ResearchGate listing](https://www.researchgate.net/publication/400176932_Multimodal_Wearable-Based_Stress_Detection_Using_Machine_Learning_A_Systematic_Review_of_Validation_Protocols_and_Generalization_Gaps_2021_-_2025) (venue unverified)

### Inferences
- The team's **AUROC ≈ 0.57** on EmoPhone with whole participants held out is in line with in-the-wild results that use far richer signals: SMILE held-out about 59% accuracy with ECG+EDA, Schmidt about 45% F1 with E4, FEEL real-world within-domain F1 ≤ 0.49. It is not evidence of a broken pipeline.
- The 99%+ WESAD numbers (MethodsX) almost certainly use window-level splits, so they say nothing about new users. The useful WESAD reference is about 0.81–0.85 F1 under LOSO.

### Gaps
- The SWEET paper's headline LOSO accuracy and the per-target F1 of Schmidt 2019 were not extracted.
- Original LOSO results for the Nurse, LAUREATE and ADARP papers were not read; only FEEL's harmonised re-benchmark was.

---

## Q4. Transferability: what survives at Apple Watch level, and evidence on lab→field and device→device

### Takeaway
Published evidence says lab-trained stress models **do not transfer** to other datasets unless the **stressor type** matches. Field accuracy drops to about 60–72% even with chest ECG. Once signals are cut to **one HR sample every ~5 min plus steps plus occasional SDNN**, everything lab models rely on is gone: beat-to-beat HRV, EDA, respiration, BVP morphology. What remains is "HR above personal baseline given activity". Lab datasets carry that signal only in seated, minutes-long blocks that one or two Apple Watch samples would barely cover. **No published study was found that trains on WESAD-type lab data and tests in the wild on a consumer watch at 5-min HR resolution.**

### Cited Findings
- **Cross-dataset (HRV)**: SWELL-KW→WESAD best RFC F1 **0.557** / acc 0.676, against ≥0.814 F1 within WESAD. Training on SWELL-KW and WESAD combined **lowered** WESAD performance by about 12% F1 and 9% accuracy. — [Stressor Type Matters](https://arxiv.org/html/2405.09563)
- **What does transfer**: WESAD ↔ VerBIO ↔ ForDigitStress (all *social* stressors) transfer with only a **4–6%** drop. The authors conclude that **stressor type** dominates, while device brand and stress intensity matter little. — [arXiv 2405.09563](https://arxiv.org/html/2405.09563)
- **Prajod & André 2022**: cross-dataset results for WESAD↔SWELL are "the opposite of within-dataset evaluations", and combining datasets "does not improve" recognition. — [arXiv 2210.06225](https://arxiv.org/pdf/2210.06225) (search summary)
- **Vos et al. 2023**: SWELL-trained HR+EDA models were poor on WESAD and NEURO. The ensemble reached about **50% F1**; adding SWELL+NEURO+UBFC-Phys raised accuracy slightly but lowered F1. — [as summarised in arXiv 2405.09563](https://arxiv.org/html/2405.09563); [Vos et al. arXiv 2209.15146](https://arxiv.org/pdf/2209.15146)
- **Mishra et al. 2020 (IMWUT)**: pooled 90 participants from 4 lab studies with 2 sensor types and report a near-total lack of reproducibility across studies. Field validation was left for later. — [Dartmouth project page](https://www.cs.dartmouth.edu/dfk/research/mishra-stress-ml/index.html) (search summary)
- **FEEL cross-setting**: real-world→lab F1 up to 0.79, constraint→real up to 0.88 (valence, RF), lab→real up to 0.76 "but lacked consistency". Lab-device→E4 transfer was fine (F1 about 0.73), but models from the **custom DAPPER wristband transferred poorly (F1 often < 0.66)**. — [FEEL](https://arxiv.org/html/2604.05926)
- **Lab→field with the same device**: cStress lab recall 88.6% vs field accuracy 72% (or 92%→62% per the Schmidt review). — [cStress summary](https://pmc.ncbi.nlm.nih.gov/articles/PMC4631393); [Schmidt review](https://ar5iv.labs.arxiv.org/html/1811.08854). Polar H7: 0.87→0.66 F1. — [MDPI 2019 summary](https://www.mdpi.com/1424-8220/19/17/3805)
- **Device→device (lab)**: Garmin HRV-only models matched E4 HRV+EDA in most comparisons. A model pre-trained on other studies kept AUROC 0.748–0.968 on Garmin but generalised poorly to E4. — [arXiv 2505.05694](https://arxiv.org/html/2505.05694v1)
- **Activity confound in daily life**: in SWEET, HR and skin conductance rise with accelerometer SD, which "highlight[s] the challenge of differentiating physiological changes caused by physical activity from those caused by stress". The authors kept only low-activity windows (ACC SD < 0.04) with quality > 0.8. — [npj Digit Med](https://www.nature.com/articles/s41746-018-0074-9)
- **Free-living stress and physical activity** produce similar responses in many wearable-measured variables. — [search summary, MDPI Algorithms 15(10):352](https://mdpi.com/1999-4893/15/10/352)
- **Field-trained foundation model**: Pulse-PPG, trained on raw PPG from 120 participants over 100 days in the field, beats a lab-trained model even on lab tasks. It needs **raw PPG**. — [search summary of arXiv 2502.01108](https://arxiv.org/html/2502.01108v2)
- **Personalisation**: SWEET found large between-subject differences in stress reactivity and recommends personalised models. — [npj Digit Med](https://www.nature.com/articles/s41746-018-0074-9). A 2026 bioRxiv preprint (not peer-reviewed) also argues detection is largely person-specific. — [bioRxiv](https://www.biorxiv.org/content/10.64898/2026.08.28.745906v1.full.pdf) (search summary)

### Inferences
- **What remains after degrading to Apple Watch level**: (a) mean HR in a 5-min window relative to the person's baseline; (b) activity from steps (no raw ACC); (c) at most 1–3 SDNN readings a day, taken opportunistically at rest and not aligned with prompts; (d) overnight HR, respiratory rate and wrist temperature, which can be built from TILES-style or MMASH data but not from lab sets.
- **Lab sets at that resolution**: a WESAD TSST block (about 10 min) gives 2 HR samples at ~5-min sampling. The stress-vs-baseline contrast is "seated + elevated HR", so any model learns "high HR = stress". In daily life the same rule fires on stairs, walking and caffeine. Stress Type Matters and SWEET both suggest this does not transfer to EmoPhone-style self-reported arousal.
- **Highest-value external data for the current model**: DAPPER (wrist HR 1 Hz + ACC + ESM, 88 people, daily life) is the only open dataset that can be **downsampled** to Apple Watch-like inputs and labels (momentary ESM). It is a fair **external test** of the EmoPhone-trained logistic regression. FEEL's finding that DAPPER-trained models transfer poorly is a warning that its custom wristband HR may differ systematically, so per-user z-scoring is needed.
- **Expected gain from switching or adding datasets**: small or even negative for in-the-wild AUROC. The literature gives no support for the 80–95% lab figures carrying over. A realistic ceiling for person-independent daily-life arousal from HR+steps is probably in the 0.55–0.65 AUROC range. This is judgement based on SMILE, FEEL and Schmidt 2019, not a published number for this exact setup. Personalisation (per-user baselines, or fine-tuning on the user's own feedback) is the lever the literature consistently points to.

### Gaps
- No study found that tests WESAD- or SWELL-trained models on **consumer-watch data in daily life**, or that simulates 5-min HR sampling explicitly.
- No study found on **Apple Watch HealthKit SDNN** against momentary self-reported arousal or stress in a public dataset. A separate consumer-device search would be needed (e.g., Apple Watch cohort studies such as the Mount Sinai Warrior Watch work, not checked here).
- The Prajod & André 2022 numbers could not be extracted (PDF indexed as raw binary).

---

## Q5. Legitimate narrow uses for the app

### Takeaway
None of these datasets should replace EmoPhone as the main training set. Four narrow uses are defensible: (1) **external validation** of the existing HR+steps model on DAPPER, and possibly the Nurse dataset, after downsampling; (2) **quantifying the activity confound** (stress vs exercise HR deltas) on the PhysioNet stress+exercise set, to justify or tune step/activity gating; (3) **sanity-checking feature definitions** (HR-deviation and SDNN computed the way HealthKit would) on MMASH's 24-h Polar RR + actigraphy + PANAS; (4) a documented **negative result**: a WESAD-trained HR-only model evaluated on EmoPhone, to show why lab accuracy does not transfer. Pre-training is not useful without raw PPG.

### Cited Findings
- The PhysioNet stress+exercise dataset has stress (36), aerobic (30) and anaerobic (31) sessions on the same E4 device, with self-reported stress per stage, under ODC-By. It is the cleanest open source for measuring how much exercise HR elevation exceeds or overlaps stress HR elevation. — [PhysioNet](https://physionet.org/content/wearable-device-dataset/1.0.1/)
- MMASH gives 24-h beat-to-beat RR (Polar H7) plus actigraphy, sleep, PANAS 5 times a day, daily stress inventory and cortisol, open under ODbL. That is enough to compute 5-min mean HR, rest-only SDNN and step-like activity and compare them with momentary PANAS. — [PhysioNet MMASH](https://physionet.org/content/mmash/1.0.0/)
- DAPPER provides 1-Hz HR, GSR and ACC with ESM 6 times a day over 5 days for 88 participants. — [Sci Data](https://www.nature.com/articles/s41597-021-00945-4)
- The Nurse dataset provides E4 HR, IBI and ACC over about 1 week of real shifts with stress-event labels; directly downloadable from Dryad. — [Dryad](https://datadryad.org/dataset/doi:10.5061/dryad.5hqbzkh6f)
- SWEET shows that restricting to low-activity windows is a standard way to separate stress from movement in daily life. — [npj Digit Med](https://www.nature.com/articles/s41746-018-0074-9)
- Emognition records a **Samsung Galaxy Watch** (HR, BVP, ACC) next to the E4, but only during film clips in the lab, under an academic-only EULA. — [FEEL](https://arxiv.org/html/2604.05926); [Emognition README summary](https://github.com/Emognition/Emognition-wearable-dataset-2020/blob/main/README.md)
- PPG foundation models (Pulse-PPG, PaPaGei) need raw PPG segments (4-min windows in Pulse-PPG). — [search summary of arXiv 2502.01108](https://arxiv.org/html/2502.01108v2)

### Inferences
- **Use 1, external validation (most valuable)**: rebuild the 13 PROJECT.md §6 features from DAPPER. Resample HR to Apple Watch density (one sample per ~4–5 min, outside activity), derive a step-count proxy from ACC (weak: ACC magnitude ≠ steps), and map ESM arousal to the same binary target. Then score the frozen EmoPhone model, with whole participants held out by construction. Expect a drop. A model that holds AUROC > 0.55 there is evidence of robustness; one that collapses to 0.5 is honest evidence for the report. Unknown ≠ 0: DAPPER's HR = 40 floor code must become "unknown".
- **Use 2, activity confound**: on the stress+exercise set, compute 5-min mean HR deltas from each person's rest baseline for stress tasks vs aerobic exercise. If exercise deltas are much larger and overlap stress only at low intensity, that supports a rule such as "HR deviation counts as arousal only when steps in the window are below a threshold". The threshold can be tuned on EmoPhone, not on the lab data.
- **Use 3, HRV feature validation**: Apple Watch SDNN is a short resting reading taken a few times a day. MMASH (Polar RR) or WESAD chest ECG can show whether a single ~1-min SDNN differs between conditions or across the day, and how noisy it is within a person. This informs whether the feature is worth including at all, not its model weight.
- **Use 4, negative control for the report**: train an HR-only (5-min mean) model on WESAD stress vs baseline, apply it to EmoPhone with participants held out, and report the AUROC. This directly answers "would lab data help?" with the team's own numbers. WESAD's non-commercial licence covers this academic use.
- **Not recommended**: merging lab datasets into training (shown to hurt in cross-dataset studies); using EDA-heavy datasets (EDA is unavailable on Apple Watch); deep pre-training on raw PPG (not available through HealthKit in the team's setup); requesting SWEET (formal agreement, months of delay, ECG-patch data the app cannot reproduce).
- **Licence fit for publishing the model**: if any external data enters the *shipped* model, prefer CC0 / ODC-By / ODbL sources (Nurse, PhysioNet stress+exercise, MMASH) over WESAD (non-commercial) or EULA datasets. External validation only, with no data in the shipped model, avoids the question.

### Gaps
- Whether DAPPER's ESM includes an arousal item directly comparable to EmoPhone's was not verified. If it has only valence/PANAS-style items, the label mapping is weaker.
- No published evidence was found on how well a step-count proxy derived from wrist ACC (DAPPER, E4) matches Apple Watch step counts for this purpose.
- Model-weight publication rules in the Emognition, StressID, TILES and K-EmoCon EULAs were not read.
