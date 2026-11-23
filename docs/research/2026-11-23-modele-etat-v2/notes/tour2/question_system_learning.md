# In-app question system and on-device learning loop for a wearable-driven music app (state of the art, November 2026)

Scope note. "Cited Findings" are documented facts from the linked source. "Inferences" are my own judgement, including all design proposals and arithmetic. OS-version requirements are checked against an **iOS 18.0 deployment target** and an iPhone-only app (no watchOS app). This builds on the earlier note `Exploiter EmoPhone et autres datasets/apple_watch_signals.md` (signals, HealthKit types, HKStateOfMind label list). Where I reuse its findings, I say so. Apple developer pages were read in their Markdown form (`developer.apple.com/documentation/<path>.md`). PMC papers were read through the NCBI BioC / Europe PMC full-text services, but the links below point to the normal pages.

---

## Q1. What to ask: validated ultra-short measures of energy/arousal and pleasantness/valence, and which formats respect "never show a named emotion"

### Takeaway
Single-item momentary affect ratings are now well supported for within-person work. Their reliability is lower than multi-item scales but acceptable, and their validity is good. Two dimensions are enough: **energy/arousal** and **pleasant–unpleasant**. The EmoPhone items are 7-point (−3..+3) single items, but their arousal anchors ("very calm → very excited") are emotion words. The closest evidence on "compared to usual" phrasing **advises against relatively-worded items**. It recommends an absolute scale that shows the user's previous answer as a "Last" marker. The "relative to usual" label can then be computed on the phone against the user's own running median, which is also how EmoPhone builds HIGH/LOW labels.

### Cited Findings
**What EmoPhone / K-EmoPhone asked (the labels the population model was trained on)**
- EmoPhone D-1 ESM fields: Valence −3..+3 "very negative → very positive"; Arousal −3..+3 "very calm → very excited"; Stress −3..+3 "not stressed at all → very stressed"; Attention −3..+3 "very bored → very engaged"; Disturbance, Mental load and Duration; and "Change: emotion change while answering". D-3 replaces Change with **ChangedValence / ChangedArousal, "state immediately after answering the ESM"**. D-3 moves stress and disturbance to a 0..+6 scale, while valence and arousal stay −3..+3 — [Zhang et al., EmoPhone, arXiv 2609.16581, Tables 11–13](https://arxiv.org/pdf/2609.16581)
- K-EmoPhone: 77 students, 7 days, 5,582 ESM responses, **signal-contingent (16/day), voluntary**. Labels: valence, arousal, stress, attention, task disturbance, emotion change and duration — [arXiv 2609.16581, Table 1](https://arxiv.org/pdf/2609.16581); [Kang et al., Scientific Data 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10238385)
- The EmoPhone benchmark turns ratings into HIGH/LOW with the median of the training labels. Only the temporal setting uses a per-user median — [arXiv 2609.16581 §4.3, App. A.7.6](https://arxiv.org/html/2609.16581) (from the earlier `emophone_uci_audit.md` notes)

**Single items: validity and reliability**
- Song et al. (Assessment 2023), EMA data. Repeated-measures correlations between single items and their multi-item scales ranged from **.24 to .61**. Single items kept significant predictive validity in **27 of 29** models. Single-item reliability was **37%–78% of the multi-item counterpart at the within-person level** and 46%–106% at the between-person level — [Song et al., Assessment 30(5), PMC10248304](https://pmc.ncbi.nlm.nih.gov/articles/PMC10248304)
- Cloos, Ceulemans & Kuppens (Psychological Assessment) compared single- and multi-item momentary affect measures on within-person variance and validity criteria. They report "strong support for single-item measures of momentary affect" — [KU Leuven repository](https://lirias.kuleuven.be/retrieve/688893) (abstract-level)
- Dejonckheere et al. (Psych. Assessment 2022, 34:1138–1154) propose two time-varying test–retest designs for single-item ESM reliability: repeat the item within the same survey, or re-ask after a short delay and extrapolate. They argue single-item studies should build one of these in — [Tilburg repository](https://research.tilburguniversity.edu/en/publications/assessing-the-reliability-of-single-item-momentary-affective-meas/). The numeric reliability estimates were not retrievable (see Gaps).
- Scott et al. 2020 (seven diary/EMA studies) found affect reliability adequate to high at person, day and moment levels — [CDC Stacks supplement](https://stacks.cdc.gov/view/cdc/217574/cdc_217574_DS1.pdf) (abstract-level)

**Two-dimensional formats**
- **Affect Grid** (Russell, Weiss & Mendelsohn 1989): a single 9×9 grid with pleasure on one axis and arousal on the other. Four student studies showed "adequate reliability, convergent validity, and discriminant validity". Killgore (1998, n = 284) called it "a moderately valid measure of the general dimensions of pleasure and arousal" with "little specificity" — [Univ. of Arizona record](https://experts.arizona.edu/en/publications/the-affect-grid-a-moderately-valid-nonspecific-measure-of-pleasur/), [Aalto UX measures entry](https://experience.aalto.fi/affect-grid-2-2-2-2/)
- **Photographic Affect Meter (PAM)**: the user picks one photo from a grid. It was validated against PANAS, the Affect Grid and the Self-Assessment Manikin, with results "consistent with expectation" — [Pollak et al., Cornell eCommons](https://ecommons.cornell.edu/entities/publication/561d1ae3-02b0-404b-8f2b-f8c0656899e2). A VR comparison found PAM's **arousal** agreement weaker than its valence agreement (mean ICC 0.628, with about half of the lower confidence bounds in the "poor" range), because PAM ties each arousal value to a valence value — [arXiv 2004.00034](https://arxiv.org/pdf/2004.00034)
- A 2025 pictorial scale correlated with the **Self-Assessment Manikin** at r = 0.63 (valence) and 0.52 (arousal). This gives a rough idea of how far two pictorial formats agree — [Frontiers in Psychology 2025](https://www.frontiersin.org/articles/10.3389/fpsyg.2025.1498143/full)

**"Compared to usual" and response-scale format**
- Dejonckheere et al. (Psych. Assessment 2024, n = 178, daily life) tested two "relative" methods: (a) showing the person's **previous rating as a "Last" anchor** on an absolute scale, and (b) **relatively phrased items** ("compared with earlier"). Method (a) gave the best user experience ("easiest and most accurate"), **less measurement error** and more stable person-level dynamics. "In contrast, using relatively phrased emotion items is not recommended." — [PubMed 38127556](https://pubmed.ncbi.nlm.nih.gov/38127556/)
- A 14-day EMA experiment compared a 7-point Likert scale (n = 63) with a visual analogue scale (VAS, n = 56). The VAS gave moderately higher within-person means and fewer exact-zero answers. There were **no reliable differences in missing data, time to answer, or experience ratings**. Overall the differences were small — [Behavior Research Methods 2025](https://link.springer.com/article/10.3758/s13428-025-02706-2)
- The µEMA format used in the TIME study is one question with **at most 3 options**, such as "Feeling stressed?" → Yes / Sort of / No. Participants said "Sort of" helped when they felt in-between — [Ponnada et al., JMIR Form Res 2022](https://formative.jmir.org/2022/2/e32772/)

**Named-emotion check (from earlier notes)**
- HKStateOfMind labels include, among 38, **calm, excited, stressed, drained, overwhelmed, peaceful** — [Apple Docs: HKStateOfMind.Label](https://developer.apple.com/documentation/healthkit/hkstateofmind/label)

### Inferences
- **Non-compliant wording** under the project rule: EmoPhone's arousal anchors ("calm"/"excited"), any "Feeling stressed?" item, PAM photos (they depict emotions, even if unnamed), and Apple's label words.
- **Compliant wording (my judgement)**:
  - Energy: "Energy right now", from *low* to *high*. Energy is a bodily state, not an emotion name.
  - Pleasantness: "How does right now feel?", from *unpleasant* to *pleasant*. This is a dimension, not a category. Apple's own State of Mind scale uses the same axis.
  - Non-verbal anchors (colour bar, battery icon) also comply.
  - Smiley faces are a grey zone: they show an emotion without naming it. **The team should decide this explicitly.**
- **Recommended item set (buildable)**:
  1. **Energy** as the primary label, because the state model predicts arousal. Use a 3-option µEMA version (Low / Medium / High) for notifications and a 7-step slider for in-app use, to stay comparable with EmoPhone's −3..+3.
  2. Optionally **pleasantness** (3 options or 7-step), only where a second tap is cheap (in-app). It separates the "stress" situation (high energy, unpleasant) from good high energy.
  3. Do **not** ask "compared to usual". Ask the absolute level, show the user's last answer as a small marker on in-app sliders (Dejonckheere 2024), and compute "above / below usual" on the phone against the user's own running median. That matches EmoPhone's median-split labels.
- A 2D Affect-Grid-style pad (energy on the vertical axis, pleasantness on the horizontal) is a one-tap two-label format. Use it in-app only: a grid has lower agreement on arousal (see the PAM caveat) and does not fit a lock-screen notification.
- To estimate label noise cheaply, follow Dejonckheere 2022 and occasionally (about 1 in 10 prompts) re-ask the energy item a few minutes later. This gives a per-user test–retest estimate for the learning loop's noise term.

### Gaps
- Numeric single-item test–retest reliabilities from Dejonckheere 2022 and Cloos et al. were not retrieved (paywalled; only abstracts seen).
- No study found that validates a "compared to usual" **energy** item specifically. The 2024 evidence concerns emotion items "compared with earlier levels", not "compared with your usual".
- The original Self-Assessment Manikin paper (Bradley & Lang 1994) was not retrieved. From background knowledge (not re-verified here), it is a 9-point (originally 5-figure) pictorial scale for valence, arousal and dominance.
- Exact anchor wording of Apple's State of Mind slider (for example "Very Unpleasant … Very Pleasant") was not confirmed from an Apple page in this session.

---

## Q2. When and how often: response rates, burden, signal- vs event-contingent prompts, micro-interactions and reactivity

### Takeaway
Typical EMA studies prompt about 6 times a day for 7 days and get about **79% compliance**, mostly with payment. Prompt count per day barely predicts compliance, but higher frequency raises perceived burden and careless answers over the days, and long questionnaires hurt data quality. **One-tap micro-interactions are what keep response rates up**: smartwatch µEMA got **81% compliance vs 65%** for phone EMA, despite about 8× more prompts. The watch alone does not explain the gain; the one-question format does. Over **6+ months without pay for µEMA**, compliance was about **68%**. EmoPhone students answered about **7 of 10–15 prompts a day**. For Harmony, the cheapest high-yield labels are **event-contingent**: a one-tap energy question just before a queue, and the existing "Did it fit?" just after. Add 1–3 signal-contingent prompts a day for moments when the app is not used. Measurement reactivity on mood itself looks small, but asking does slightly change answers over time, through habituation and lower variance.

### Cited Findings
**Meta-analyses and experiments on frequency and length**
- Wrzus & Neubauer (Assessment 2023): 477 articles, 496 samples, N = 677,536. "On average EMA studies scheduled six assessments per day, lasted for 7 days, and obtained a compliance of 79%." "The number of assessments did not predict compliance or dropout rates." Compliance was significantly higher with **financial incentives** — [PMC9999286](https://pmc.ncbi.nlm.nih.gov/articles/PMC9999286)
- Williams et al. (JMIR 2021, 105 mEMA data sets): pooled compliance **81.9%**. Compliance was associated with prompts per day and items per prompt only in non-clinical data sets, with very high heterogeneity (I² > 90%) — [JMIR 2021;23(3):e17023](https://www.jmir.org/2021/3/e17023)
- Students, Study 1 (n = 313): 3 vs 9 questionnaires a day for 7 days. "A higher sampling frequency increased perceived burden but did not affect" compliance, within-person variability or within-person relationships. Study 2 (n = 282): 33 vs 82 items, 3 a day for 14 days. The longer questionnaire did not change burden or compliance, but it **reduced within-person variability in momentary mood** — ["The effects of assessment intensity on participant burden…", Behav Res Methods, PMC9374628](https://pmc.ncbi.nlm.nih.gov/articles/PMC9374628)
- Eisele et al. (Assessment 2022; 163 students; 30 vs 60 items; 3/6/9 prompts a day; 14 days): longer questionnaires increased burden and lowered data quantity and quality, while higher frequency did not — [Tilburg repository](https://research.tilburguniversity.edu/en/publications/the-effects-of-sampling-frequency-and-questionnaire-length-on-per/). A 2025 reanalysis of the same data with a screen-time mixture model found the reverse for careless/insufficient-effort responding: **frequency, not length**, increased it, "with sharper increases … across, but not within days" — [Psych. Assessment 37:347–359, abstract](https://ifp.nyu.edu/2025/journal-article-abstracts/pas0001379/), [Maastricht PDF](https://cris.maastrichtuniversity.nl/ws/files/262214670/Viechtbauer-2025-Investigating-the-effect-of-experience-sampling.pdf)

**Micro-interactions (µEMA)**
- Intille et al. (UbiComp 2016), 4-week between-subjects pilot: smartwatch µEMA (n = 19) vs phone EMA (n = 14). "Despite an ≈8 times increase in the number of interruptions, μEMA had a significantly higher compliance rate, completion rate, and first prompt response rate" and was "perceived as less distracting". Mean compliance was **81.2% (µEMA) vs 64.5% (EMA)** — [PMC6143290](https://pmc.ncbi.nlm.nih.gov/articles/PMC6143290)
- Ponnada et al. (IMWUT 2017) added watch-EMA, with 6 back-to-back questions on the watch. It did not differ from phone-EMA, while watch-µEMA was significantly higher than watch-EMA. The gain is "likely due to the microinteraction question technique, not simply the use of the watch" — [PubMed 30198012](https://pubmed.ncbi.nlm.nih.gov/30198012/)
- TIME study (Ponnada et al., JMIR Form Res 2022): 246 participants. µEMA allows **up to 48 prompts a day (about 4 per hour)**, one question with ≤ 3 options, versus ≤ 7 prompts and ≤ 6 questions for phone EMA. The question stays on screen 20 s. An "Undo?" button lasts 3 s. Thank-you messages come from more than 250 variants. **No regular pay for µEMA compliance** (pay was for wearing the watch and for phone EMA bursts; participants with > 50% µEMA compliance could keep the watch). In 81 participants with ≥ 6 months and 662,397 questions, **compliance was 67.6% (SD 24.4) and completion 79% (SD 22.2)** — [JMIR Form Res 2022;6(2):e32772](https://formative.jmir.org/2022/2/e32772/)
- µEMA criterion-validity pilot: 17 participants, 72 prompts a day for a week, completion 87.0%, compliance 74.0%, and a reported average answer time of about 5.4 s — [JMIR mHealth 2021;9(3):e23391](https://mhealth.jmir.org/2021/3/e23391) (search-summary level; full text not re-read)

**Student ESM datasets (closest population)**
- EmoPhone: prompts sent per day **15 / 12 / 10** (D-1/D-2/D-3, "intentional reduction"). ESM responses per active day were **6.70 / 6.99 / 7.03**, and mean responses per participant 111.5 / 212.6 / 206.0 over 22–32 days. Quality control excluded people below a **30%** response rate. The team contacted anyone below **50%** every 2–3 days. A participant-facing **progress counter** was added in D-2. Participants were compensated — [arXiv 2609.16581](https://arxiv.org/pdf/2609.16581)

**Timing / receptivity**
- Ally+ (iOS, free-living): machine-learning models that predicted receptivity "led up to a **40% improvement in receptivity**" over random timing, and the adaptive (per-user) model improved over the study — [Mishra et al., IMWUT 2021, arXiv 2011.08302](https://arxiv.org/abs/2011.08302)

**Reactivity of being asked**
- Mixed-method ESM study (average compliance 81%): completion time and within-person variance fell over the study, and positive affect was lower over time. Participants reported low behavioural reactivity. The authors read this as habituation and/or burden — [Maastricht repository](https://cris.maastrichtuniversity.nl/en/publications/a-mixed-method-investigation-into-measurement-reactivity-to-the-e)
- An ambulatory study that manipulated sampling frequency found that pleasant–unpleasant mood "did not show a systematic trend", while emotional clarity rose over time, regardless of frequency — [Behav Res Methods 2024](https://link.springer.com/10.3758/s13428-024-02346-y)
- Affect labeling (putting feelings into words) lowers self-reported distress and also dampens pleasure in lab picture tasks — [PubMed 21534661](https://pubmed.ncbi.nlm.nih.gov/21534661/), [Lieberman et al. 2007, PubMed 17576282](https://pubmed.ncbi.nlm.nih.gov/17576282/), [Torre & Lieberman 2018 review](https://journals.sagepub.com/doi/10.1177/1754073917742706)

### Inferences
- **Pilot arithmetic (my estimate).** Two weeks from 7 Dec 2026, unpaid students.
  - Event-contingent pre-queue energy taps: about 1–3 queues a day × about 80% answered ≈ **15–35 labels per user**.
  - Signal-contingent notifications, 2–3 a day × 50–70% answered ≈ **15–30 more**.
  - Realistic total: **about 30–60 energy labels per user**, so 150–300 for 5 users.
  - That is below EmoPhone's density (about 7 a day), which was paid and monitored.
- **Proposed schedule.**
  1. **Pre-queue** (event-contingent, in-app, one tap): "Energy right now?" before the queue starts. This is the cleanest *state* label, because it comes before the music acts.
  2. **Post-queue**: the existing "Did it fit?". This is the *reward* for queue choice, not a state label.
  3. **Signal-contingent**: 2 notifications a day at random times inside user-chosen windows (for example late morning and late afternoon), at least 2 h apart and never during the first 30 min after a queue. These cover moments when the app is not open and reduce selection bias.
  4. **No reminders, no streak pressure** (pay and monitoring are what lifted compliance in studies). Show a simple "answers this week" counter like EmoPhone's.
  5. Keep the "Undo" and "thank-you variation" ideas from TIME.
- **Selection bias** is the main threat to label quality: if labels only come when the user opens the app to play music, the model learns "app-open moments". Random signal-contingent prompts are the fix.
- **Reactivity.** The D-3 "ChangedArousal after answering" field shows that even the dataset authors expected answering to shift state. Asking energy *before* the queue and fit *after* keeps the two roles apart. Do not ask energy again right after the queue and treat the change as a music effect (regression to the mean and reactivity make it misleading).
- If prompts are increased later, raise **frequency before length**. Compliance is roughly flat in frequency, but careless answers grow across days (2025 reanalysis). So also cap the total, for example ≤ 4 a day.

### Gaps
- No study found that measures response rates for **iOS lock-screen notification actions** used as EMA, as opposed to watch apps. The µEMA numbers come from custom Android/Wear OS watch apps.
- No numbers found for unpaid students over exactly 2 weeks with 1-tap phone prompts.
- No study found on whether a "Did it fit?" question changes music listening or later mood.

---

## Q3. What consumer apps do: patterns worth copying for a one-tap check-in

### Takeaway
Consumer apps converge on: **one continuous or 5-point scale first, words optional and later**, reminders the user turns on, widgets and complications as entry points, and **correlation views gated on a minimum count of entries** (WHOOP needs 5 "yes" and 5 "no" entries within 90 days). Apple's State of Mind on the watch is a Digital Crown valence slider; words and life domains are optional follow-ups. Harmony can copy the slider and the minimum-count gating, and must skip the word step. Music services lean on implicit signals (skips, saves) and occasionally on in-app surveys at scale.

### Cited Findings
- **Apple State of Mind (watchOS 11 Mindfulness app)**: "Log how you're feeling right now" (momentary emotion) or "how you've felt overall today" (daily mood). "Turn the Digital Crown to indicate how you're feeling". Then optional words, then optional "what's having the biggest impact". Reminders are set up in the Health app on iPhone — [Apple Watch User Guide](https://support.apple.com/guide/watch/apd7de0f5610/watchos). The App Store listing says the shape adjusts as you turn the Crown, and that entries can be compared with lifestyle factors (time in daylight, sleep, exercise, mindful minutes) — [Mindfulness on the App Store](https://apps.apple.com/us/app/mindfulness/id1560383515)
- **How We Feel** (nonprofit, built with the Yale Center for Emotional Intelligence / Marc Brackett): a colour-coded matrix of emotion words with an energy dimension (for example "low-energy but pleasant") and intensity rising toward the edges. It has Home Screen widgets for quick check-ins and cross-references sleep and exercise — [App Store listing](https://apps.apple.com/us/app/how-we-feel/id1562706384), [App Store Awards 2022](https://apps.apple.com/us/story/id1647059928)
- **Daylio**: a five-point mood scale plus activities from a list, described as a "micro" journal. Its own guide suggests high- and low-energy variants of each mood to track energy — [Wikipedia: Daylio](https://en.wikipedia.com/wiki/Daylio), [Daylio: how to track moods](https://daylio.net/how-to-track-moods/)
- A symptom/mood tracker App Store listing (I could not confirm it is Bearable) offers a customizable 2- to 11-point mood scale and Apple Health links showing "how sleep or active energy influence your mood" — [App Store id1335347860](https://apps.apple.com/app/id1335347860)
- **WHOOP Journal / Behavior Impact**: after "at least five 'yes' and five 'no' responses for a behavior within a 90-day period", WHOOP shows whether it is associated with higher or lower Recovery. It presents this as personal patterns, not causation — [WHOOP: insights on behaviors](https://www.whoop.com/ca/en/thelocker/a-new-way-to-see-insights-on-which-behaviors-affect-your-recovery/)
- **Spotify**: an in-app survey sent to about 3 million users (more than 100,000 responses) on home-screen satisfaction and the reason for using the app that day. It surfaced intents that interviews had missed (Mehrotra et al., as summarized by Benedict et al.) — [Benedict et al. 2023, UvA](https://irlab.science.uva.nl/wp-content/papercite-data/pdf/benedict-2023-intent-satisfaction.pdf). Spotify's BaRT home-page bandit learns "satisfaction (e.g., click-through rate, consumption probability) for any combination of item, explanation, and context" and attaches an explanation to each shelf — [McInerney et al., RecSys 2018](https://static1.squarespace.com/static/5ae0d0b48ab7227d232c2bea/t/5ba85dac7817f764cdda68f4/1537760712983/bart_recsys.pdf)
- **Skips as a signal**: a song's skip profile over time is a stable, song-specific property, largely shared across users and devices — [arXiv 1903.06008](https://arxiv.org/abs/1903.06008), [arXiv 2005.06987](https://arxiv.org/abs/2005.06987). For an internet-radio next-song recommender, using real negative feedback (including skips) as negatives cut training time by about 60% and raised accuracy by about 6% — [arXiv 2406.04488](https://arxiv.org/abs/2406.04488)

### Inferences
- **Patterns to copy:**
  - One gesture first (slider or 3 buttons); anything extra is optional.
  - Entry from a widget or Control.
  - User-set reminder windows.
  - "Insights unlock after N answers" (WHOOP-style gating). This is honest about data needs and is a ready-made answer to "when does it learn me?".
- **Patterns to avoid:** the word-picking step (How We Feel, Apple, Daylio moods). It breaks the named-emotion rule.
- **Skips are partly song-intrinsic** (the skip-profile papers). The bandit reward should therefore use a *relative* skip signal, for example a skip before 30 s, or a skip compared with that song's own skip history in the user's library. A raw skip count is not enough.

### Gaps
- Welltory, Bearable (official), Oura tags and the WHOOP Journal question flow were not verified from primary pages in this session.
- No public number found for response rates of consumer one-tap mood check-ins (Apple, How We Feel, Daylio).

---

## Q4. Learning loop for small per-user data: priors, shrinkage, online updates, noise, drift, feedback loops, and bandits for queue choice

### Takeaway
The mHealth pattern that fits Harmony is **"population prior + per-user Bayesian update"**. HeartSteps V2 built its prior from the earlier study's data. It used Thompson sampling with action-centering and **clipped randomization probabilities** so the system keeps exploring and stays analysable afterwards. IntelligentPooling adds per-user random effects with empirical Bayes and cut regret by 26%, even with a small group. Thompson sampling with a Gaussian (Laplace) posterior over logistic weights is simple to hand-write, robust to delayed and batched feedback, and its "posterior becomes the next prior" batch update fits a nightly job. With about 30–60 labels per user, published personalization gains are small (< 2% AUROC with about 70 labels a user on K-EmoPhone). So the realistic pilot goals are **calibration (per-user intercept) and a queue-choice bandit over a few arms**, not new per-user coefficients.

### Cited Findings
**Personalizing the state model**
- From the earlier notes: on K-EmoPhone, leak-free partial personalization improved AUROC by **less than 2% with about 70 labels per user**, versus about 5% on a dataset with about 566 labels per user — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf). The very large "hybrid" gains (AUROC .41–.62 rising to .78–.98) used 50% of each test user's data with random splits — [Meegahapola et al. 2022](https://arxiv.org/pdf/2211.03009)
- A simple hierarchical model of individual differences "can substantially improve emotional state prediction performance without relying on previous days' data" (phone and wearable data) — [JMIR mHealth 2021;9(3):e24465](https://mhealth.jmir.org/2021/3/e24465) (abstract-level)
- Sample-size rules for logistic models: the classic heuristic is **10 events per variable**. Riley et al. replace it with criteria that include an expected **global shrinkage factor ≥ 0.9** and an optimism in Nagelkerke R² of ≤ 0.05. These usually need more events when the expected R² is small — [Riley et al., Stat Med 2019, PMC6519266](https://pmc.ncbi.nlm.nih.gov/articles/PMC6519266)

**Bandits / RL in mHealth (closest analogue to "learn on one phone")**
- Personalized HeartSteps (V2):
  - The RL algorithm decides five times a day whether to send a suggestion. Data from V1 were used to choose predictive variables and **"form a prior distribution"**, and to build a simulation environment.
  - The model is **action-centered**: (A_t − π_t) keeps the treatment-effect estimate unbiased "even when the baseline reward model … is incorrect".
  - Randomization probabilities are **clipped** (ε₀ = 0.2 in V2). This "enables off-policy data analyses after the study" and "ensures that the RL algorithm will continue to explore … instead of locking itself into a particular policy".
  - A **"dosage"** variable models smaller effects after recent treatments (habituation). The authors expect non-stationarity from unobserved engagement and burden.

  — [Liao et al., arXiv 1909.03539](https://arxiv.org/abs/1909.03539)
- IntelligentPooling: a Thompson-sampling contextual bandit with random effects and empirical Bayes that "adaptively adjust[s] the degree to which policies are personalized to each user". It has **26% lower regret than state of the art** in simulation, handles non-stationarity through "time since beginning treatment", and was feasible in a live trial with a small group — [Tomkins et al., arXiv 2008.01571 / Machine Learning 2021](https://arxiv.org/abs/2008.01571)
- Because algorithms are stochastic, apparent personalization can be an artefact. A resampling method checks whether an online RL algorithm really personalized — [arXiv 2304.05365](https://arxiv.org/abs/2304.05365)
- Chapelle & Li (NIPS 2011):
  - Logistic regression with a **Gaussian posterior with diagonal covariance** ("as in the Laplace approximation … the inverse variance of each weight is given by the curvature").
  - **Algorithm 3**: the posterior after each batch becomes the prior for the next.
  - Scaling the posterior to explore less (α < 1) often lowers regret but raises variance.
  - Under delayed or batched feedback, Thompson sampling kept its regret far below UCB's. The UCB/TS regret ratio grew from 2.65 (no delay) to 3.82 (delay 1000). "Since it is a randomized algorithm, it is robust in the case of delayed feedback."

  — [Chapelle & Li 2011, PDF](https://proceedings.nips.cc/paper_files/paper/2011/file/e53a0a2978c28872a4505bdb51db06dc-Paper.pdf)

**Music-recommendation bandits**
- Deezer carousel personalization is a contextual bandit with multiple plays, cascade-based updates and **delayed batch feedback**. "Semi-personalization via user clustering" shares arms within groups of similar users. **Pessimistic priors Beta(1,99) were "overall more effective" than uniform Beta(1,1)**. The paper releases industrial data and a simulator — [Bendada et al., RecSys 2020, arXiv 2009.06546](https://arxiv.org/abs/2009.06546)
- Music recommendation framed as a bandit with a Bayesian model of audio content and **novelty** was supported by simulations and a user study — [Wang et al., arXiv 1311.6355](https://arxiv.org/abs/1311.6355)
- Spotify BaRT (bandit plus explanations) reported significant engagement gains offline and online — [RecSys 2018 PDF](https://static1.squarespace.com/static/5ae0d0b48ab7227d232c2bea/t/5ba85dac7817f764cdda68f4/1537760712983/bart_recsys.pdf). Spotify playlist RL trained in a **simulator of user satisfaction** found offline simulator scores "strongly correlated with observed online metric results" — [arXiv 2310.09123](https://arxiv.org/abs/2310.09123)

**Pitfalls**
- Offline evaluation of a bandit is only unbiased when the logs come from known (for example randomized) action probabilities. The "replay" method relies on this — [Li et al., arXiv 1003.5956](https://arxiv.org/abs/1003.5956)
- Recommenders change user preferences and hence their own feedback ("degenerate feedback loops", echo chambers vs filter bubbles). The paper suggests ways to slow the degeneracy — [Jiang et al., arXiv 1902.10730](https://arxiv.org/abs/1902.10730)

### Inferences
**A. State model (energy above/below usual): per-user intercept, then maybe slopes**
- Keep the EmoPhone logistic regression frozen as the **prior mean**. Add a per-user intercept b_u ~ N(0, τ²). Optionally add per-user slopes on 1–2 strongest features, with a smaller τ.
- **How much data before personal terms matter (my derivation; Laplace approximation of Bayesian logistic regression).** Each label near p ≈ 0.5 carries about 0.25 units of information, so the weight on the user's data is w = 0.25·n / (0.25·n + 1/τ²).
  - τ = 0.5 log-odds: half weight at **n ≈ 16 labels**, 0.71 at n = 40.
  - τ = 1: half weight at n ≈ 4.
  - Estimate τ from EmoPhone with a random-intercept logistic model under GroupKFold, so that day 1 equals the population model.
- **Per-user slopes** need roughly the same n per slope for a similar τ. Slope heterogeneity is usually smaller, so in practice they need more labels. With 30–60 labels, **1 intercept plus at most 1–2 slopes**, all strongly shrunk, is the ceiling. This is consistent with the EPV ≈ 10 heuristic (15–30 "high" events) and with Riley's shrinkage logic.
- **Update cadence:**
  - **Per-answer update** of the intercept posterior: one Newton step on n·(y − p), closed form, microseconds, in Swift.
  - **Nightly refit** (BGProcessingTask, see Q5): re-run the Laplace fit on the full per-user history, recompute personal baselines, apply forgetting.
  - **Fallback:** BG tasks are not guaranteed, so run the refit at app launch if the last one is older than 24 h.
- **Label noise:** treat "Medium" or "Sort of" answers as y = 0.5 (soft label) or drop them. Keep the clipped-probability idea to avoid overconfident updates from single answers. Use the re-ask estimate from Q1 to set how much one answer can move b_u.
- **Drift:** each night inflate the posterior variance (for example add 1–2% of τ²) so old answers fade. IntelligentPooling instead uses "time since start".
- **Feedback loop (music changes the next answer):**
  1. Use only **pre-queue** and **random-prompt** answers as state labels.
  2. Drop or flag answers within about 30–60 min after a queue, or add "minutes since last queue" as a feature.
  3. Never train the state model on "Did it fit?".
  4. Because the predicted state picks the situation and the user's answer may be shaped by it (expectation effects), log the model's prediction at prompt time and do **not** show it before asking.

**B. Queue choice: a small Thompson-sampling bandit**
- **Arms:** a few *queue strategies* per situation, not individual songs. Examples:
  - "match current energy, then shift toward the target"
  - "go straight to the target energy"
  - "target energy ± 1 step"
  - positivity high vs neutral

  With 4 situations × 3 arms = 12 cells, a 2-week pilot can learn at least something.
- **Reward (composite, in [0,1]):**
  - "Did it fit?" when answered (yes = 1, sort of = 0.5, no = 0)
  - otherwise 1 − (share of songs skipped before ~30 s)
  - with a small bonus for a like

  Skip only relative to the song's own skip history if available, because skips are partly song-intrinsic.
- **Prior:**
  - **Pessimistic or neutral Beta priors** per cell (Deezer found pessimistic priors better). Alternatively, a Gaussian prior over a logistic model with context = situation, time-of-day bucket and predicted energy (Chapelle & Li).
  - Share strength across users only through a design-time prior, because there is no cloud: health-derived rewards must stay on the phone.
- **Exploration floor:** clip each arm's selection probability to ≥ 10–20% (HeartSteps style). **Log the probability** used for every queue, so the team can do off-policy (replay / inverse-propensity) analysis after the pilot.
- **Minimum data:** a Beta posterior for one cell only separates arms after tens of plays. With about 1–3 queues a day for 14 days (14–40 queues a user), expect *per-user* learning across about 3 arms within one or two common situations at best. Present it as "the app starts to adapt", not as "it learned you". Pooling the 5 users' logs offline after the pilot (on the team's machines, only with consent and only if health data are excluded) is the way to set better priors for the next version.
- **Known pitfalls:**
  1. Position and novelty effects within a queue.
  2. Rewards confounded by the situation (stress queues may simply be rated lower). Keep rewards per situation, or action-center them.
  3. Habituation ("dosage"): the same strategy may wear off.
  4. A bandit that collapses onto one arm. The clipping floor prevents this.
  5. Apparent personalization that is only noise. Use the resampling check (arXiv 2304.05365) before claiming it in the report.

### Gaps
- No paper found that applies contextual bandits to **state-targeted short music queues** with wearable context. The closest are mHealth bandits (HeartSteps) and playlist/carousel bandits (Deezer, Spotify).
- No published random-intercept variance τ for EmoPhone arousal was found. It must be estimated by the team (the hard rule allows aggregate results in Git).
- The exact second clipping constant (ε₁) in HeartSteps V2 was cut off in the extracted text.

---

## Q5. iOS feasibility with an iOS 18.0 target (no watchOS app)

### Takeaway
Everything needed for a one-tap question works on iOS 18.0 without a watch app:
- **Local notifications with action buttons** are answerable from the lock screen and are **forwarded to Apple Watch** when the phone is locked. A watch tap runs the action on the iPhone in the background. Watch Double Tap fires the **first non-destructive action**, which can bias answers.
- **Interactive widgets** (iOS 17+) and **Controls** (iOS 18+) run App Intents, but **not on a locked device** without authentication.
- **BGProcessingTask** is Apple's documented home for overnight ML training.
- **Core ML MLUpdateTask** updates only neural networks and k-NN (plus pipelines), not a GLM logistic regression. A hand-written Swift Bayesian logistic update is the simpler path.
- `HKStateOfMind` (iOS 18.0) can supply extra valence labels and accept the check-in.
- App Review: no medical claims (1.4.1); health data not for marketing and **not stored in iCloud**; no false data written to HealthKit (5.1.3); and human-subject research needs consent and ethics approval (5.1.3 iii–iv).

### Cited Findings
**Notifications (UserNotifications, iOS 10+)**
- Notification forwarding: a **local notification from an iOS app** goes to "Apple Watch or iPhone, depending on the locked/unlocked state of both devices". The rules: (1) iPhone unlocked with screen on → phone; (2) otherwise, watch on the wrist and unlocked → watch; (3) otherwise → iPhone — [Apple Docs: Taking advantage of notification forwarding](https://developer.apple.com/documentation/watchos-apps/taking-advantage-of-notification-forwarding)
- Forwarding works "even if you don't have a watchOS app". For a forwarded notification, tapping an action on the watch "runs it in the background on their iPhone" — [Apple watchOS docs, via search summary](https://developer.apple.com/documentation/watchos-apps/notifications.md) (not re-read verbatim). A developer-forum answer says actions must be the same on iPhone and Watch; per-device suppression was not available — [Apple Developer Forums 4294](https://developer.apple.com/forums/thread/4294)
- "Users can respond to actions while the device is locked, which would make files encrypted with the `complete` [file protection] option unavailable to your app." — [Apple Docs: Declaring your actionable notification types](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types)
- "When someone performs a **Double Tap** gesture while viewing a notification on Apple Watch Series 9 or Apple Watch Ultra 2, the system invokes the **first nondestructive action**." — [same page](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types)
- `UNNotificationActionOptions.authenticationRequired`: "The action can be performed only on an unlocked device"; the system asks the user to unlock first — [Apple Docs](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/authenticationrequired)
- `UNTextInputNotificationAction` is available from iOS 10 — [Apple Docs](https://developer.apple.com/documentation/usernotifications/untextinputnotificationaction)

**Widgets, Live Activities, Controls**
- "On a locked device, buttons and toggles are inactive and the system doesn't perform actions unless a person authenticates and unlocks their device." Interactive buttons and toggles need iOS 17. Intents that adopt `LiveActivityIntent` or `AudioPlaybackIntent` run in the app's process; plain `AppIntent`s run in the widget extension — [Apple Docs: Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- A forum report confirms that tapping a widget toggle while locked does not execute the intent — [Apple Developer Forums 766780](https://developer.apple.com/forums/thread/766780)
- Live Activities: active for **up to 8 hours**, then stay on the Lock Screen for up to 4 more hours (**max 12 h**) — [Apple Docs: Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- A `LiveActivityIntent` can start a Live Activity "without opening your app", for example from a Control Center control — [Apple Docs: LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent)
- **Controls** "perform your app's actions from Control Center, the Lock Screen, and the Action button". Apple advises: "require device authentication before a control performs its action, as well as redact the text … when the device is locked" — [Apple Docs: Creating controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)

**Background updates**
- Apple says to defer intensive work "overnight when the device charges … such as **training machine learning models**", scheduled with `BGProcessingTask`, and "the system decides the best time to launch" — [Apple Docs: Choosing background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- `BGProcessingTaskRequest` (iOS 13): "can take minutes to complete". It has `requiresExternalPower` and `requiresNetworkConnectivity` — [Apple Docs](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest)
- `BGContinuedProcessingTaskRequest` is **iOS 26.0+** and must be submitted from the foreground after a user action, so it is **not usable on iOS 18** without `#available` — [Apple Docs](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest)

**Core ML on-device updates**
- `MLUpdateTask` (iOS 13): "updates a model with additional training data" from an `MLBatchProvider` — [Apple Docs: MLUpdateTask](https://developer.apple.com/documentation/coreml/mlupdatetask), [Personalizing a model with on-device updates](https://developer.apple.com/documentation/coreml/personalizing-a-model-with-on-device-updates)
- Updatable model types: Core ML 3 supports updates for **neural networks** (convolution and fully connected layers; cross-entropy and MSE losses) and **k-nearest-neighbour classifiers** — [WWDC19 session 704](https://developer.apple.com/videos/play/wwdc2019/704), [InfoQ](https://www.infoq.com/news/2019/06/core-ml-3-on-device-retrain). coremltools also lists **pipelines** — [coremltools updatable models guide](https://cymbalrush.github.io/coremltools/docs-guides/_sources/source/updatable-model-examples.rst)

**HealthKit State of Mind** (from the earlier notes, plus the API page)
- `HKStateOfMind` is iOS 18.0. `init(date:kind:valence:labels:associations:metadata:)` takes a `valence` (−1…+1), a `kind` (`dailyMood` or `momentaryEmotion`) and **arrays** of labels and associations — [Apple Docs: HKStateOfMind](https://developer.apple.com/documentation/healthkit/hkstateofmind), [init](https://developer.apple.com/documentation/healthkit/hkstateofmind/init(date:kind:valence:labels:associations:metadata:))

**App Store Review Guidelines (last updated 16 Oct 2026)** — [Apple](https://developer.apple.com/app-store/review/guidelines/)
- 1.4.1: medical apps that "could provide inaccurate data" get greater scrutiny. "Apps must clearly disclose data and methodology to support accuracy claims relating to health measurements". Apps "should remind users to check with a doctor".
- 5.1.3(i): health, fitness and HealthKit data may not be used or disclosed "for advertising, marketing, or other use-based data mining purposes other than improving health management, or for the purpose of health research, and then only with permission". You must disclose the specific health data collected.
- 5.1.3(ii): "Apps must not write false or inaccurate data into HealthKit … and may not store personal health information in iCloud."
- 5.1.3(iii)–(iv): apps "conducting health-related human subject research must obtain consent" (nature, purpose, duration, risks, confidentiality, contact, withdrawal) and "must secure approval from an independent ethics review board".
- 4.5.4: push notifications "must not be required for the app to function, and should not be used to send sensitive personal or confidential information".

### Inferences
- **Main channel (works on iOS 18, iPhone only):** a local notification with a category of 3 or 4 actions: "Low", "Medium", "High", plus "Not now".
  - Use background actions, not `.foreground`, so the answer is one tap on the lock screen or on the watch.
  - Because of Double Tap, **put "Not now" first**. Otherwise a reflexive Double Tap records "Low" (or whatever comes first) as a real answer.
  - Keep notification text neutral ("Quick check: energy right now?"), with no health values, which also follows 4.5.4.
- **Storage when locked:** answers can arrive while the phone is locked, so the handler must not depend on a store with `.complete` file protection. Either give the SwiftData store `completeUntilFirstUserAuthentication`, or append the answer to a small unprotected-until-first-unlock queue file and merge it into SwiftData at next launch. **The team should check which protection class the current SwiftData store uses.**
- **Widgets and Controls (iOS 17 / 18):** good *entry points* (open the in-app 2D pad, or run an intent on an unlocked phone), but not lock-screen answering. The Lock Screen is where the notification wins.
- **Live Activity during a queue:** possible (an "energy / fit" button set on the Lock Screen while music plays). However, buttons are inactive when locked, the 8 h limit applies, and it adds UI that the design canvas does not include. Per the project rules this needs a design decision first.
- **Learning implementation:** write the Bayesian logistic update by hand in Swift (Laplace / diagonal Gaussian, Chapelle–Li Algorithm 3). Keep the population coefficients in the bundled model or a JSON file, and the per-user posterior (mean and variance per coefficient) in SwiftData. Do not convert the logistic regression into an updatable Core ML neural network just to use `MLUpdateTask`: it is heavier, harder to test against golden fixtures, and gives no benefit at this data size.
- **Nightly job:** use `BGProcessingTaskRequest` with `requiresExternalPower = true`, but treat it as best-effort and fall back to refitting at app launch. HealthKit data are encrypted while locked (earlier notes), so the nightly job should only touch the app's own label/feature store.
- **HKStateOfMind:**
  - *Read* (needs the user's permission for State of Mind): adds valence labels when the user logs in Apple's apps. Expect them to be sparse (earlier notes).
  - *Write* the check-in only if the team adds pleasantness: `kind: .momentaryEmotion`, `valence` mapped from the answer, `labels: []`, `associations: []`. This is a genuine self-report, so 5.1.3(ii) is respected.
  - **Downsides:** an extra permission prompt; the Health app will show its own valence classification words; and an energy-only answer cannot be written, because HealthKit has no arousal field.
  - Make it **opt-in**.
- **Pilot status:** a ≤ 5-user, 2-week pilot that records health-linked self-reports is plausibly "health-related human subject research" under 5.1.3(iii)–(iv) if distributed through the App Store. Through development builds or TestFlight it is mainly a course/university ethics question. The team should confirm what its course requires (consent form at minimum).

### Gaps
- Whether `UNNotificationAction` buttons forwarded to Apple Watch still appear when the iPhone app has **no** watch app on watchOS 26/27 was not confirmed verbatim from a current Apple page (only via search summary and older forum threads). It should be tested on a device.
- Apple's current list of updatable Core ML model types beyond the 2019 announcement was not found in current docs (`MLUpdateTask` pages do not list them).
- Whether `HKStateOfMind` accepts an **empty** labels array is not stated in the docs. It should be tested.
- Maximum number of notification actions shown on iPhone and Watch was not verified in this session.
- How App Review treats TestFlight-only research pilots under 5.1.3(iv) was not found.

---

## Q6. Extra Apple Watch / iPhone signals for a personal on-device model, and how many labels per user before extra per-user coefficients help

### Takeaway
A personal model *could* add signals that EmoPhone lacks: HRV SDNN, respiratory rate, wrist temperature, sleep stages, time in daylight, environmental noise, active energy and the HR motion context. **There is no population prior for them**, though, so each coefficient must be learned from the user's own labels. At about 30–60 labels a user, the evidence and rules of thumb say this is not enough for more than 1–2 shrunk coefficients. Commercial products need 7–14 nights just to set a personal baseline, before any learning from labels. The practical pilot plan: keep EmoPhone features, add per-user baselines (z-scores), learn a per-user intercept, and **log** the extra signals for offline analysis after the pilot.

### Cited Findings
- Signal availability and cadence (all on iOS 18 or earlier), from the earlier notes:
  - HR: about 1 sample per 5-minute window when still.
  - SDNN: about every 4 h by default, only when still.
  - Respiratory rate and wrist temperature: nightly (wrist temperature is one value a night, Series 8+).
  - Sleep stages: kappa 0.63, 0.68 after iOS 26.
  - `timeInDaylight`: iOS 17.
  - `environmentalAudioExposure`: iOS 13.
  - `physicalEffort`: iOS 17.
  - HR `MotionContext` metadata: sedentary / active.

  — [apple_watch_signals.md: Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf), [Apple Docs: heartRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartrate), [Apple sleep stages paper 2025](https://www.apple.com/kr/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf), [Apple Docs: timeInDaylight](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/timeindaylight)
- HRV shows the most consistent link with stress in the literature: low parasympathetic activity, according to a meta-analysis of 37 publications — [Kim et al. 2018, PMC5900369](https://pmc.ncbi.nlm.nih.gov/articles/PMC5900369) (from the earlier notes)
- Baseline periods in Apple's own products: Vitals needs **7 nights** to set a typical range — [Apple Support 120142](https://support.apple.com/en-us/120142). Oura: "It can take **up to two weeks** for the Oura App to learn your average values for each contributor". HRV balance compares a 14-day weighted average with a 3-month average — [Oura Readiness contributors](https://support.ouraring.com/hc/en-us/articles/360057791533)
- Label-count evidence:
  - < 2% AUROC gain with about 70 labels a user, about 5% with about 566 — [Zhang et al. 2024](https://ic.kaist.ac.kr/publications/papers/zhang2024reproducible.pdf)
  - WHOOP will not estimate a behaviour's personal effect before **5 yes + 5 no** entries — [WHOOP](https://www.whoop.com/ca/en/thelocker/a-new-way-to-see-insights-on-which-behaviors-affect-your-recovery/)
  - Riley's prediction-model criteria (shrinkage ≥ 0.9) replace the EPV-10 heuristic — [PMC6519266](https://pmc.ncbi.nlm.nih.gov/articles/PMC6519266)

### Inferences
- **Labels-to-coefficients rule of thumb (my synthesis):**
  - Unpenalized: about 10 minority-class labels per coefficient.
  - With Bayesian shrinkage toward the population prior: 15–40 labels before a personal intercept reaches 50–70% weight (τ ≈ 0.5, Q4 arithmetic).
  - A new per-user coefficient on a feature with no prior (prior mean 0) needs a similar or larger count. Its estimate stays near 0 until then, which is safe but useless in a 2-week pilot.
  - Expect personal coefficients to start mattering after **about 60–100 labels** a user (1–2 months at 2 a day). This is consistent with K-EmoPhone's small gain at about 70 labels.
- **Ranking of extra signals for a later personal model:**
  1. HR restricted to sedentary samples (via MotionContext). Cheap, frequent, and close to the EmoPhone HR feature.
  2. Recent active energy / physicalEffort (behavioural activation).
  3. Sleep structure from the previous night (latency, wake after sleep onset), for the wake-up situation.
  4. Overnight SDNN / respiratory rate / wrist temperature as next-day baseline shifts.
  5. Time in daylight (daily and circadian context).
  6. Environmental noise.

  Headphone audio exposure is circular, because it reflects Harmony's own playback (earlier notes).
- **"Unknown is not zero" (project rule):** each extra signal needs a missingness indicator. In a Bayesian per-user model, simply skip the term when the value is unknown; do not impute 0.
- **Pilot recommendation:** log the extra signals on the phone alongside each label, but do not use them for decisions. After the pilot, analyse the 5 users' logs only if consent allows export and health data never leave the phone. Otherwise the analysis must also run on the phone (for example, an in-app "export aggregate correlations" view). This choice must be settled against the hard rule "health data never leave the phone".

### Gaps
- No study found that measures how many labels a *single user* needs before HRV, temperature or daylight improve a personal arousal model on Apple Watch data.
- Whether Recovery HRV / RMSSD (iOS 27, Series 12) reaches HealthKit on pilot devices is unknown (earlier notes).

---

## Q7. How products present "a model that learns you" (for the team's presentation)

### Takeaway
Products frame learning as **(1) a calibration period with a stated length**, **(2) comparison with "your usual"** rather than with a population, and **(3) insights unlocked after a minimum amount of personal data**, with "correlation, not causation" wording. None publishes accuracy for its personal model. Harmony can honestly say: "It starts from a model trained on students; each answer adjusts it to you; after about 2 weeks it compares you with your own usual; it never sends your health data anywhere."

### Cited Findings
- **Oura:** "Readiness contributors are based on your personal averages. It can take up to two weeks for the Oura App to learn your average values … 'long-term' refers to personal data collected over the past two months." — [Oura support](https://support.ouraring.com/hc/en-us/articles/360057791533)
- **WHOOP:** behaviour impact appears after 5 "yes" + 5 "no" in 90 days and is framed as association, not causation — [WHOOP](https://www.whoop.com/ca/en/thelocker/a-new-way-to-see-insights-on-which-behaviors-affect-your-recovery/). A community thread says initial calibration takes about 4 days and a full baseline about 30 days — [WHOOP Community](https://community.whoop.com/t/how-long-does-it-take-for-whoop-to-learn-your-baseline-metrics/359) (forum, not official)
- **Apple:** Vitals needs 7 nights for a typical range — [Apple Support 120142](https://support.apple.com/en-us/120142). State of Mind entries can be compared with daylight, sleep, exercise and mindful minutes — [Mindfulness App Store listing](https://apps.apple.com/us/app/mindfulness/id1560383515). Readiness (Series 12 / Ultra 4) reportedly needs 7 nights and is not a HealthKit type — [Sahha](https://sahha.ai/blog/apple-event-2026-health-readiness-labs/) (community; from the earlier notes)
- **Endel:** soundscapes react to "time of day, weather, heart rate, and location". The beat is compared with the user's resting heart rate (real-time HR needs an Apple Watch; otherwise historical data are used). Generation runs on device. Claims of being "backed by neuroscience" are company statements — [Endel technology](https://endel.io/technology), [Endel Daily Energy Cycles](https://endel.zendesk.com/hc/articles/360014891500), [Wikipedia: Endel](https://en.wikipedia.org/wiki/Endel_(app))
- **Garmin Body Battery:** uses Firstbeat analytics. No documented learning period was found — [gneta comparison](https://www.gneta.app/blog/recovery-scores-compared-garmin-whoop-oura) (third-party)
- **Spotify BaRT:** pairs every recommendation with an **explanation** ("shelves") and learns per context — [RecSys 2018](https://static1.squarespace.com/static/5ae0d0b48ab7227d232c2bea/t/5ba85dac7817f764cdda68f4/1537760712983/bart_recsys.pdf)

### Inferences
- **Slide-ready framing:**
  - Day 1: population prior, trained on 282 Korean students' data.
  - Each answer: a small personal correction, shown as a confidence bar that tightens.
  - About 2 weeks: "your usual" established, like Oura and Apple Vitals.
  - Queue choice: tries a few approaches and keeps what you skip less (a bandit, as at Spotify and Deezer).
  - Privacy: all on the phone.
- **Honesty guardrail:** with AUROC ≈ 0.56–0.58 and 2 weeks of data, claim *adaptation*, not *accuracy*. Use the resampling check (Q4) before saying "it personalized". Avoid any wording that implies a medical measurement (1.4.1, and the project rule).

### Gaps
- No official Garmin documentation of a Body Battery learning period was retrieved.
- No official WHOOP statement of calibration length was retrieved (only a community thread).
- No product publishes the accuracy or label needs of its *personal* model.
