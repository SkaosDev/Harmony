# Harmony pilot — protocol and consent (TODO 4.1)

> Written on 23 Nov 2026, **before any pilot data exist**. The analysis plan (section 7) is fixed
> here and is not changed after looking at the data. Check-ins (state model v2, TODO 6.14) will be
> added in section 10 if they enter the pilot build.

## 1. Purpose

A feasibility test of Harmony in daily life, and a first comparison of two kinds of queue:

- **Body** queues: the queue starts from the state estimated from the Apple Watch (heart rate,
  steps, sleep) and the time of day (current model, `docs/PROJECT.md` §6).
- **Time only** queues: the queue starts from the time of day only (`time_only` model of
  `model_params.json`), as if no watch data existed.

Questions: does the app work every day without help (crashes, playback, data coverage)? Are body
queues skipped less, and do they "fit" more often, than time-only queues **for this participant**?

This is **not** a proof of anything general: one participant, two weeks.

## 2. Participant

- **One participant: Clément Royer**, a member of the team (team decision, 23 Nov 2026,
  `docs/PROJECT.md` §3). This stays within the 5 accounts allowed by Spotify development mode.
- The participant is also a developer of the app: he knows the two kinds of queue and can guess
  which one he gets (the reason shown with a time-only queue only talks about the time of day).
  The comparison is therefore **not blind**; expectation effects are possible and are reported
  as a limit.

## 3. Duration and equipment

- **14 days, from Monday 7 Dec to Sunday 20 Dec 2026** (pilot day 1 = 7 Dec).
- iPhone 16 of the participant with a **Debug build** of Harmony installed from Xcode (the pilot
  controls live in the Debug screen), his own Spotify Premium account, his Apple Watch.

## 4. Before day 1

- [ ] Build from `main` installed; `Config.xcconfig` filled; Spotify connected; library imported
      and scored.
- [ ] Apple Watch worn for at least 7 days before day 1 (the personal reference is ready at 7 days).
- [ ] Spotify connected with the playlist scopes of 23 Nov. (`docs/PROJECT.md` §9): after a queue,
      the Spotify library holds a single "Harmony" playlist.
- [ ] Demo mode **off** (Settings › Debug).
- [ ] On day 1: Settings › Debug › Pilot › **Pilot running** switched on. This saves the start day
      and a random seed for the daily draw.
- [ ] Consent form (section 9) signed.

## 5. Daily procedure

- Wear the watch day and night as usual (night data give the sleep features).
- Use Harmony when a situation happens (wake-up, stress, low energy, wind-down), as a normal user
  would. **No minimum number of queues**: the pilot measures real use. As a guide, about two queues
  a day give 25–30 queues in two weeks.
- Skip, like or remove songs freely. Answer "Did it fit?" at the end of a queue when possible
  ("Skip" is allowed and is counted as "no answer").
- Do not switch the pilot off, do not change the date, do not use demo mode during the pilot.
- Note problems (crash, playback failure, wrong data, anything surprising) in a short dated list
  outside the app; they are used at the mid-pilot point.

## 6. Daily draw (TODO 4.4)

- Each pilot day is either a **body** day or a **time-only** day; every queue of that day uses the
  same kind.
- Days go in **blocks of two**: in each block, the order (body then time only, or the reverse) is
  drawn at random from the seed saved on day 1; the second day of the block gets the other kind.
  Over 14 days this gives exactly 7 body days and 7 time-only days (a daily coin toss could give
  10/4 with a single participant).
- On a body day, if the watch gives no recent heart rate, the app falls back to time only, as it
  always does. The queue keeps its drawn kind (`QueueRecord.kind`) and also records the mode it
  really used (`QueueRecord.stateMode`).
- A day is a calendar day on the phone (midnight to midnight).

## 7. Data and analysis plan (fixed before the data)

### 7.1 What stays on the phone
Everything Harmony already stores (library, song scores, hourly and nightly watch summaries,
queues, feedback, consents). Nothing new leaves the phone during the pilot.

### 7.2 What is exported (TODO 4.5), once, at the end
Settings › Debug › Pilot › **Export pilot data** writes one JSON file (format `harmony-pilot-1`),
which the participant copies to `data/pilot/` on a team computer (ignored by Git, never committed,
never pasted into a chat). It contains only:

- for each queue started since day 1: pilot day, hour of day, situation, drawn kind, mode really
  used, and for each song its position, score origin (MuSe, language model, neutral) and whether it
  was a MuSe suggestion; the skip / like / finish events with their position and seconds played;
  the "Did it fit?" answer;
- watch coverage counts: pilot days, nights with known sleep, hours elapsed, hours with at least one
  heart rate.

It never contains: Spotify IDs, song titles or artists, account IDs, the queue reason, the
estimated state or song targets, heart rate, step or sleep values, or absolute dates.

### 7.3 Measures (script `ml/pilot_analysis.py`)
- **Primary (TODO 4.7)**, by drawn kind (body vs time only):
  - **skip rate** = songs skipped before 30 s / (skipped + finished songs). A song left between
    30 s and its end gives no event and is not counted (rule of `PlaybackTracker`);
  - **fit rate** = "yes" / ("yes" + "no") among answered queues, with the answer rate beside it.
- **Secondary**: the same table by mode really used.
- **MuSe fallback (TODO 4.8)**: share of queues with at least one MuSe suggestion, share of songs
  that are suggestions, skip rate of suggestions vs library songs.
- **Watch coverage (TODO 4.9)**: share of nights with known sleep, share of hours with a heart rate,
  share of body queues that fell back to time only.

### 7.4 Uncertainty and reading
- With one participant, the unit of resampling is the **day**: 95 % intervals of the difference
  body − time only by bootstrap over days (days resampled within each kind, 2 000 resamples,
  percentiles 2.5 and 97.5, fixed seed).
- A difference whose interval excludes 0 is reported as a difference **for this participant
  only**; otherwise "no difference detected". Both outcomes are reported, in the report as they are.
- No product decision is taken from this pilot alone; the team discusses the results at the weekly
  meeting (`docs/PROJECT.md` §13: "mode heure seule si aucun gain").
- Only aggregates go to Git, `docs/PROJECT.md` and the report.

## 8. Mid-pilot point (TODO 4.6), day 7 (Sunday 13 Dec)

Short notes (in `docs/PROJECT.md` §12 or the meeting notes), without looking at the skip or fit
rates by kind (that would break section 7):
- crashes and bugs seen, playback failures, "Can't play this" screens;
- days with no queue, and why;
- watch worn at night? (count of nights with known sleep in Settings › Debug › Apple Health);
- what felt wrong or tiring;
- decision: continue unchanged, or fix a blocking bug (a fix is noted with its date).

## 9. Consent (simple written form)

> **Harmony pilot — consent**
>
> I take part in the Harmony pilot from 7 Dec to 20 Dec 2026 (CSE 406, Hanyang University,
> group G02). I understand that:
> 1. Harmony reads my Apple Watch heart rate, steps and sleep, and my Spotify library, and keeps
>    them **on my iPhone only**. Only song titles and artists are sent to the team's server to
>    score songs, as in normal use.
> 2. Harmony is not a medical device; it gives no health advice.
> 3. Each day, Harmony uses either my watch data or the time of day only to build my queues, by
>    random draw.
> 4. At the end, I export one file with the counts described in section 7.2 of the protocol (no
>    song names, no health values, no dates). I can read it before giving it to the team. Only
>    aggregate results are published, in the course report.
> 5. I can stop at any time without giving a reason, and delete all my data in Settings › My data
>    › Delete everything. If I stop, my exported data are not used unless I say so.
>
> Name: ____________________  Date: ____________  Signature: ____________________

## 10. Check-ins (state model v2) — to be completed by TODO 6.14

Not part of the pilot build today (Phase 6 not implemented). If the check-in notifications enter
the build before 7 Dec, TODO 6.14 adds here: the two daily questions, the "Not now" answer, what
is logged (`CheckIn`, `PromptLog`), the exported pairs (`pCommonBefore`, `pPersonalBefore`,
`labelEnergy`, `dayOfUse`) and prompt counts, the consent sentence covering them, and the answer of
the teacher on whether an ethics review is needed.
