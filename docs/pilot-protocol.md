# Harmony pilot — protocol and consent (TODO 4.1)

> Written on 23 Nov 2026 and revised on 24 Nov 2026 (one week, watch data every day), both
> **before any pilot data exist**. The analysis plan (section 7) is fixed here and is not changed
> after looking at the data. The check-ins (state model v2, TODO 6.14: section 10 and the check-in
> parts of sections 4, 5, 7, 8 and 9) were added on 26 Nov 2026, pilot day 1, before any export:
> no pilot data had been exported or looked at.

## 1. Purpose

A feasibility test of Harmony in daily life, with the Apple Watch data used **every day**: every
queue starts from the state estimated from the watch (heart rate, steps, sleep) and the time of day
(current model, `docs/PROJECT.md` §6). When the watch gives no recent heart rate, the app falls
back to the time of day, as it always does.

Questions: does the app work every day without help (crashes, playback, data coverage)? How often
are songs skipped, and how often does a queue "fit", **for this participant**?

This is **not** a proof of anything general: one participant, one week, no comparison queue.

## 2. Participant

- **One participant: Clément Royer**, a member of the team (team decision, 23 Nov 2026,
  `docs/PROJECT.md` §3). This stays within the 5 accounts allowed by Spotify development mode.
- The participant is also a developer of the app and knows how queues are built, so expectation
  effects are possible; they are reported as a limit.

## 3. Duration and equipment

- **7 days, from Thursday 26 Nov to Wednesday 2 Dec 2026** (pilot day 1 = 26 Nov). One week only,
  because the project ends on 4 Dec 2026: the results must be in the report and the demo by then.
- iPhone 16 of the participant with a **Debug build** of Harmony installed from Xcode (the pilot
  controls live in the Debug screen), his own Spotify Premium account, his Apple Watch.

## 4. Before day 1

- [ ] Build from `main` installed; `Config.xcconfig` filled; Spotify connected; library imported
      and scored.
- [ ] The build includes TODO 4.4: every pilot day uses the watch data.
- [ ] Apple Watch worn for at least 7 days before day 1 (the personal reference is ready at 7 days).
- [ ] Spotify connected with the playlist scopes of 23 Nov. (`docs/PROJECT.md` §9): after a queue,
      the Spotify library holds a single "Harmony" playlist.
- [ ] Demo mode **off** (Settings › Debug).
- [ ] On day 1: Settings › Debug › Pilot › **Pilot running** switched on. This saves the start day.
- [ ] Questions switched on (Settings › Questions) and notifications allowed; test answers removed
      with Settings › Questions › **Reset what Harmony learned**, so that day of use 1 is the day of
      the first real answer (section 10).
- [ ] Consent form (section 9) signed, check-in items included.

## 5. Daily procedure

- Wear the watch day and night as usual (night data give the sleep features).
- Use Harmony when a situation happens (wake-up, stress, low energy, wind-down), as a normal user
  would. **No minimum number of queues**: the pilot measures real use. As a guide, about two queues
  a day give about 14 queues in one week.
- Skip, like or remove songs freely. Answer "Did it fit?" at the end of a queue when possible
  ("Skip" is allowed and is counted as "no answer").
- Answer the question "Quick check: energy right now?" when it comes and when convenient, from the
  lock screen or the watch (section 10). "Not now" or no answer is fine: it counts as no
  information, never as "Low".
- Do not switch the pilot off, do not change the date, do not use demo mode during the pilot.
- Note problems (crash, playback failure, wrong data, anything surprising) in a short dated list
  outside the app; they are used at the mid-pilot point.

## 6. Watch data every day

- Every pilot day uses the state estimated from the watch and the time of day (current model).
- If the watch gives no recent heart rate, the app falls back to the time of day, as it always
  does; each queue records the mode it really used (`QueueRecord.stateMode`).
- A day is a calendar day on the phone (midnight to midnight).

## 7. Data and analysis plan (fixed before the data)

### 7.1 What stays on the phone
Everything Harmony already stores (library, song scores, hourly and nightly watch summaries,
queues, feedback, consents), and the check-ins and question log of section 10. Nothing new leaves
the phone during the pilot.

### 7.2 What is exported (TODO 4.5), once, at the end
Settings › Debug › Pilot › **Export pilot data** writes one JSON file (format `harmony-pilot-2`),
which the participant copies to `data/pilot/` on a team computer (ignored by Git, never committed,
never pasted into a chat). It contains only:

- for each queue started since day 1: pilot day, hour of day, situation, mode really used (state
  estimate, or time of day when the watch gave no recent heart rate), and for each song its position, score origin (MuSe, language model, neutral) and whether it
  was a MuSe suggestion; the skip / like / finish events with their position and seconds played;
  the "Did it fit?" answer; the queue strategy (always S1 in shadow mode, decision D4; chosen by
  the bandit after the amendment of section 10.6) and, from that amendment, where the queue's start
  point came from (`e0Source`: rank, raw or personal);
- watch coverage counts: pilot days, nights with known sleep, hours elapsed, hours with at least one
  heart rate;
- for each answer to the check-in question since day 1 (section 10, decision D5): its day of use,
  whether it was above the participant's usual ("label", absent with fewer than 5 earlier
  answers), and the two probabilities the phone computed **just before** the answer was added: the
  common model's (`pCommonBefore`) and the personal layer's (`pPersonalBefore`);
- counts of the questions sent since day 1: answered, "Not now", ignored, still waiting.

It never contains: Spotify IDs, song titles or artists, account IDs, the queue reason, the
estimated state or song targets of a queue, the check-in answers themselves (Low / Medium / High)
or their times, the model logits, heart rate, step or sleep values, or absolute dates.

### 7.3 Measures (script `ml/pilot_analysis.py`)
- **Primary (TODO 4.7)**, over the week:
  - **skip rate** = songs skipped before 30 s / (skipped + finished songs). A song left between
    30 s and its end gives no event and is not counted (rule of `PlaybackTracker`);
  - **fit rate** = "yes" / ("yes" + "no") among answered queues, with the answer rate beside it.
- **MuSe fallback (TODO 4.8)**: share of queues with at least one MuSe suggestion, share of songs
  that are suggestions, skip rate of suggestions vs library songs.
- **Watch coverage (TODO 4.9)**: share of nights with known sleep, share of hours with a heart rate,
  share of queues that fell back to the time of day.
- **Check-ins (TODO 6.15, analysis WP-P of the design v2 §7)**:
  - **answer rate** = answered / (answered + "Not now" + ignored) among the questions sent since
    day 1, with the "Not now" and ignored shares beside it; questions still waiting at the export
    are counted apart. Answers in the week, and answers with a label;
  - **chronological AUROC** (decision D8): on the answers with a label and both probabilities,
    AUROC of `pCommonBefore` and of `pPersonalBefore` against the label, and their difference
    (personal − common), for days of use **1–3**, **4–7** and **the whole week** (bins fixed here).
    Each answer is predicted from the earlier answers only, by construction on the phone. A bin
    with a single label value gets no AUROC ("–");
  - **reward by strategy**: mean reward of the queues of each strategy (S1 only during the pilot),
    with the rule of the app (`QueueBandit.reward`, design v2 §4.6): "Did it fit?" yes 1, no 0;
    without an answer, 1 − share of skips among skipped or finished songs; +0.2 per like, at most
    1; a queue with neither gives no reward. This is the point of comparison for the strategy
    choice after the course.

### 7.4 Uncertainty and reading
- With one participant, the unit of resampling is the **day**: 95 % intervals of the skip and fit
  rates by bootstrap over the 7 days (2 000 resamples, percentiles 2.5 and 97.5, fixed seed).
- The AUROCs and their difference get the same kind of interval, by bootstrap over the **days of
  use** (same resamples for the two probabilities and their difference); the mean reward, over the
  pilot days. With two questions a day there are at most 14 answers and, after the first 5 that
  only build the usual, at most about 9 with a label: the intervals will be very wide. The AUROCs
  show that the chronological logging works end to end on a real Apple Watch user; they are not
  evidence that the personal layer helps. Expected from the simulation (not a criterion,
  `docs/PROJECT.md` §6.8, three answer levels, two a day): days 4–7, 0.534 common vs 0.736
  personal.
- The rates are reported as they are, **for this participant only**. With no comparison queue,
  they describe how the app does in daily life; they do not show that the watch data help.
- No product decision is taken from this pilot alone; the team discusses the results before the
  final report.
- Only aggregates go to Git, `docs/PROJECT.md` and the report.

## 8. Mid-pilot point (TODO 4.6), day 4 (Sunday 29 Nov)

Short notes (in `docs/PROJECT.md` §12 or the meeting notes), without looking at the skip or fit
rates (that would break section 7):
- crashes and bugs seen, playback failures, "Can't play this" screens;
- days with no queue, and why;
- watch worn at night? (count of nights with known sleep in Settings › Debug › Apple Health);
- questions: do they arrive, on the lock screen and the watch? Counts only (Settings › Debug ›
  Personal layer: check-ins, answered / not now / ignored), not the probabilities or `b_E`;
- what felt wrong or tiring;
- decision: continue unchanged, or fix a blocking bug (a fix is noted with its date).

## 9. Consent (simple written form)

> **Harmony pilot — consent**
>
> I take part in the Harmony pilot from 26 Nov to 2 Dec 2026 (CSE 406, Hanyang University,
> group G02). I understand that:
> 1. Harmony reads my Apple Watch heart rate, steps and sleep, and my Spotify library, and keeps
>    them **on my iPhone only**. Only song titles and artists are sent to the team's server to
>    score songs, as in normal use.
> 2. Harmony is not a medical device; it gives no health advice.
> 3. Every day, Harmony uses my watch data and the time of day to build my queues (the time of
>    day only when the watch has no recent data).
> 4. At the end, I export one file with the counts described in section 7.2 of the protocol (no
>    song names, no heart rate, step or sleep values, no answers, no dates). I can read it before
>    giving it to the team. Only aggregate results are published, in the course report.
> 5. I can stop at any time without giving a reason, and delete all my data in Settings › My data
>    › Delete everything. If I stop, my exported data are not used unless I say so.
> 6. Harmony asks me "Quick check: energy right now?" at most twice a day, by notification. The
>    questions are optional: I can answer "Not now", ignore them, or switch them off in
>    Settings › Questions. My answers are treated as health data: they stay on my iPhone, are
>    deleted after 30 days, and I can delete them with "Reset what Harmony learned". During the
>    pilot they do not change my queues.
>
>    *Item 6 as revised by the amendment of section 10.6 (26 Nov 2026):* Harmony asks me "Quick
>    check: energy right now?" by notification, at most twice a day, and during the pilot, from the
>    evening of 26 Nov, up to four times a day. The questions are optional: I can answer "Not now",
>    ignore them, or switch them off in Settings › Questions. My answers are treated as health data:
>    they stay on my iPhone, are deleted after 30 days, and I can delete them with "Reset what
>    Harmony learned". From the evening of 26 Nov, my answers, skips and likes change my queues:
>    Harmony learns from them on my iPhone.
> 7. For each answer, the exported file holds only its day of use, whether it was above my usual,
>    and the two estimates the app computed just before it (from the shared model, and adjusted to
>    my earlier answers), plus how many questions I answered, declined or ignored. It never holds
>    the answer itself or its time.
>
> Name: ____________________  Date: ____________  Signature: ____________________

## 10. Check-ins (state model v2, TODO 6.14)

Written on 26 Nov 2026, pilot day 1, before any export. The pilot build includes the check-ins in
**shadow mode** (decision D4, `docs/PROJECT.md` §3; design v2 §15, "collection only"); the
questions were switched on and the test answers reset on 26 Nov (TODO 6.10).

### 10.1 The questions
- One question, energy only: the notification "Quick check: energy right now?" with four actions in
  this order: **Not now** · Low · Medium · High (stored as −2 / 0 / +2). It is answered from the lock
  screen or the Apple Watch, without opening the app.
- At most two a day, at a random time in each of two windows (default 10:00–13:00 and 15:00–19:00,
  settable within 07:00–22:00 in Settings › Questions), at least 2 h apart, none in the 80 min after
  a queue starts; planned 3 days ahead. A question left 2 h without an answer counts as ignored.
- Neutral text, no health value, no reminder, no streak. "Not now" and ignored questions are no
  information, never "Low".
- Shadow mode: the energy row on Home and the check-in sheet appear in active mode only, so during
  the pilot the questions come only by notification. The personal layer is computed and logged but
  does not change the queues; every queue uses strategy S1 (probability 1), as in section 6.

### 10.2 What is logged on the phone
- `CheckIn`, one per answer: time, channel, answer, the common model's logit and mode at that time,
  the label "above the usual" (answer above the mean of the participant's answers of the 14 days
  before, at least 5 of them; fixed at the answer), whether it is used for learning (not during a
  queue or in the 60 min after it), `pCommonBefore` and `pPersonalBefore` computed before the answer
  is added, and the day of use (day 1 = day of the first answer). An answer given on the lock
  screen gets its logit and probabilities at the next opening of the app, computed for the time of
  the answer.
- `PromptLog`, one per question: planned time, time shown, outcome (answered, Not now, ignored).
- Both are deleted after 30 days, by "Reset what Harmony learned" and by "Delete everything".

### 10.3 What is exported and analysed
Section 7.2 (pairs and counts, decision D5) and sections 7.3–7.4 (answer rate, chronological AUROC
by days of use, reward by strategy), with `ml/pilot_analysis.py`. The export needs the build with
format `harmony-pilot-2` (TODO 4.5). **Installed on 26 Nov 2026 (day 1, 12:19)** over the app
(branch `phase6/pilote`): only the export changed, the data stayed in place and the app opened on
them.

### 10.4 Ethics review
- Question to the teacher: is an ethics review needed for this pilot (one participant who is a
  team member, one week, optional one-tap energy questions, everything kept on the phone, only the
  aggregates and pairs of section 7.2 leave it, with written consent)?
- Answer, reported by the participant on 26 Nov 2026: **no ethics review needed**; the pilot runs
  as described here.

### 10.5 Consent
The revised consent of section 9 (items 1–7, check-ins included) was accepted in writing by the
participant on 26 Nov 2026, pilot day 1, before any export.

### 10.6 Amendment: active mode and up to four questions a day (26 Nov 2026, evening of day 1)
Written on 26 Nov 2026, pilot day 1, before any export or analysis; decided by the participant
and the team.

- **Why.** In shadow mode the app cannot improve during the week, and two questions a day give few
  labelled answers (a label needs 5 earlier answers). The team wants the pilot to show the app
  learning from one real user.
- **What changes, from the installation of the active build** (branch `phase6/actif`; time noted
  below):
  1. Both learning loops run in **active mode** (D4 revised, `docs/PROJECT.md` §3). The queue
     starts from the personal estimate once there are 5 labelled energy answers in the 14 days,
     and its reason may say "your answers show more / less energy than usual". The bandit chooses
     the strategy (S1 / S2 / S3) by Thompson sampling, with a uniform choice 45% of the time, and
     logs the probability of its choice. Home shows the energy row and the check-in sheet.
  2. **Up to four questions a day, for the pilot only.** The setting Settings › Debug › Personal
     layer › "Pilot: 4 questions a day" uses four fixed windows, 09:00–11:00, 12:00–14:00,
     15:00–17:00 and 18:00–21:00, instead of the two of Settings › Questions. The other rules of
     section 10.1 stay: at least 2 h apart, none in the 80 min after a queue starts, planned 3 days
     ahead, ignored after 2 h. Known gap: Settings › Questions still shows two windows and "Up to 2
     a day"; the app keeps two questions a day for every other user.
  3. The export adds, for each queue, where its start point came from (`e0Source`, section 7.2).
- **What stays.** The measures of section 7.3, fixed before the data, are computed as planned
  (days 1–3, 4–7, the week). Day 1 before the installation ran in shadow mode.
- **Added as exploratory, marked as such in the analysis:** queues that start from the rank against
  queues that start from the personal estimate (`e0Source`); the reward of each strategy chosen by
  the bandit; before against after the switch.
- **Expected size.** About 2 answers on day 1, then up to 4 a day: at most about 26 answers, about
  21 of them labelled; queues should start from the personal estimate from about day 3. With one
  participant who also built the app, this is a demonstration, not a proof.
- **Consent.** Item 6 of section 9 is revised as shown there, and accepted in writing by the
  participant before the installation of the active build.
- **Installed:** 26 Nov 2026 at ______ (filled in at the installation).
