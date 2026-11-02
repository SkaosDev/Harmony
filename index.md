---
layout: page
title: "ITE 351: AI & Applications, Project Proposal"
---

> **Course:** ITE 351 - AI & Applications, Hanyang University  
> **Track:** Option B - Prototype service using AIML techniques  
> **Date:** November 2026

---

## Group Members

- **Clément Royer**, Dept. of Computer Science, Hanyang University - clement.royer@edu.devinci.fr
- **Cyprien Vanden Abeele**, Dept. of Computer Science, Hanyang University - cyprien.vanden_abeele@edu.devinci.fr
- **Lucas Miskulin**, Dept. of Computer Science, Hanyang University - lucas.miskulin@edu.ece.fr
- **Riad Mekideche**, Dept. of Computer Science, Hanyang University - riad.mekideche@edu.devinci.fr

---

## Research Idea

### Title

**Harmony: Context-Aware Music Companion Using Wearable Health Data**

### Proposal

Harmony is a music app that guesses how the user feels from their smartwatch data and daily context, and then suggests songs that match this mood.

We will use the EmoPhone dataset (KAIST, Harvard Dataverse). It contains real-world data from wearables (heart rate, steps), smartphone context and thousands of emotion labels (valence and arousal) reported by the participants.

We plan to work in three steps:

1. Machine learning: we explore and clean the data, build features over time windows and compare logistic regression, random forest and gradient boosting (scikit-learn, LightGBM).
2. Deep learning: we train 1D-CNN and LSTM models (PyTorch) directly on the heart rate time series and try to personalize them for each user.
3. Recommendation: the predicted mood is linked to song features, and a contextual bandit (reinforcement learning) improves the suggestions using user feedback like skips and likes.

We will compare the models with the F1-score and use SHAP to understand their predictions.

---

## Progress Log

### October 29, 2026: Full access to the EmoPhone dataset

After emailing the dataset owner, we were granted access to the complete EmoPhone dataset. We can now start exploring the data.
