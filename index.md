---
layout: default
title: "Harmony: Context-Aware Music Companion Using Wearable Health Data"
---

> **Course:** ITE 351 - AI & Applications, Hanyang University  
> **Track:** Option B - Prototype service using AIML techniques  
> **Version:** blog in progress, November 24, 2026

---

## Group Members

- **Clément Royer**, Dept. of Computer Science, Hanyang University, clement.royer@edu.devinci.fr
- **Cyprien Vanden Abeele**, Dept. of Computer Science, Hanyang University, cyprien.vanden_abeele@edu.devinci.fr
- **Lucas Miskulin**, Dept. of Computer Science, Hanyang University, lucas.miskulin@edu.ece.fr
- **Riad Mekideche**, Dept. of Computer Science, Hanyang University, riad.mekideche@edu.devinci.fr

**Video presentation (Task 2):** the link will be added here with the final version of the blog.

---

## Table of Contents

- [I. Introduction](#i-introduction)
  - [A. Harmony in One Minute](#a-harmony-in-one-minute)
  - [B. Motivation](#b-motivation)
  - [C. What We Want to See at the End](#c-what-we-want-to-see-at-the-end)
- [II. Datasets](#ii-datasets)
  - [A. EmoPhone: Watch Data and Mood Answers](#a-emophone-watch-data-and-mood-answers)
  - [B. UC Irvine: A Second Test Set](#b-uc-irvine-a-second-test-set)
  - [C. MuSe: Mood Scores for Songs](#c-muse-mood-scores-for-songs)
- [III. Methodology](#iii-methodology)
  - [A. How the Whole System Works](#a-how-the-whole-system-works)
  - [B. The State Model: Reading the Watch](#b-the-state-model-reading-the-watch)
  - [C. From Python to the iPhone With Core ML](#c-from-python-to-the-iphone-with-core-ml)
  - [D. Song Scores: MuSe and a Language Model](#d-song-scores-muse-and-a-language-model)
  - [E. From a Number to a Queue](#e-from-a-number-to-a-queue)
  - [F. Next Step: Harmony Learns From You](#f-next-step-harmony-learns-from-you)
- [IV. Evaluation & Analysis](#iv-evaluation--analysis)
  - [A. How We Test](#a-how-we-test)
  - [B. Results of the State Model](#b-results-of-the-state-model)
  - [C. What the Model Looks At](#c-what-the-model-looks-at)
  - [D. Personalisation in Simulation](#d-personalisation-in-simulation)
  - [E. How Good Are the Song Scores](#e-how-good-are-the-song-scores)
  - [F. The App on a Real iPhone](#f-the-app-on-a-real-iphone)
  - [G. The Pilot](#g-the-pilot)
- [V. Related Work](#v-related-work)
  - [A. Existing Studies and Products](#a-existing-studies-and-products)
  - [B. Tools and Libraries](#b-tools-and-libraries)
- [VI. Conclusion: Discussion](#vi-conclusion-discussion)
- [References](#references)
- [Progress Log](#progress-log)

---

## I. Introduction

### A. Harmony in One Minute

Harmony is an iPhone app that picks music for the moment you are in. You open it, tap one of four moments (waking up, stress, low energy or winding down), and it starts a short queue of three to five songs from **your own Spotify library**.

The order of the songs is the point. The first song matches how activated you seem right now, and the next ones move step by step toward what the moment needs: calmer before sleep, more energetic in the morning. To guess "how activated you seem right now", Harmony reads your Apple Watch data on the phone (heart rate, steps and last night's sleep), compares them with your own usual values, and adds the time of day. A small machine-learning model turns all this into one number between 0 and 1. Each song also has two scores, energy and positivity, so the app can line songs up from where you are to where you want to go.

The player shows one short sentence that explains the queue, for example *"Evening: medium songs first, then a little calmer."* The music plays in Spotify as usual. You can skip a song, like it, and at the end answer "Did it fit?". Harmony keeps these answers on the phone to do better next time.

**An example.** It is 11:30 p.m. and you tap *Wind-down*. Your heart rate is higher than your usual evening value, so Harmony does not jump straight to sleepy music: the first two songs have a medium energy, and the next three get calmer one after the other.

<p align="center">
  <img src="docs/blog/home.png" width="170" alt="Home screen with the four moments">
  <img src="docs/blog/player.png" width="170" alt="Player with the reason for the queue">
  <img src="docs/blog/queue.png" width="170" alt="Queue from the current state to the goal">
  <img src="docs/blog/library.png" width="170" alt="Library with the origin of each song score">
</p>

*Fig. 1. The app on the iOS simulator in demo mode (synthetic songs and watch data, which is why there are no real covers). From left to right: Home, the player with the reason for the queue, the queue going from "Now" to "Goal", and the library, where each song shows where its score comes from.*

**Table I - The Four Moments**

| **Moment** | **Typical time** | **What the music should do** | **Energy at the end of the queue** |
|---|---|---|---|
| Wake-up | morning, after sleep | get gently more energetic | about 0.7 |
| Stress | any time | get calmer, with rather positive songs | about 0.3 |
| Low energy | afternoon slump | get more energetic, with rather positive songs | about 0.7 |
| Wind-down | evening, night | get calm, ready for sleep | about 0.2 |

Harmony never tells you "you are stressed" and never names an emotion. It makes no medical claim either: it only offers calmer or more energetic music, and you can always pick the moment yourself and skip any song.

### B. Motivation

Poor sleep and stress are an everyday problem in Korea. A report based on a KB Financial Group study gives an average sleep time of 471 minutes per day, 30 minutes below the OECD average. In a Philips survey cited by the same report, only 41% of Koreans were satisfied with their sleep, and stress was the first cause of disturbed sleep [1].

Music can help. A Cochrane review of 13 randomised trials (1,007 adults) found that listening to music improved sleep quality [2]. This is evidence about music in general: it does not show that our app improves well-being, and we do not claim it.

Yet music apps ignore the body of the listener. A smartwatch measures heart rate, steps and sleep all day, but streaming platforms choose songs from the listening history and the time of day only. Our users are students and young workers who wear a smartwatch and listen to music on their phone. They want the music they already like, at the right moment, with one tap. We belong to this group ourselves.

For an AI course, the project raises a real question: can a cheap wrist sensor tell how activated a person feels in daily life, well enough to choose music? Mood answers given on a phone are noisy and published results are modest [3], [9], so we want to measure honestly how far simple models go, run them on the phone, and see whether the app can learn from each user.

### C. What We Want to See at the End

1. **A state model** that tells, from the watch and the clock, whether a person is more or less activated than usual. It is tested on people it has never seen, and it must beat a model that only knows the time of day.
2. **All the AI on the phone.** The model is converted to Core ML, so heart rate and sleep never leave the iPhone.
3. **Scores for any song**, even songs that no dataset knows, using a large language model (LLM).
4. **An app that learns from each user.** Short answers ("energy right now?"), skips and likes adjust the model and the way queues are built for that person.
5. **A two-week pilot** with real Apple Watch data, comparing queues that use the body with queues that use the clock only.

**Where we are on November 24.** Points 1 to 3 are done, and the app works from start to finish on an iPhone 16 (Sections III and IV). Point 4 is designed and tested in simulation, and is being built (Section III-F). The pilot runs from December 7 to December 20.

---

## II. Datasets

Harmony needs two kinds of data: examples of people's watch signals together with how they felt at that moment, to train the state model, and mood scores for songs. No single dataset has both, so we use three.

### A. EmoPhone: Watch Data and Mood Answers

We train the state model on **EmoPhone** [3], a dataset from KAIST shared on Harvard Dataverse. After emailing the dataset owner, we were granted access to the complete data for this project. The authors allow us to use it but not to share it, so the files stay on our computers: this blog only shows our method and aggregate results.

EmoPhone has three waves (D-1, D-2 and D-3). In each wave, students of a Korean university used an Android phone and wore a **Fitbit Inspire HR** for about four weeks. About seven times a day, the phone asked them short questions about how they felt. Table II gives the size of each wave.

**Table II - EmoPhone Waves**

| **Wave** | **Period of the answers** | **Participants** | **Mood answers** |
|---|---|---|---|
| D-1 | Feb. 8 - Apr. 2, 2020 | 92 | 10,259 |
| D-2 | Dec. 7, 2020 - Jan. 27, 2021 | 99 | 21,042 |
| D-3 | Nov. 24, 2021 - Jan. 11, 2022 | 106 | 21,838 |
| **Total** | | **297** | **53,139** |

The 297 participant-waves correspond to 282 different people: according to the authors, 14 students took part in more than one wave. Their codes are not linked across waves, so we treat each wave and code as a separate person. The authors report that removing these students changes the results between waves by at most 0.002 AUROC.

**What we use.** The **heart rate** from the Fitbit (about one reading every 5 seconds), the **steps** per minute, and from each mood answer: the time, the **arousal** (how calm or activated the person feels, from -3 to +3) and the **stress**.

**What we leave out.** EmoPhone also has phone sensors (location, app use, key events...) and questionnaires about each participant. Our app will only read the watch and the clock, so the model must work with the same inputs.

**Cleaning.** Timestamps are in UTC and we convert them to Korean time, because the time of day is a model input. EmoPhone has no measured sleep, so we estimate it from heart rate and steps (Section III-B). A night or a period without watch data is marked **unknown**, never zero sleep or zero steps. Wave D-3 asks stress on a 0 to 6 scale, which we bring back to -3 to +3. People with sensor files but no mood answer are left out.

**The label.** For each answer, the label is 1 when the arousal is above the person's own average, and 0 otherwise. People use the scale differently: one student answers +1 on an ordinary day, another only on a very lively day. A label relative to each person is fairer, and it is exactly what the app needs: "more or less activated than usual".

### B. UC Irvine: A Second Test Set

To see whether the model works outside EmoPhone, we test it on a second public dataset from UC Irvine [4]. Students in Southern California wore a **Samsung smartwatch** and an **Oura ring** around the 2020 COVID-19 lockdown. The article reports 21 students; the files contain 24 participant folders, which we always keep apart in the tests. They rated their mood once a day (3,949 answers).

There is no arousal question, so we average six items (active, alert, excited, enthusiastic, jittery, nervous) and use the same "above your own average" label. We never train the app's model on this dataset: it only tells us whether the model transfers to other people, other devices and another country.

### C. MuSe: Mood Scores for Songs

Spotify removed the audio features (energy, valence) from its Web API for new apps in November 2024 [5], so the app cannot get a mood score for each song from Spotify. We use **MuSe** [6] instead, a public dataset (CC BY 4.0) in which each song has a valence and an arousal score computed from the Last.fm tags given by listeners. We use version 3, published by the authors on Kaggle: 90,001 songs, 68.5% of them with a Spotify ID and 92.6% with a genre.

- **Scale.** The raw scores are packed in a small range, so we use percentile ranks. The **energy** comes from the arousal and the **positivity** from the valence: an energy of 0.2 means "calmer than 80% of MuSe songs".
- **Duplicates.** Some Spotify IDs point to several different songs, so we remove them, and we keep one row per normalised title and artist. 89,269 songs remain, 59,679 of them with a Spotify ID.
- **Limits.** The scores of a single song are rough: the median song has only 2 emotion tags, and 28.6% of the songs have only one.

MuSe mostly covers older Western songs. On the 2,045 songs of a team member's library, only 233 (11.4%) are in MuSe: 102 found by Spotify ID and 131 by title and first artist. This is why the app needs a second way to score songs (Section III-D).

---

## III. Methodology

### A. How the Whole System Works

![Architecture of Harmony: everything runs on the iPhone except a small Cloudflare Worker that calls the language model](docs/architecture.svg)

*Fig. 2. Architecture. Green parts run on the iPhone, orange ones are external services, blue is our only cloud part, purple is the offline training on our computers.*

Here is what happens, step by step:

1. **Once, on our computers.** We build the inputs from EmoPhone, train the state model in Python with scikit-learn, evaluate it, and convert it to Core ML. The model file ships inside the app.
2. **At the first launch.** The user signs in with Spotify and chooses which Apple Health data the app may read. Harmony imports the saved songs, top songs and recent songs, and gives each one an energy and a positivity score, in the background.
3. **Each time the app opens.** It reads the new watch samples from HealthKit and keeps hourly and nightly summaries.
4. **When the user taps a moment.** The phone computes the 13 model inputs from the last 14 days of watch data, runs the model, builds the queue and plays it in Spotify with the Spotify iOS SDK.
5. **During and after the queue.** Skips, likes and the "Did it fit?" answer are stored on the phone for the next queues.

Health data never leave the phone. The only cloud part is a small **Cloudflare Worker** that holds the API key of the language model: it receives song titles and artists, nothing else. Since Spotify only allows five accounts for an app in development mode [13], Harmony is a demonstrator for a few users, not a store app.

The app combines three kinds of AI: a **classical machine-learning model** for the state (Sections III-B and III-C), a **large language model** for song scores (III-D), and, in the next version, **on-device learning** from each user (III-F). Simple rules connect them (III-E).

### B. The State Model: Reading the Watch

We frame the problem as a **binary classification**. For a given moment, the model looks at what the watch and the clock say just before, and gives the probability that the person feels more activated than usual.

**Inputs.** The model has 13 inputs (Table III). Most of them compare a signal with the person's **usual** value, because a heart rate of 80 means something different for each of us. The usual value is the mean and the spread of the person's own values over the **14 days before** the moment, measured every 30 minutes from 8 a.m. to midnight when the watch is worn. It needs at least 7 days of data. An input of +1 then means "one usual spread above your usual" (a z-score).

**Table III - The 13 Inputs of the State Model**

| **Group** | **Input** | **In plain words** |
|---|---|---|
| Time | hour (sine and cosine) | the time of day on a circle, so 11 p.m. is close to 1 a.m. |
| Time | weekend | Saturday or Sunday |
| Heart rate | last 15, 30 and 60 min vs. usual | is your heart rate higher than usual right now? |
| Heart rate | last 30 min vs. usual for this time of day | same question, compared with your usual for this 3-hour block, since heart rate changes during the day |
| Steps | last 15, 30 and 60 min vs. usual | have you moved more than usual? (log of the step count) |
| Sleep | last night vs. usual | did you sleep more or less than usual? |
| Sleep | hours since waking up | how long you have been awake |
| Sleep | sleep unknown | the watch was not worn last night |

**Adapting the Fitbit data to the Apple Watch.** The Fitbit of EmoPhone measures the heart rate every 5 seconds, but the Apple Watch only every few minutes: on our own watch we measured a median gap of 4.2 minutes at night and 4.6 minutes during the day. So the features use **one heart-rate reading every 5 minutes**, and a single reading is enough for a window. This choice costs almost nothing in accuracy (Section IV-B).

**Unknown is not zero.** A window without any watch data is **unknown**, not 0 steps or 0 heart rate. Unknown inputs are replaced by the median of the training data, and the model also knows when last night's sleep is unknown.

**Sleep.** EmoPhone has no measured sleep, so we estimate it the way watches do. A minute counts as asleep when the watch is worn, there are no steps and the heart rate is close to the person's lowest values. The night is the longest such period between 9 p.m. and noon (short gaps merged, at least 2 hours). If the heart rate covers less than 60% of the night, the watch was not worn and the night is unknown. In the app, we simply read the sleep measured by the Apple Watch.

**The model.** We use a **logistic regression** (scikit-learn 1.5.2), after filling unknown values with the median and standardising each input. We chose it for three reasons. The labels are noisy and come from a few hundred people, so a simple model is hard to overfit. Its weights can be read directly (Section IV-C). And it is tiny: 13 weights and one intercept, which runs instantly on a phone.

**What about deep learning?** We compared it with bigger models on waves D-1 and D-2, with the same folds: gradient-boosted trees, a tuned logistic regression, a model with interactions between inputs, a small **neural network** (a multi-layer perceptron, also trained on three outputs at once: activation, pleasantness and stress) and ensembles of these. None of them beat the plain logistic regression by more than the variation between folds. This matches the GLOBEM benchmark [8]: on a related problem (detecting depression from the phone and Fitbit data of students), deep sequence models such as 1D-CNN and LSTM did not beat a pipeline of hand-made features. With a few hundred training people, a deep model on raw heart-rate series would add a lot of cost (conversion, missing data, overfitting) for a gain smaller than the noise. We put our effort into personalisation instead (Section III-F).

**Fallback.** A second logistic regression uses the 3 time inputs only. The app uses it when there is no heart rate in the last 30 minutes or when the person's usual values are not ready yet (the first week). It is also the baseline that our model must beat.

**Final training.** After the evaluation of Section IV, the final model is trained once on all three waves (53,139 answers).

### C. From Python to the iPhone With Core ML

Training happens in Python, but the model must run in Swift on the phone. This step has two parts.

**Converting the model.** The scikit-learn pipeline (median filling, standardisation, logistic regression) is converted with **coremltools** into `StateModel.mlmodel`: 13 numeric inputs, where a missing value is passed as NaN, and one probability as output. On 100 rows of D-1, half of them with unknown values, Core ML and scikit-learn give the same probabilities (largest difference about 1e-16). The same parameters are also saved in a small JSON file (`model_params.json`, 2.2 KB) that tells the app the exact order of the inputs and holds the time-only model.

**Computing the same inputs.** The hard part is not the model, it is the 13 inputs: Swift must compute exactly what Python computed from the raw watch samples, otherwise the model receives wrong values without any error. We use **golden tests**: Python generates 10 synthetic watch histories (a weekday, a weekend, a night, less than 7 days of history, a watch removed for an hour, an unknown night...) with the expected inputs and probability, and a Swift unit test must find the same values within 1e-6. We do the same for song-title normalisation and the LLM prompt, with test cases shared by Python, Swift and TypeScript.

**On the phone.** At each tap, the app reads the last 14 days of heart rate and steps from HealthKit in memory, computes the inputs and runs Core ML on the CPU. On an iPhone 16 with real watch data, one estimate takes 0.13 to 0.15 s. Raw samples are never stored and never sent.

### D. Song Scores: MuSe and a Language Model

Every imported song gets an energy and a positivity score between 0 and 1, in this order:

1. **MuSe.** The app looks for the song in a MuSe table shipped inside the app (SQLite), first by Spotify ID, then by normalised title and first artist (lower case, no accents, "feat." and mentions like "Remastered 2011" removed).
2. **The language model.** Otherwise, the title and artists go to our Cloudflare Worker, which asks **Claude Haiku 5.5** (Anthropic) for the two scores, by batches of 50 songs. The prompt describes each scale with the words listeners use as tags, defines 50 as a typical song, and gives 48 reference songs taken from MuSe with their scores (3 songs in each cell of a 4 x 4 grid of energy and positivity, all with at least 10 tags). The answer uses structured output, so it is always valid JSON with an index, an energy and a positivity from 0 to 100 for each song.
3. **Neutral.** If the Worker fails or a pair is invalid, the song gets 0.5 and 0.5, and the queue only uses it when nothing better is available.

Each song is scored once and the score is kept on the phone. On the 2,045-song library of Section II-C, the first scoring took 158 s, in the background. The Worker checks the user's Spotify token against an allow-list, keeps the API key as a secret, and limits each user to 50 requests a day.

The language model only sees a title and an artist, so its scores are estimates. Section IV-E measures how good they are.

### E. From a Number to a Queue

The queue follows the **iso principle** of music therapy [7]: start with music that matches the current state, then move step by step toward the target. We call `e0` the current state (from the model, between 0 and 1) and `g` the energy goal of the moment (Table I).

- **Length.** The queue has 5 songs when `e0` is far from `g` (more than 0.3 apart), otherwise 3.
- **Targets.** The first one or two songs aim at `e0`. The next targets are spread evenly from `e0` to `g`, and the last one is exactly the goal. A Wind-down queue never ends more energetic than it starts, and a Wake-up queue never gets calmer.
- **Choosing each song.** For each target, the app takes the library song whose energy is closest, with penalties: +0.2 for a rather negative song (positivity below 0.5) in Stress or Low energy, and +0.3 if the artist is already in the queue. Songs played in the last 3 days, and songs skipped twice in the same moment, are left out.
- **Suggestions.** If no song of the library is close enough (within 0.15), the app may add at most 2 MuSe songs by an artist or in a genre of the library, after checking with Spotify that the ID really is that song.
- **The reason.** The sentence on the player is built from fixed parts: the time of day, a short or long night, a heart rate higher or lower than usual, then the plan ("medium songs first, then a little calmer"). A test goes through every possible sentence and checks that none contains an emotion or a medical word.
- **The suggested moment.** On Home, one moment can be highlighted: Wake-up within 2 hours after waking, Wind-down after 9 p.m., Low energy between 1 and 5 p.m. when the state is low. Stress is never suggested automatically, because the model is too weak on stress (Section IV-B).

### F. Next Step: Harmony Learns From You

*Status: designed and simulated, being built for the pilot and the final demo.*

The watch model gives an estimate on the first day without asking anything, but it is weak (Section IV-B), and more inputs or bigger models barely change it (Section III-B). What does help is the user's own answers: in a simulation on EmoPhone, two short answers a day raise the AUROC from 0.555 to 0.666 (Section IV-D). The final version therefore adds three small parts, all running on the phone.

**1. A one-tap question.** At most two notifications a day ask *"Quick check: energy right now?"* with the buttons Low, Medium and High, or "Not now". The user can answer from the lock screen or the watch, and can turn the questions off. No answer is never read as "low".

**2. The personal layer.** Each answer gets a label: 1 if it is above the person's own average answer over the previous 14 days (at least 5 answers), 0 otherwise. The layer learns a single number `b` that is added to the shared model's output before the final probability:

```
p_personal = sigmoid(z_shared + b)

b = argmin over b of   sum_i  w_i * logloss(y_i, sigmoid(z_i + b))  +  b^2 / (2 * tau^2)
w_i = exp(-age_i / 2 days)        tau = 1.0
```

In words: `b` goes up if the person often feels more energetic than the shared model thinks, and down otherwise. Recent answers weigh more (an answer counts half after about 1.4 days), so the layer follows changes in the person's life. The `b^2` term is a Gaussian prior that keeps `b` close to 0 when there are few answers; with no answer at all, `b = 0` and the app behaves exactly like the shared model. The phone solves this in 3 to 5 Newton steps on a few dozen answers, so it needs no server and no background training. An optional second question, about how pleasant the moment feels, would give a second offset, used only to choose more or less positive songs and never shown to the user.

**3. A queue bandit (reinforcement learning).** For each moment, there are three ways to build the queue: *progressive* (the current rule), *half-step* (moves halfway toward the goal from the second song) and *long match* (stays longer at the current state, then moves). After each queue, a reward between 0 and 1 is computed: "Did it fit?" yes = 1, no = 0; with no answer, 1 minus the share of songs skipped before 30 s; +0.2 per like, capped at 1. The app picks the strategy by **Thompson sampling** with a Beta(1, 1) prior for each moment and strategy, mixed with a uniform choice so that each strategy keeps at least a 15% chance. The chosen probability is logged, so the strategies can be compared fairly afterwards. The state model itself is never trained on "Did it fit?".

Two smaller changes come with it. The shared model's probabilities stay between about 0.36 and 0.55, so queues often start from the same point; the app will instead use the **rank** of the current estimate among the person's own estimates of the last 14 days, which spreads the starting point from about 0.03 to 0.98. And a candidate shared model with 17 inputs (it adds the raw heart rate and steps, before the comparison with the usual) and a pleasantness model will be adopted only if they pass a criterion that we write down before looking at the results.

During the pilot, the personal layer is planned to run in **shadow mode**: it is computed and logged at each answer but does not change the queues, and only the energy question is asked. The bandit and the active personal layer come after the pilot, for the final demo.

---

## IV. Evaluation & Analysis

### A. How We Test

- **Whole people are kept apart.** The model is always tested on people it has never seen, with a 5-fold `GroupKFold` grouped by participant. A random split would put answers of the same person in both training and test, and give results that are too optimistic.
- **Three levels of test.** Cross-validation on waves D-1 and D-2 (31,301 answers, 191 participant-waves). Then **one single test on wave D-3** (21,838 answers, 106 participants), run once after the code was frozen. Then one test of the final model on UC Irvine, without any retraining.
- **A baseline to beat.** Every result is compared with a model that only knows the time of day. If our model does not beat it, the app uses the time of day only.
- **Metrics.** The **AUROC** is the probability that a random "more activated" moment gets a higher score than a random "less activated" one: 0.5 is a coin flip, 1 is perfect. The **balanced accuracy** is the average of the correct rates on the two classes.
- **The personal layer** will be evaluated in time order: each answer is predicted from earlier answers only.

### B. Results of the State Model

**Table IV - State Model Evaluation (people never seen in training)**

| **Test and inputs** | **AUROC** | **Balanced accuracy** |
|---|---|---|
| *Waves D-1 + D-2, 5 folds by participant (31,301 answers)* | | |
| Time of day only | 0.535 ± 0.017 | 0.505 |
| Time + heart rate | 0.554 ± 0.012 | 0.516 |
| **Time + heart rate + steps + sleep (our model)** | **0.563 ± 0.010** | **0.540** |
| *Wave D-3, held out and tested once (21,838 answers)* | | |
| Time of day only | 0.534 | 0.511 |
| Time + heart rate | 0.570 | 0.537 |
| **Time + heart rate + steps + sleep (our model)** | **0.576** | **0.541** |
| *UC Irvine, final model tested once (3,949 answers)* | | |
| Time + heart rate + steps + sleep | 0.496 | 0.499 |

What we read from it:

- **The model beats the time of day**, both in cross-validation (0.563 against 0.535) and on the wave it never saw (0.576 against 0.534). The gain is small, but it goes in the same direction in both tests.
- **Heart rate carries most of the signal.** Steps and sleep add a little on top (+0.009 in cross-validation, +0.006 on D-3). We keep them because the Apple Watch measures sleep itself, while EmoPhone sleep had to be estimated.
- **The level is in line with the literature.** On people not seen in training, the best EmoPhone benchmark models reach an AUROC of about 0.58 for arousal with thousands of phone and watch features [3]. We are close with 13 inputs that an Apple Watch can provide. WatchAnxiety [9] reports 60.4% balanced accuracy for anxiety from smartwatch heart rate, another sign that realistic results are modest.
- **It does not transfer to another population.** On UC Irvine (other students, other devices, mood rated once a day), the model is at chance level (0.496). The other way round, a model trained on UC Irvine gets 0.528 on D-3: each model only works on its own data. Apple Watch users at Hanyang are a third population, which only the pilot can measure.
- **Stress is barely predictable** (AUROC 0.53 to 0.56 in our first tests, and no better than the time of day with the final inputs). This is why the app never suggests the Stress moment on its own.
- **One heart-rate reading every 5 minutes is enough.** On D-1, time + heart rate gives 0.575 with one reading every 5 minutes against 0.576 with the full Fitbit series, so the model suits the Apple Watch.

### C. What the Model Looks At

For a logistic regression on standardised inputs, the weights are the explanation: a weight of +0.12 means that one usual spread more on this input raises the log-odds of "more activated than usual" by 0.12. Table V gives the largest weights of the final model.

**Table V - Largest Weights of the Final Model**

| **Input** | **Weight** | **Meaning** |
|---|---|---|
| Heart rate, last 15 min vs. usual | +0.12 | a heart rate above usual points to "more activated" |
| Sleep unknown | +0.12 | see the warning below |
| Time of day (sine, cosine) | -0.06, +0.05 | together: highest around 8 p.m., lowest around 8 a.m. |
| Steps, last 15 min vs. usual | +0.06 | moving more than usual points to "more activated" |
| Heart rate vs. usual for this time of day | +0.05 | |
| Heart rate, last 30 and 60 min vs. usual | -0.05, +0.04 | strongly linked to the 15-min value, to read together |
| Hours since waking up | +0.04 | |
| Last night's sleep vs. usual | +0.03 | |

All weights are small: the model is cautious, which is expected with noisy labels. One warning: "sleep unknown" has one of the largest weights, but it mostly reflects a habit of EmoPhone participants, who did not wear the Fitbit on about a third of the nights. It is not a signal from the body, and Apple Watch users who wear their watch at night will rarely have it. We do not present it as a body signal.

### D. Personalisation in Simulation

To decide whether the personal layer of Section III-F is worth building, we replayed waves D-1 and D-2 as if each student had used the app, with two answers a day, and predicted each moment only from earlier answers.

- **Energy:** the AUROC goes from 0.555 with the shared model to 0.666 with the personal layer over the whole study. On days 4 to 7, it is already 0.640 against 0.571.
- **Pleasantness:** from 0.529 to 0.704.

These figures are simulated on EmoPhone students, who were paid to answer about seven times a day. Real users will answer less, so the gain will probably come later. Before writing the Swift code, we will simulate the exact rule of the app to set its parameters, and the pilot will measure the real curve.

### E. How Good Are the Song Scores

To check the language model, we gave it 2,000 MuSe songs with only the title and the artist, and compared its scores with the hidden MuSe scores. Before running the check, we wrote down a rule: for each score, a Spearman correlation of at least 0.4 and a mean error in percentiles below 0.25 (the error of a constant 0.5 is 0.25).

**Table VI - Language Model vs. MuSe on 2,000 Songs**

| **Trial** | **Energy: Spearman / error** | **Positivity: Spearman / error** |
|---|---|---|
| Claude Haiku 4.5, simple prompt | 0.277 / 0.275 | 0.336 / 0.263 |
| Claude Haiku 5.5, prompt describing the scales | 0.279 / 0.273 | 0.324 / 0.266 |
| Claude Haiku 5.5, + 48 reference songs (used in the app) | 0.258 / 0.280 | 0.316 / 0.267 |

No trial passes the rule. Better prompts fixed the scale of the scores (their spread went from 0.13-0.17 to about 0.23, closer to the 0.29 of MuSe) but not the ranking. Part of the problem is MuSe itself: 65% of its songs have three tags or fewer, and the agreement grows with the number of tags, up to 0.39 (energy) and 0.44 (positivity) on songs with 4 to 9 tags, against 0.18 and 0.19 on songs with a single tag. The check therefore measures the noise of MuSe as much as the error of the model.

The team still uses the language model for songs missing from MuSe, because without it almost 90% of a real library would get the neutral score. This is a team decision, not a validated result: in the Library tab, each song shows whether its score comes from MuSe or is estimated, and the skips and "Did it fit?" answers of the pilot will tell whether these queues work.

### F. The App on a Real iPhone

- **Speed.** On an iPhone 16 with a library of 2,459 songs, the queue is on screen 0.28 to 0.37 s after the tap (median 0.34 s over 12 queues; our requirement is under 2 s), plus 0.13 to 0.15 s for the state estimate.
- **Effort.** Music starts two taps after opening the app.
- **When something is missing.** Without recent heart rate, the queue uses the time of day only and Home shows "Watch not synced". Without network or without the Spotify app, the app does not crash and says what happens in one sentence.
- **Tests.** Besides the golden tests of Section III-C, unit tests cover the queue rules (for example, a Wind-down queue never ends more energetic than it starts), data deletion (all tables are empty afterwards) and the forbidden words in the reasons.

### G. The Pilot

*Status: planned, December 7 to 20, 2026. The protocol was written before any data.*

One participant, a team member, uses the app for 14 days with an Apple Watch. Each day is drawn at random as a **body** day (queues start from the state estimate) or a **time-only** day (queues start from the time of day only), in blocks of two days so that the 14 days give 7 of each. We will measure:

- the share of songs skipped before 30 s and the share of "yes" to "Did it fit?", for each kind of day, with 95% intervals by bootstrap over days;
- how often MuSe suggestions are used and skipped;
- how often the watch data are missing (unknown nights, hours without heart rate);
- for the personal layer in shadow mode, the AUROC of the shared and the personal predictions by day of use, on real Apple Watch data.

The phone exports one anonymous file, with no song name, health value or date. With one participant who also built the app, this is a feasibility test, not a proof.

---

## V. Related Work

### A. Existing Studies and Products

- **EmoPhone benchmark** [3]: gives our training data and our evaluation method (features from the minutes before each answer, labels relative to each person, tests on unseen people). Its best models reach an AUROC of about 0.58 for arousal.
- **UC Irvine dataset** [4]: Samsung watch, Oura ring and daily mood of students around the 2020 lockdown; our second test set.
- **WatchAnxiety** [9]: predicts a yes/no anxiety state from smartwatch heart rate with transfer learning, with 60.4% balanced accuracy.
- **GLOBEM** [8]: a multi-year benchmark of student phone and Fitbit data, where deep models (1D-CNN, LSTM, Transformer) did not beat hand-made features and all methods dropped when tested on another year.
- **Context-aware music recommenders** [10]: a systematic review of 100 papers finds that body signals are little studied, partly because suitable datasets are lacking.
- **Iso principle** [7]: a controlled experiment on mood after a sad film clip supports this principle of music therapy, which our queue follows.
- **Endel** [11]: adapts generated soundscapes to heart rate, time and weather. It uses the body, but not the user's own songs.
- **Spotify daylist** [12]: personalises a playlist from the listening history and the time of day. It plays the user's music, but ignores the body.
- **MuSe** [6]: gives our song scores and the reference songs of the prompt.

### B. Tools and Libraries

All our code is on GitHub: <https://github.com/SkaosDev/Harmony>. The data are never in the repository, only the scripts and aggregate results.

| **Tool** | **What we use it for** |
|---|---|
| Python 3.12, pandas, NumPy | Reading EmoPhone, UC Irvine and MuSe, building the 13 inputs |
| scikit-learn 1.5.2 | Logistic regression, gradient-boosted trees, MLP, `GroupKFold`, AUROC and balanced accuracy |
| coremltools 8, Core ML | Converting the model and running it on the iPhone |
| Swift 6, SwiftUI, SwiftData | The iPhone app and its local storage |
| HealthKit | Apple Watch heart rate, steps and sleep (heart-rate variability is only used in the explanation) |
| Spotify Web API, Spotify iOS SDK 5.0.1 | The user's library and playback |
| Cloudflare Workers, Workers KV (TypeScript) | The proxy that holds the LLM key, checks the user and counts requests |
| Anthropic API, Claude Haiku 5.5 | Song scores; the Message Batches API for the offline checks |
| Xcode, XcodeBuildMCP | Building, testing, simulator screenshots |
| GitHub | Code, pull requests reviewed by another member, this blog |
| Claude Code (Anthropic) | AI coding assistant used during development |

---

## VI. Conclusion: Discussion

*This section will be completed after the pilot.*

So far, Harmony shows that a very small model can read something useful from a wrist sensor: with 13 inputs and a logistic regression, it predicts better than the time of day whether a person is more or less activated than usual, on people and on a wave it has never seen. The signal is weak (AUROC 0.56 to 0.58) and it does not transfer to another population, so the app is built to stay useful when the estimate is wrong: the user can always choose the moment and skip any song.

The whole AI part runs on the phone. The model goes from scikit-learn to Core ML with the same probabilities, and golden tests make sure that Swift computes the same inputs as Python. Songs are scored by MuSe when possible and by a language model otherwise, whose agreement with MuSe is weak; we use it knowingly and show the user where each score comes from.

The main lesson so far is that more model capacity or more watch inputs barely help with this kind of data, while the user's own answers do. This is why the final version learns from each person on the phone, with a personal layer and a queue bandit. The open questions for the final version:

- Do queues built from the body fit better than queues built from the clock, on a real Apple Watch user?
- Does the personal layer learn fast enough with about two answers a day?
- Do the estimated song scores give queues that people do not skip?

---

## References

[1] Y. Whan-woo, "Sleep market in Korea reaches W3 tril. says report," *The Korea Times*, Apr. 10, 2024. [Online]. Available: <https://www.koreatimes.co.kr/www/biz/2024/04/126_372435.html>

[2] K. V. Jespersen, V. Pando-Naude, J. Koenig, P. Jennum, and P. Vuust, "Listening to music for insomnia in adults," *Cochrane Database Syst. Rev.*, no. 8, Art. no. CD010459, 2022, doi: 10.1002/14651858.CD010459.pub3.

[3] P. Zhang, M. Park, S. Kang *et al.*, "EmoPhone: A multi-wave dataset for in-the-wild mobile and wearable affect sensing," arXiv:2609.16581, 2026. Data: Harvard Dataverse, doi: 10.7910/DVN/QGRVU8.

[4] S. Labbaf *et al.*, "Physiological and emotional assessment of college students using wearable and mobile devices during the 2020 COVID-19 lockdown: An intensive, longitudinal dataset," *Data in Brief*, vol. 54, Art. no. 110228, 2024, doi: 10.1016/j.dib.2024.110228. Data: Dryad, doi: 10.7280/D1WH6T.

[5] Spotify for Developers, "Introducing some changes to our Web API," Nov. 27, 2024. [Online]. Available: <https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api>

[6] C. Akiki and M. Burghardt, "MuSe: The Musical Sentiment Dataset," *J. Open Humanit. Data*, vol. 7, 2021, doi: 10.5334/johd.33.

[7] K. Starcke, J. Mayr, and R. von Georgi, "Emotion modulation through music after sadness induction—the iso principle in a controlled experimental study," *Int. J. Environ. Res. Public Health*, vol. 18, no. 23, Art. no. 12486, 2021.

[8] X. Xu *et al.*, "GLOBEM dataset: Multi-year datasets for longitudinal human behavior modeling generalization," in *Proc. NeurIPS Datasets and Benchmarks Track*, 2022, arXiv:2211.02733.

[9] M. S. Ahmed *et al.*, "WatchAnxiety: a transfer learning approach for state anxiety prediction from smartwatch data," arXiv:2509.13725, 2025.

[10] Á. Lozano Murciego, D. M. Jiménez-Bravo, A. Valera Román, J. F. De Paz Santana, and M. N. Moreno-García, "Context-aware recommender systems in the music domain: a systematic literature review," *Electronics*, vol. 10, no. 13, Art. no. 1555, 2021.

[11] Endel, "Endel: personalized soundscapes." [Online]. Available: <https://endel.io/> (accessed Oct. 20, 2026).

[12] "Spotify launches ever-changing 'Daylist' playlist that adapts to users' moods," *Music Business Worldwide*, 2023. [Online]. Available: <https://musicbusinessworldwide.com/spotify-launches-ever-changing-daylist-playlist-that-adapts-to-users-moods>

[13] Spotify for Developers, "Web API changes, February 2026" and "February 2026 dev mode changes: migration guide." [Online]. Available: <https://developer.spotify.com/documentation/web-api/references/changes/february-2026> (accessed Nov. 4, 2026).

---

## Progress Log

- **October 29, 2026.** Full access to the EmoPhone dataset granted by its authors.
- **November 10.** The three EmoPhone waves explored; on each wave, time + heart rate beats the time of day.
- **Mid-November.** Spotify sign-in, library import and Apple Watch reading work on a real iPhone; demo mode with synthetic data.
- **November 20.** Final 13 inputs, cross-validation on D-1 + D-2, single test on D-3; model trained on the three waves and converted to Core ML.
- **November 22.** UC Irvine tested: the EmoPhone model is kept. The model runs in the app, and the golden tests pass on the iPhone.
- **November 23.** Song scores (MuSe, then Claude Haiku 5.5 through the Cloudflare Worker), queue, player and all screens working on an iPhone 16. Personal layer and queue bandit designed and simulated. Pilot protocol written.
- **Next.** Build the personal layer for the pilot (December 7 to 20), then the final demo, presentation and video.
