---
layout: default
title: "Harmony: Context-Aware Music Companion Using Wearable Health Data"
---

> **Course:** ITE 351 - AI & Applications, Hanyang University  
> **Track:** Option B - Prototype service using AIML techniques  
> **Date:** November 2026

---

## Group Members

- **Clément Royer**, Dept. of Computer Science, Hanyang University, clement.royer@edu.devinci.fr
- **Cyprien Vanden Abeele**, Dept. of Computer Science, Hanyang University, cyprien.vanden_abeele@edu.devinci.fr
- **Lucas Miskulin**, Dept. of Computer Science, Hanyang University, lucas.miskulin@edu.ece.fr
- **Riad Mekideche**, Dept. of Computer Science, Hanyang University, riad.mekideche@edu.devinci.fr

---

## Table of Contents

- [I. Introduction](#i-introduction)
  - [A. Motivation](#a-motivation)
  - [B. What We Want to See at the End](#b-what-we-want-to-see-at-the-end)
- [II. Datasets](#ii-datasets)
  - [A. EmoPhone: Mood and Wearable Data](#a-emophone-mood-and-wearable-data)
  - [B. MuSe: Song Scores](#b-muse-song-scores)
- [III. Methodology](#iii-methodology)
  - [A. Step 1: Machine Learning on Watch Data](#a-step-1-machine-learning-on-watch-data)
  - [B. Step 2: Deep Learning on Heart-Rate Series](#b-step-2-deep-learning-on-heart-rate-series)
  - [C. Step 3: Song Recommendation](#c-step-3-song-recommendation)
- [IV. Evaluation & Analysis](#iv-evaluation--analysis)
  - [A. Results on the Three Waves](#a-results-on-the-three-waves)
  - [B. Analysis](#b-analysis)
  - [C. Next Steps](#c-next-steps)
- [V. Related Work](#v-related-work)
  - [A. Existing Studies and Products](#a-existing-studies-and-products)
  - [B. Tools and Libraries](#b-tools-and-libraries)
- [VI. Conclusion: Discussion](#vi-conclusion-discussion)
- [References](#references)
- [Progress Log](#progress-log)

---

## I. Introduction

Harmony is a music app that estimates, from smartwatch data and the time of day, whether the user is more or less activated than usual. It then plays a short queue of songs from the user's own Spotify library that fits the moment: waking up, stress, an afternoon energy dip or falling asleep.

### A. Motivation

Poor sleep and stress are an everyday problem in Korea. A report based on a KB Financial Group study gives an average sleep time of 471 minutes per day, 30 minutes below the OECD average. In a Philips survey cited by the same report, only 41% of Koreans were satisfied with their sleep, and stress was the first cause of disturbed sleep [1].

Music can help. A Cochrane review of 13 randomised trials (1,007 adults) found that listening to music improved sleep quality [2]. This is evidence about music in general: it does not show that our app will improve well-being, and we do not claim it.

Yet music apps ignore the body of the listener. A smartwatch measures heart rate, steps and sleep all day, but streaming platforms choose songs from the listening history and the time of day only. Our users are students and young workers who wear a smartwatch and listen to music on their phone. They want the music they already like, at the right moment, with one tap. We belong to this group ourselves.

For an AI course, the project raises a clear question: can wearable data tell how a person feels in daily life? Mood answers given on a phone are noisy, and published results are modest [3], [4]. We want to measure how far simple models go, whether deep learning does better, and whether a recommender can learn from a few skips and likes.

### B. What We Want to See at the End

1. **A state model** that predicts, from the watch data and the time of day, whether a person is more or less activated than usual. It is tested on people it has never seen, and it must answer one question: does it beat a model that only knows the time of day?
2. **A comparison** of classic machine learning and deep learning on the same task, with SHAP to see which signals drive the predictions.
3. **A working prototype**: an iPhone app that runs the model on the phone, builds a short queue from the user's Spotify library and improves its choices from skips and likes.

The app is a wellness demonstrator for a few users, not a medical tool. It never shows a named emotion to the user, only a calmer or a more energetic queue.

---

## II. Datasets

### A. EmoPhone: Mood and Wearable Data

We train and test the state model on **EmoPhone** [3], a dataset from KAIST shared on Harvard Dataverse. After emailing the dataset owner, we were granted access to the complete data for this project. The authors allow us to use it but not to share it, so the files stay on our computers: this blog only shows our method and aggregate results.

EmoPhone has three waves (D-1, D-2 and D-3). In each wave, students of a Korean university used an Android phone and wore a **Fitbit Inspire HR** for about four weeks. About seven times a day, the phone asked them short questions about their mood. Table I gives the size of each wave.

**Table I - EmoPhone Waves**

| **Wave** | **Period of the answers** | **Participants** | **Mood answers** |
|---|---|---|---|
| D-1 | Feb. 8 - Apr. 2, 2020 | 92 | 10,259 |
| D-2 | Dec. 7, 2020 - Jan. 27, 2021 | 99 | 21,042 |
| D-3 | Nov. 24, 2021 - Jan. 11, 2022 | 106 | 21,838 |
| **Total** | | **297** | **53,139** |

**What we use.**

- **Heart rate** from the Fitbit, about one reading every 5 seconds.
- **Steps** per minute.
- From each mood answer: the participant code, the time of the answer, the **arousal** (how calm or activated the person feels, from -3 to +3) and the **stress**.

**What we leave out.** EmoPhone also contains phone sensors (such as location, proximity or key events) and questionnaires about each participant. We do not use them: our app will only read the watch and the clock, so the model must work with the same inputs. The locations are also anonymised, so the weather cannot be matched to each participant.

**Cleaning.**

- Timestamps are in UTC milliseconds. We convert them to Korean time (UTC+9), because the time of day is a model input.
- EmoPhone has **no measured sleep** and no heart-rate variability. We estimate sleep from the heart rate and the steps (Section III-A). A night without enough data is marked **unknown**, never as zero sleep.
- Valence and arousal use the same -3 to +3 scale in the three waves. D-3 asks stress on 0 to +6 instead; since our labels compare each answer with the person's own average, this shift does not change them.
- Some people have sensor files but no mood answer (10 in D-1, 13 in D-2). They are left out.
- Participant codes are numbered per wave, and the documentation does not say whether the same students came back. When we combine waves, each wave and code is treated as a different person.

**Label.** For each answer, the label is 1 when the arousal is above the person's own average, and 0 otherwise. People use the scale differently: a "+1" can be high for one student and normal for another, so a label relative to each person is fairer. It is also exactly what the app needs: "more or less activated than usual".

### B. MuSe: Song Scores

Spotify removed the audio features (valence, energy) from its Web API for new apps in November 2024 [5], so we cannot get a mood score for each song from Spotify. We use **MuSe** [6] instead, a public dataset (CC BY 4.0) in which each song has a valence, an arousal and a dominance score computed from the Last.fm tags given by listeners.

We use version 3, published by the authors on Kaggle: 90,001 songs, 68.5% of them with a Spotify ID and 92.6% with a genre. The scores of a single song are rough: the median song has only 2 emotion tags, and 28.6% of the songs have only one.

- **Scale.** The raw scores are packed in a small range: with a min-max scaling, 63% of the songs would fall between 0.45 and 0.75. We use percentile ranks instead. The **energy** comes from the arousal and the **positivity** from the valence: an energy of 0.2 means "calmer than 80% of MuSe songs".
- **Duplicates.** 889 Spotify IDs are shared by 1,863 rows, often by different songs, so we remove these IDs. We also keep one row per normalised title and artist, the one with the most tags.
- **Result.** 89,269 songs remain, 59,679 of them with a Spotify ID.

---

## III. Methodology

We work in three steps, as planned in the proposal. Step 1 has started, step 2 is planned and step 3 is in progress.

### A. Step 1: Machine Learning on Watch Data

*Status: first version done on the three waves.*

**Features.** For each mood answer, we compute 14 features from the data recorded before the answer (Table II). Each signal is compared with the person's own average (a z-score), so the model does not need to learn each user. A heart-rate mean is kept only when there are enough readings (5 in 15 minutes, 10 in 30 minutes). Missing values are replaced by the median of the training data.

**Table II - Features of the First Version**

| **Group** | **Feature** | **How it is computed** |
|---|---|---|
| Time | hour (sine, cosine) | time of day on a circle, so 23:00 is close to 01:00 |
| Time | weekend | 1 on Saturday and Sunday |
| Heart rate | mean over 15, 30, 60 min | mean heart rate before the answer, z-score per person |
| Heart rate | spread over 30 min | standard deviation, z-score per person |
| Heart rate | mean over 30 min vs. same time of day | compared with the person's mean in the same 3-hour block, since heart rate depends on the time of day |
| Steps | steps over 15, 30, 60 min | log(1 + steps), z-score; watch worn without steps = 0, watch not worn = unknown |
| Sleep | last night's sleep | minutes of sleep, z-score |
| Sleep | hours since waking up | unknown if the answer comes before waking up |
| Sleep | sleep unknown | 1 when last night is unknown |

**Sleep estimate.** EmoPhone has no sleep data, so we estimate it the way watches do. A minute counts as asleep when the watch is worn (heart rate present), there are no steps and the heart rate is close to the person's lowest values (at most 1.05 times their 30th percentile). The night is the longest such period between 21:00 and 12:00, with gaps of up to 30 minutes merged, and it must last at least 2 hours. If the heart rate covers less than 60% of this window, the watch was not worn and the night is **unknown**. On D-1, the median night is 7.3 hours.

**Models.** Our main model is a **logistic regression** (scikit-learn, after standardisation). It is fast, easy to explain and small enough to run on an iPhone with Core ML. We compare it with **gradient-boosted trees** (scikit-learn `HistGradientBoostingClassifier`, 200 iterations, learning rate 0.05). As planned in the proposal, we will add a **random forest** and **LightGBM**, and use **SHAP** to see which features drive the predictions.

**Baselines.** Two baselines tell us whether the model learns something useful:

- **Time of day only:** a logistic regression on the three time features. If our model does not beat it, the app will use the time of day only.
- **Other participants at the same moment:** for each answer, the share of "more activated than usual" answers among the training participants at the same date and 3-hour block. It measures how much shared effects, such as the weather, could bring.

**Evaluation protocol.** The model is always tested on people it has never seen: we use a 5-fold `GroupKFold` grouped by participant. A random split would put answers of the same person in both training and test, and give results that are too optimistic. We report the **AUROC** (0.5 = chance, 1 = perfect) and the **balanced accuracy**, as the EmoPhone benchmark does. We will add the F1-score planned in the proposal for the final comparison.

**Limit of this first version.** Each person's average is computed over the whole four weeks, which uses future data and is slightly optimistic. The next version will only use the 14 days before each answer, as the app will.

### B. Step 2: Deep Learning on Heart-Rate Series

*Status: planned.*

Instead of hand-made features, a **1D-CNN** and an **LSTM** (PyTorch) will read the heart-rate and step series before each answer, and we will try to personalise them for each user. They will use the same folds as step 1, so the results can be compared directly.

The Apple Watch measures heart rate far less often than the Fitbit: on our own watch, we measured a median of 4 to 5 minutes between two readings. We plan to resample the series to one reading every 5 minutes, so that a model trained on EmoPhone can run on Apple Watch data.

### C. Step 3: Song Recommendation

*Status: MuSe table built; LLM scores, queue and bandit planned.*

**Song scores.** Each song of the user's Spotify library gets an energy and a positivity score between 0 and 1 from MuSe, matched by Spotify ID, then by normalised title and artist. For songs not in MuSe, a large language model (LLM) estimates the two scores from the title and artist only. We will check these estimates on songs that are in MuSe.

**Queue.** The predicted state is linked to the song scores with the **iso principle** of music therapy [7]: the first songs match the current state, then each song moves one step toward the goal of the moment, calmer for falling asleep or more energetic for waking up. A queue has 3 to 5 songs.

**Learning from feedback.** As planned in the proposal, a **contextual bandit** (reinforcement learning) will improve the choices with the user's feedback. The context is the moment and the predicted state, and the reward comes from likes and skips.

**On the phone.** The trained model is converted with coremltools and runs on the iPhone with Core ML, so health data never leave the phone. Only song titles and artists are sent to the LLM.

---

## IV. Evaluation & Analysis

### A. Results on the Three Waves

We ran step 1 on each wave separately, with people kept apart. In Table III, each cell gives the mean AUROC over the 5 folds, its standard deviation between folds, and the balanced accuracy. 0.5 is chance.

**Table III - Results of Step 1 on Each EmoPhone Wave (people kept apart)**

| **Target and inputs** | **D-1** | **D-2** | **D-3** |
|---|---|---|---|
| Mood answers / participants | 10,259 / 92 | 21,042 / 99 | 21,838 / 106 |
| Answers with last night's sleep estimated | 66% | 41% | 78% |
| Arousal: time of day only | 0.530 ± 0.013 / 0.509 | 0.538 ± 0.016 / 0.509 | 0.542 ± 0.007 / 0.500 |
| Arousal: time + sleep | 0.524 ± 0.016 / 0.506 | 0.552 ± 0.026 / 0.531 | 0.540 ± 0.010 / 0.503 |
| Arousal: time + heart rate | 0.576 ± 0.009 / 0.544 | 0.570 ± 0.014 / 0.526 | 0.593 ± 0.009 / 0.547 |
| Arousal: time + heart rate + steps | 0.576 ± 0.008 / 0.544 | 0.571 ± 0.013 / 0.529 | 0.599 ± 0.012 / 0.553 |
| **Arousal: time + heart rate + steps + sleep (our model)** | **0.572 ± 0.005 / 0.544** | **0.576 ± 0.017 / 0.544** | **0.598 ± 0.011 / 0.551** |
| Arousal: same, gradient-boosted trees | 0.558 ± 0.008 / 0.537 | 0.566 ± 0.024 / 0.538 | 0.589 ± 0.012 / 0.552 |
| Arousal: time + heart rate, one reading every 5 min | 0.575 ± 0.008 / 0.546 | 0.567 ± 0.014 / 0.523 | 0.591 ± 0.010 / 0.544 |
| Stress: our model | 0.546 ± 0.018 / 0.516 | 0.530 ± 0.027 / 0.512 | 0.558 ± 0.010 / 0.529 |
| Arousal: other participants at the same moment | 0.521 ± 0.012 / - | 0.519 ± 0.012 / - | 0.539 ± 0.021 / - |

### B. Analysis

- **The model beats the time of day on all three waves:** 0.572 against 0.530 on D-1, 0.576 against 0.538 on D-2 and 0.598 against 0.542 on D-3. The gain is small, but larger than the variation between folds.
- **Heart rate carries most of the information.** Adding it to the time of day raises the AUROC by 0.03 to 0.05. Steps and sleep add no measurable gain: the changes stay within the variation between folds. We keep them because the Apple Watch measures sleep itself, whereas EmoPhone sleep had to be estimated, and because the queue rules use them.
- **Gradient-boosted trees do slightly worse than logistic regression** on all three waves (by about 0.01). With 14 features and noisy labels, a simple linear model is enough for now; the random forest and LightGBM will tell whether this holds.
- **One heart-rate reading every 5 minutes gives almost the same result.** This matters because the Apple Watch measures much less often than the Fitbit.
- **Stress is barely predictable** (0.53 to 0.56). In the app, the user chooses the stress situation; the model never triggers it.
- **Shared effects carry little information.** The mood of the other participants at the same moment, which includes shared effects such as the weather, gives only 0.52 to 0.54.
- **These results are modest, but in line with the literature.** On people not seen in training, the best EmoPhone models reach an AUROC of about 0.58 for arousal with thousands of phone and watch features [3]. Our model reaches a similar level with 14 inputs that an Apple Watch can provide. WatchAnxiety [4] reports 60.4% balanced accuracy for anxiety from smartwatch heart rate, another sign that realistic results are modest.

### C. Next Steps

- Train on D-1 and D-2, then test once on D-3, a wave the model has never seen.
- Compute personal averages from the 14 previous days only (Section III-A).
- Add the F1-score, the random forest, LightGBM and SHAP.
- Train the 1D-CNN and the LSTM of step 2 on the same folds.

---

## V. Related Work

### A. Existing Studies and Products

- **EmoPhone benchmark** [3]: gives our training data and our evaluation method: features from the minutes before each mood answer, normalisation per person, labels relative to each person's average, and tests on unseen people. Its best models reach an AUROC of about 0.58 for arousal.
- **WatchAnxiety** [4]: predicts a yes/no anxiety state from smartwatch heart rate with transfer learning, and reports 60.4% balanced accuracy.
- **Context-aware music recommenders** [8]: a systematic review of 100 papers finds that body signals are little studied, partly because suitable datasets are lacking.
- **Iso principle** [7]: a controlled experiment on mood after a sad film clip supports this principle of music therapy: start with music that matches the current mood, then move step by step toward the target. Our queue follows it.
- **Endel** [9]: adapts generated soundscapes to heart rate, time and weather. It uses the body, but not the user's own songs.
- **Spotify daylist** [10]: personalises a playlist from the listening history and the time of day. It plays the user's music, but ignores the body.
- **MuSe** [6]: gives our song scores (Section II-B).

### B. Tools and Libraries

All our code is on GitHub: <https://github.com/SkaosDev/Harmony>. The script `ml/explore_d1.py` reproduces the results of Section IV.

| **Tool** | **What we use it for** |
|---|---|
| Python 3.12, pandas, NumPy | Reading EmoPhone and MuSe, building the features |
| scikit-learn 1.5.2 | Logistic regression, gradient-boosted trees, `GroupKFold`, AUROC and balanced accuracy |
| LightGBM, PyTorch, SHAP | Planned: step 1 comparison, step 2 deep learning, explanations |
| coremltools 8, Core ML | Converting the model and running it on the iPhone |
| Swift, SwiftUI, HealthKit | The iPhone app and the Apple Watch data |
| Spotify Web API, iOS SDK | The user's library and playback |
| GitHub | Code, reviews and this blog |
| Claude (Anthropic) | AI assistant to help with development |

---

## VI. Conclusion: Discussion

*This section will be completed at the end of the project.*

So far, a simple model with 14 watch and time features predicts, better than chance and better than the time of day alone, whether a person is more or less activated than usual. The signal is weak (AUROC 0.57 to 0.60), so the app must stay useful when the estimate is wrong: the user can always choose the moment with one tap and skip any song. Three questions remain open:

- Does deep learning on the raw heart-rate series do better than 14 hand-made features?
- Does a model trained on Fitbit data work on Apple Watch data?
- Can a contextual bandit learn from the few skips and likes of one user?

---

## References

[1] Y. Whan-woo, "Sleep market in Korea reaches W3 tril. says report," *The Korea Times*, Apr. 10, 2024. [Online]. Available: <https://www.koreatimes.co.kr/www/biz/2024/04/126_372435.html>

[2] K. V. Jespersen, V. Pando-Naude, J. Koenig, P. Jennum, and P. Vuust, "Listening to music for insomnia in adults," *Cochrane Database Syst. Rev.*, no. 8, Art. no. CD010459, 2022, doi: 10.1002/14651858.CD010459.pub3.

[3] P. Zhang, M. Park, S. Kang *et al.*, "EmoPhone: A multi-wave dataset for in-the-wild mobile and wearable affect sensing," arXiv:2609.16581, 2026. Data: Harvard Dataverse, doi: 10.7910/DVN/QGRVU8.

[4] M. S. Ahmed *et al.*, "WatchAnxiety: a transfer learning approach for state anxiety prediction from smartwatch data," arXiv:2509.13725, 2025.

[5] Spotify for Developers, "Introducing some changes to our Web API," Nov. 27, 2024. [Online]. Available: <https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api>

[6] C. Akiki and M. Burghardt, "MuSe: The Musical Sentiment Dataset," *J. Open Humanit. Data*, vol. 7, 2021, doi: 10.5334/johd.33.

[7] K. Starcke, J. Mayr, and R. von Georgi, "Emotion modulation through music after sadness induction—the iso principle in a controlled experimental study," *Int. J. Environ. Res. Public Health*, vol. 18, no. 23, Art. no. 12486, 2021.

[8] Á. Lozano Murciego, D. M. Jiménez-Bravo, A. Valera Román, J. F. De Paz Santana, and M. N. Moreno-García, "Context-aware recommender systems in the music domain: a systematic literature review," *Electronics*, vol. 10, no. 13, Art. no. 1555, 2021.

[9] Endel, "Endel: personalized soundscapes." [Online]. Available: <https://endel.io/> (accessed Oct. 20, 2026).

[10] "Spotify launches ever-changing 'Daylist' playlist that adapts to users' moods," *Music Business Worldwide*, 2023. [Online]. Available: <https://musicbusinessworldwide.com/spotify-launches-ever-changing-daylist-playlist-that-adapts-to-users-moods>

---

## Progress Log

### October 29, 2026: Full access to the EmoPhone dataset

After emailing the dataset owner, we were granted access to the complete EmoPhone dataset. We can now start exploring the data.
