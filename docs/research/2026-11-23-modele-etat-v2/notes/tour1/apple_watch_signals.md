# Signals a third-party iPhone app (with an optional watchOS app) can read from Apple Watch and iPhone, November 2026

Scope note: "Documented" means Apple developer documentation, Apple support articles or Apple white papers. "Community" means developer forums, blogs or vendor posts. The deployment target is iOS 18.0, so anything introduced later needs `if #available`. Apple doc pages were read through their JSON endpoints (`developer.apple.com/tutorials/data/documentation/...json`). The links below point to the human-readable pages.

## Q1. Heart signals in HealthKit: identifiers, devices, sampling cadence, history

### Takeaway
On every Apple Watch before Series 12, background heart rate (HR) is built to publish at most **one value per non-overlapping 5-minute window, and only while the wearer is still**. The team's field cadence of one sample every 4.2–4.6 min matches this design. HRV (SDNN) comes from background "tachograms" (beat-to-beat recordings) taken **every 4 h by default**: about 6 attempts a day, fewer in practice because the wearer must be still. That rises to every 2 h with irregular-rhythm notifications and every 15 min with AFib History. Apple's DTS (developer support) says no third-party API changes the background rate. The only levers are a watch-side HKWorkoutSession, which gives about 5-second HR but only during a real workout, or a Series 12 / Ultra 4 watch. On those models, Apple says it measures as often as every 5 s all day, but it has not said how much of that reaches HealthKit.

### Cited Findings
**heartRate (`HKQuantityTypeIdentifier.heartRate`, iOS 8 / watchOS 2)**
- Apple's 2024 white paper names three algorithms. The foreground (workout or user-initiated) algorithm "attempts to provide one heart rate measurement … every five seconds". The background algorithm "reports measurements only when the user is still. It attempts to report one heart rate in bpm every 5 minutes." "In every non-overlapping five minutes window, Apple Watch attempts to publish one background heart rate to HealthKit, with availability subject to signal quality and user motion." Background HR uses **infrared** PPG (light-based pulse sensing) plus the accelerometer — [Apple, Heart Rate, Calorimetry, and Activity on Apple Watch, Nov 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)
- The same paper adds walking spot checks: "the foreground heart rate algorithm is triggered for up to one minute for spot checks when the user appears to be walking … a spot-checked walking heart rate is published to HealthKit" — [Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)
- HR samples can carry `HKMetadataKeyHeartRateMotionContext`. The value is "sedentary" if the user has been still for at least 5 minutes before the sample, and "active" if in motion. Some samples have no context. HealthKit "may condense/coalesce" HR samples — [Apple Docs: heartRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartrate)
- Apple's support page (published 30 Sep 2026): "Apple Watch Series 12 and Apple Watch Ultra 4 use green LEDs continuously during the day to provide a measurement as often as every five seconds, even when you're in motion. Infrared LED lights are used during your sleep schedule." Users can turn "Continuous Measurements" off — [Apple Support 120277](https://support.apple.com/en-au/120277)
- An earlier copy of the same support page: "Since Apple Watch takes these background readings based on your activity, the time between these measurements will vary." Apple Watch also measures HR continuously during a Workout app session and for 3 min after it — [Apple Support HT204666](https://support.apple.com/en-ie/HT204666)
- Community: Series 12 could in theory produce 17,280 HR readings a day, "although Apple describes measurement, not how much of it lands in HealthKit" — [Sahha blog, 23 Sep 2026](https://sahha.ai/blog/apple-event-2026-health-readiness-labs/). The same caveat, plus a note that Apple attributes the new cadence to Series 12 / Ultra 4 hardware, not to watchOS 27 on older watches — [Crosley, Five-Second Heart Rate](https://blakecrosley.com/blog/five-second-heart-rate-healthkit)
- Apple DTS on the developer forums: "There is no API for a 3rd party app to impact the sampling rate on an Apple Watch … it is completely up to the system" — [Apple Developer Forums 756622](https://developer.apple.com/forums/thread/756622)

**Raising HR sampling from a watchOS app (HKWorkoutSession / WKExtendedRuntimeSession)**
- "All workout sessions generate high-frequency heart rate samples." Apple Watch runs one workout session at a time, and a second one ends yours with `errorAnotherWorkoutSessionStarted`. HKWorkoutSession has been on iOS since 17.0, but on iPhone it needs an external HR sensor — [Apple Docs: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- Community measurement on an older watch: 639 HR samples in a 53-min run, about one every 5 s — [Crosley](https://blakecrosley.com/blog/five-second-heart-rate-healthkit)
- Extended runtime sessions (watchOS 6+) come in four types, chosen once per app: Self care (frontmost, 10 min), Mindfulness (frontmost, 1 h), Physical therapy (background, 1 h), Smart alarm (background, schedulable, 30 min). Apple: "Select a session type based on the app's intended use—not based on the features that the session provides." The system may cancel a session for high CPU use — [Apple Docs: Using extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions), [WKExtendedRuntimeSession](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession)

**restingHeartRate (iOS 11 / watchOS 4)** and **walkingHeartRateAverage (iOS 11 / watchOS 4)**
- Resting HR is estimated from sedentary samples and refined during the day. Earlier samples for the current or previous day may be deleted and replaced — [Apple Docs: restingHeartRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate)
- Resting HR excludes samples taken "during Sleep Focus, scheduled Bedtime, or time of sleep". "A single daily resting heart rate [is] published to HealthKit at the end of the day." The user also gets one average walking HR a day — [Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)
- Walking HR samples are created automatically, and apps cannot save their own. They may also be replaced for the current or previous day — [Apple Docs: walkingHeartRateAverage](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/walkingheartrateaverage)

**heartRateVariabilitySDNN (iOS 11 / watchOS 4)**
- "HealthKit uses SDNN … The system automatically records samples on Apple Watch" — [Apple Docs: heartRateVariabilitySDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn)
- "The default tachogram measurement cadence is every four hours, increasing to two hours or 15 minutes when a user enables irregular rhythm notifications or AFib History, respectively." Tachograms are taken "only if the user remains still enough". "Within HealthKit, SDNN is stored alongside the sequence of individual beat-to-beat measurements." Tachograms use **green** PPG — [Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)
- A Breathe session (Mindfulness app; the user stays still for 1 min or more) publishes one HR per minute plus "estimated HRV and a tachogram" to HealthKit. A Reflect session measures HR but does not ask the user to be still — [Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)
- "HRV is sampled while you're still, so the number of measurements you see will vary according to your activity level" — [Apple Support 120277](https://support.apple.com/en-au/120277)
- Series 12 / Ultra 4: HRV "as often as every five minutes" and "up to 24 times more often" (Apple Newsroom, as quoted by Crosley). Crosley reads "24×" as relative to the 2-hour irregular-rhythm cadence, but Apple does not say which baseline it used — [Crosley](https://blakecrosley.com/blog/five-second-heart-rate-healthkit), [Sahha](https://sahha.ai/blog/apple-event-2026-health-readiness-labs/)
- Community anecdote: users see irregular HR gaps, for example 12 readings in some hours and 3–6 in others — [Apple Community 255730449](https://discussions.apple.com/thread/255730449)

**heartRateVariabilityRMSSD (new: iOS 27.0 / watchOS 27.0)**
- The identifier exists in the iOS 27 SDK. Its documentation page has no abstract or discussion, and the platforms list iOS/watchOS 27.0 — [Apple Docs: heartRateVariabilityRMSSD](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd)
- Community: Apple has not said whether Recovery HRV (Series 12 / Ultra 4) writes SDNN, RMSSD or neither. The advice is to "verify on Series 12 data which one Recovery HRV writes" — [Sahha](https://sahha.ai/blog/apple-event-2026-health-readiness-labs/), [Crosley](https://blakecrosley.com/blog/five-second-heart-rate-healthkit)

**HKHeartbeatSeriesSample (beat-to-beat intervals; iOS 13 / watchOS 6)**
- Read with `HKHeartbeatSeriesQuery` (series type `HKSeriesType.heartbeat()`) — [Apple Docs: HKHeartbeatSeriesSample](https://developer.apple.com/documentation/healthkit/hkheartbeatseriessample)
- When it is recorded: alongside each background SDNN tachogram (every 4 h, 2 h or 15 min, see above) and each Breathe session — [Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)
- Community (developer forums): a third-party workout app could not get heartbeat series, and the series it saw "seem to be from the irregular HRV measurements done by Apple". An Apple reply says there is no API to trigger on-demand heartbeat series or to read raw heartbeat data from the watch — [Apple Developer Forums 746218](https://developer.apple.com/forums/thread/746218), [777751](https://developer.apple.com/forums/thread/777751) (secondary summary; the exact Apple wording was not re-checked)
- Tachogram algorithm availability on normal sinus rhythm (the share of tachograms that reach HealthKit with 10 or more consecutive pulses) is 92%, with 99.6% accuracy, measured over 266,000 tachograms from 240 subjects — [Apple HR white paper 2024, Table 4](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)

**heartRateRecoveryOneMinute (iOS 16 / watchOS 9)**
- This is the drop from peak exercise HR to HR one minute after exercise ends — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartraterecoveryoneminute)
- "Cardio recovery" is computed only after workouts, by "60-second heart rate recovery after submaximal exercise at 85 percent of the predicted heart rate maximum", with an upper bound of 55 bpm — [Apple HR white paper 2024](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November_2024.pdf)

**vo2Max (iOS 11 / watchOS 4)**
- Series 3 and later produce it automatically, and only after outdoor walk, run or hiking workouts on flat ground with good GPS and enough exertion — [Apple Docs: vo2Max](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/vo2max)

### Inferences
- The team's observed 4.2–4.6 min cadence comes from the background design: one attempt per 5-minute window when still, plus walking spot checks. Expect large gaps during movement, and no background HR during workouts other than workout HR.
- The **motion-context metadata** could be a cheap extra feature, for example the share of sedentary samples or HR restricted to sedentary samples. It is computed on device and does not raise the sampling rate.
- SDNN on Series 4–11 gives about 0–6 values a day by default. That is too sparse for a momentary arousal input. It fits better as a daily or overnight baseline feature, and only if the training data has an equivalent. RMSSD (iOS 27) is the metric most research datasets publish (e.g. Fitbit), but the iOS 18.0 target means RMSSD must be optional, and nobody yet knows which watches write it.
- Using HKWorkoutSession just to raise HR sampling outside real workouts is risky. It credits the Exercise ring, drains the battery, blocks other workout apps (one session at a time), and Apple's guidance is to choose session types by intended use. A short "Mindfulness"-type extended session or an explicit user check-in is the closest legitimate option, and it does not guarantee dense HR either.

### Gaps
- Apple publishes no cadence at which Series 12 / Ultra 4 5-second HR and 5-minute HRV are **written to HealthKit**. Only measuring on a device will tell.
- Whether Recovery HRV or the new RMSSD type is written by watchOS 27 on older watches (Series 9–11) is undocumented.
- How much `HKWorkoutSession` drains the battery over long sessions: no Apple number found.

## Q2. Respiration, temperature, SpO2, sleep and breathing disturbances (night-time signals)

### Takeaway
Overnight vitals can all be read by third parties. Sleep stages (Awake/REM/Core/Deep, iOS 16+) come from an accelerometer-based algorithm. Its four-stage agreement with polysomnography (PSG, the clinical sleep test) is kappa 0.63, and 0.68 after the iOS 26 / watchOS 26 update. Wrist temperature is one value per night (Series 8+ / Ultra). Breathing disturbances is a nightly value (iOS 18.0, so fine for the target). Apple's **Sleep Score (iOS 26) has no HealthKit type**.

### Cited Findings
- **sleepAnalysis** (`HKCategoryTypeIdentifier.sleepAnalysis`, iOS 8) with `HKCategoryValueSleepAnalysis`. Stage values (`asleepCore`, `asleepDeep`, `asleepREM`, `awake`) arrived in iOS 16 / watchOS 9. `asleepCore` = AASM (sleep-scoring standard) stage N2, plus N1. The detailed samples overlap the in-bed sample but not each other. "Samples recorded by Apple Watch only include awake samples that occur between two sleep samples" — [Apple Docs: HKCategoryValueSleepAnalysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis), [asleepCore](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis/asleepcore)
- Sleep tracking needs Series 3 or later. It classifies each 30-second window and uses accelerometer signals, including breathing-induced motion. Validation set results: median sleep sensitivity 97.9%, specificity 75.0%, mean four-stage kappa 0.63 (SD 0.13). Apple Watch model had no impact on kappa — [Apple, Estimating Sleep Stages from Apple Watch, Oct 2025](https://www.apple.com/kr/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf)
- The 2025 update (iOS 26.0 / watchOS 26.0) uses "foundation models developed using data from the Apple Heart and Movement Study". It is still accelerometer-based. Wake classification improved from 70% to 79%, and median kappa from 0.63 to 0.68. Full staging now continues after a dismissed alarm. Hold-out set: kappa 0.66, sensitivity 95.0%, specificity 86.5% — [Apple Sleep Stages paper, Oct 2025](https://www.apple.com/kr/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf)
- Independent validation, Series 6 (2022): sleep/wake agreement with PSG 88%, multi-stage agreement 53% (kappa 0.20) — [Sensors 2022, PMC9412437](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9412437/). Independent validation, Series 8 against Oura and Fitbit Sense 2 (n=35, one night of in-lab PSG): stage sensitivity about 50–86%, total sleep time similar to PSG — [PubMed 39460013](https://pubmed.ncbi.nlm.nih.gov/39460013/)
- **appleSleepingWristTemperature** (iOS 16 / watchOS 9): Series 8 / Ultra or later. Measured "every five seconds overnight" and aggregated "to a single appleSleepingWristTemperature sample" per night, corrected for environment. Requires Sleep Focus. Readable from the first night, even though the Health app needs about 5 nights to show a baseline — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature)
- **appleSleepingBreathingDisturbances**: iOS 18.0 / watchOS 11.0 (no abstract in the docs) — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingbreathingdisturbances)
- **respiratoryRate** (iOS 8 / watchOS 2): "The system automatically records samples on Apple Watch" — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/respiratoryrate). The Vitals app lists respiratory rate among **overnight** metrics — [Apple Support 120142](https://support.apple.com/en-us/120142)
- **oxygenSaturation** (iOS 8): percent units — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/oxygensaturation). The Blood Oxygen app is not on Apple Watch SE. For US watches bought on or after 18 Jan 2024 (part numbers LW/A or LS/A), "the Blood Oxygen data analysis is performed on iPhone, and results can be viewed in the Health app", and the data is not in Vitals — [Apple Support 120142](https://support.apple.com/en-us/120142)
- **Vitals app** (overnight): HR, respiratory rate, blood oxygen, wrist temperature, sleep duration. It needs 7 nights to establish a typical range, plus Sleep Focus. On Series 12 / Ultra 4, HRV replaces sleep duration and there are **daytime vitals** (resting HR, HRV) — [Apple Support 120142](https://support.apple.com/en-us/120142)
- **Sleep Score** (iOS 26 / watchOS 26) is computed from duration, bedtime and interruptions. A developer post says no API exists for it — [9to5Mac Nov 2025](https://9to5mac.com/2025/11/10/ios-26-2s-new-sleep-score-grades-already-feel-like-an-upgrade/), [Apple Developer Forums HealthKit tag](https://developer.apple.com/forums/tags/healthkit?page=5). My scan of every HKQuantityTypeIdentifier and HKCategoryTypeIdentifier in Apple's documentation (157 identifiers, up to iOS 27.3) found **no sleep-score, readiness or vitals-score identifier** — [Apple Docs: HKQuantityTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier), [HKCategoryTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier)

### Inferences
- Sleep features already in Harmony (measured sleep) can be extended at no extra permission cost (the sleepAnalysis type is already authorized). Candidates: sleep onset latency, wake after sleep onset, deep/REM share, number of awakenings. Apple's own doc suggests these secondary statistics. Stage-level accuracy is moderate, so totals and wake measures are more trustworthy than REM/Deep minutes.
- The sleep-time sensor algorithm changed with iOS 26 / watchOS 26. Stage distributions from older and newer OS versions may not be directly comparable. This matters for "usual" baselines.
- Wrist temperature, breathing disturbances and respiratory rate are **nightly** scalars. They fit a "wake-up" or "next-day baseline" feature, not momentary arousal.

### Gaps
- Apple does not document the exact cadence of respiratory-rate samples, or whether they are recorded outside sleep (only "automatically records"). No Apple statement on sampling frequency was found.
- No Apple statement was found on whether the iPhone-computed SpO2 for US LW/A models is written to HealthKit as `oxygenSaturation`.

## Q3. Activity, behavioural and environmental HealthKit types

### Takeaway
Activity and environment types are all available on iOS 18 and earlier. They are cumulative or discrete samples written automatically by Apple Watch and/or iPhone: activeEnergyBurned, appleExerciseTime, appleStandTime, physicalEffort, timeInDaylight, environmentalAudioExposure, headphoneAudioExposure, mindfulSession. Most are behaviour proxies, not physiology.

### Cited Findings
- **appleExerciseTime** (iOS 9.3): "every full minute of movement that equals or exceeds the intensity of a brisk walk". It uses the accelerometer, plus HR and GPS during workouts — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/appleexercisetime)
- **appleStandTime** (iOS 13 / watchOS 6): cumulative time units — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applestandtime)
- **physicalEffort** (iOS 17 / watchOS 10): in METs, "estimated amount of energy being used to perform a task excluding other factors such as temperature, altitude, or heart rate". "Estimated and recorded automatically by Apple Watch" — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/physicaleffort)
- **timeInDaylight** (iOS 17 / watchOS 10): cumulative — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/timeindaylight). watchOS 10 measures it with the watch's ambient light sensor — [Apple Newsroom, watchOS 10](https://www.apple.com/uk/newsroom/2023/09/watchos-10-is-available-today/)
- **environmentalAudioExposure** (iOS 13 / watchOS 6): dBA, "can be automatically collected by an Apple Watch". **headphoneAudioExposure** (iOS 13): "automatically detected by an iPhone or Apple Watch" — [Apple Docs: environmental](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/environmentalaudioexposure), [headphone](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/headphoneaudioexposure)
- **mindfulSession** (iOS 10): a category sample with `notApplicable` value. It records sessions and no physiology — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/mindfulsession)
- **workoutEffortScore / estimatedWorkoutEffortScore** (iOS 18.0) are workout-only — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore)
- Apple's WBM paper shows how often these appear in a large cohort, as the share of participant-weeks with at least one value. Active energy burned: 93.11% of weeks. 6-minute-walk distance: 8.93% of weeks. VO2max needs outdoor walk, run or hike workouts — [Erturk et al., arXiv 2507.00191, Table 3](https://arxiv.org/html/2507.00191v1)

### Inferences
- Of these, the ones with a plausible **momentary** link to arousal are the recent activity load (active energy, exercise minutes, physical effort in the preceding hour) and the noise context (environmental audio). The rest mainly describe the day.
- Headphone audio exposure partly reflects the app's own playback level, so it is circular as an input to a music recommender.

### Gaps
- No Apple source found for the exact list of watch models with an ambient light sensor that supports timeInDaylight, or for the sampling cadence of environmentalAudioExposure.

## Q4. HKStateOfMind and mental-health assessments as personal labels

### Takeaway
`HKStateOfMind` (iOS 18.0 / watchOS 11.0, so within the target) lets apps **read and write** user-logged daily moods or momentary emotions. Each entry has a continuous valence from -1 to +1, up to 38 labels and 18 life-domain "associations". It is self-report valence with **no arousal field**, so it could serve as sparse personal valence labels, but not directly as arousal labels.

### Cited Findings
- HKStateOfMind: iOS 18.0, watchOS 11.0, macOS 15, visionOS 2. Initializer `init(date:kind:valence:labels:associations:metadata:)`, with properties `valence` and `valenceClassification` — [Apple Docs: HKStateOfMind](https://developer.apple.com/documentation/healthkit/hkstateofmind)
- `Kind`: `dailyMood`, `momentaryEmotion` — [Apple Docs: HKStateOfMind.Kind](https://developer.apple.com/documentation/healthkit/hkstateofmind/kind-swift.enum)
- The labels are: amazed, amused, angry, annoyed, anxious, ashamed, brave, calm, confident, content, disappointed, discouraged, disgusted, drained, embarrassed, excited, frustrated, grateful, guilty, happy, hopeful, hopeless, indifferent, irritated, jealous, joyful, lonely, overwhelmed, passionate, peaceful, proud, relieved, sad, satisfied, scared, stressed, surprised, worried — [Apple Docs: HKStateOfMind.Label](https://developer.apple.com/documentation/healthkit/hkstateofmind/label)
- The associations are: community, currentEvents, dating, education, family, fitness, friends, health, hobbies, identity, money, partner, selfCare, spirituality, tasks, travel, weather, work — [Apple Docs: HKStateOfMind.Association](https://developer.apple.com/documentation/healthkit/hkstateofmind/association)
- WWDC24: valence is "a self-reported measure of how good or bad someone is feeling … measured on a continuous scale from negative to positive 1". Apps can "read and write the results of the GAD-7 anxiety and PHQ-9 depression questionnaires" — [WWDC24 session 10109](https://developer.apple.com/videos/play/wwdc2024/10109/)
- `HKScoredAssessment` / `HKGAD7Assessment` (and PHQ-9): iOS 18.0 — [Apple Docs: HKScoredAssessment](https://developer.apple.com/documentation/healthkit/hkscoredassessment), [HKGAD7Assessment](https://developer.apple.com/documentation/healthkit/hkgad7assessment)
- Apple's Health-app assessments are "for informational purposes only and the results are not a medical diagnosis" — [Apple Support 105070](https://support.apple.com/en-lamr/105070)

### Inferences
- As **personal labels**: State of Mind entries exist only if the user logs them, so they will be sparse for most users. The team's own app could prompt a short State of Mind check-in and write it with `HKStateOfMind`, which gives the user a log they own. Valence can map onto EmoPhone's valence ESM item, after rescaling a 7-point Likert to [-1, 1]. No arousal field exists, though a few labels are arousal-laden (calm, peaceful, drained vs excited, stressed, overwhelmed).
- **Project hard rule check:** reading or writing State of Mind involves named emotions (labels). The rule "never show a named emotion to the user" means the UI must not display those labels back. Collecting valence alone, without labels, stays compatible.
- PHQ-9 and GAD-7 are trait or episodic screening tools (2-week windows), not momentary, and are close to "medical claims" territory. They are not suitable as model inputs for this app.

### Gaps
- The cut-offs Apple uses for `valenceClassification` were not retrieved (the doc page had no discussion text).
- No data found on how many real users log State of Mind regularly.

## Q5. Apple features from watchOS 26 / iOS 26 / watchOS 27 (Sleep Score, hypertension, readiness, Recovery HRV): what developers can read

### Takeaway
Apple "opened inputs, kept outputs". **Readable:** `hypertensionEvent` (iOS 26.2), `heartRateVariabilityRMSSD` (iOS 27.0), menopause types (iOS 27.0), workout zones (iOS 27.0), and the underlying sleep and vitals samples. **Not readable:** Sleep Score, Readiness (0–10, Series 12 / Ultra 4), Health Age, Health app Insights. Apple has shipped no developer-readable "stress score".

### Cited Findings
- From my scan of Apple's documentation index, the HealthKit identifiers and symbols introduced in iOS 26 or later are:
  - `hypertensionEvent` (26.2)
  - medications APIs: `HKUserAnnotatedMedication`, `HKMedicationDoseEvent` (26.0)
  - `HKLiveWorkoutBuilder` on iPhone (26.0)
  - `heartRateVariabilityRMSSD`, `menopausalState`, `bleedingAfterMenopause`, `HKWorkoutZone*` (27.0)
  - `hipCircumference`, `HKReferenceSex` (27.3)

  — [Apple Docs: hypertensionEvent](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/hypertensionevent), [heartRateVariabilityRMSSD](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd), [HealthKit index](https://developer.apple.com/documentation/healthkit)
- Hypertension notifications: the watch "analyzes heart data" for signs of possible hypertension and notifies the user, who is prompted to log blood pressure with a cuff for 7 days. Not for users under 22, during pregnancy or with diagnosed hypertension. "Not a medical device" — [Apple Support: hypertension notifications](https://support.apple.com/en-ae/guide/watch/apd7c37bb802)
- The event type became developer-readable in iOS 26.2 beta 3 — [iThinkDiff](https://www.ithinkdiff.com/ios-ipados-26-2-beta-3-healthkit-storekit/)
- Readiness: a 0–10 daily score ("Recover, Pace Yourself, Ready, Go For It") built from recent activity, vitals, sleep score and training load. It needs 7 nights and exists only on Series 12 / Ultra 4. "It is not a HealthKit type." watchOS 27 runs on Series 9 and later, SE 3 and Ultra 2 and later — [Sahha](https://sahha.ai/blog/apple-event-2026-health-readiness-labs/), [Crosley](https://blakecrosley.com/blog/five-second-heart-rate-healthkit) (community, citing Apple Newsroom of 9 Sep 2026)
- Recovery HRV (Series 12 / Ultra 4) "can be an indicator of stress and recovery" — [Apple Support 120277](https://support.apple.com/en-au/120277)
- Third-party reviews: Apple Watch has no combined stress metric or stress alerts. Mood logging happens through State of Mind — [Kygo 2026](https://www.kygo.app/post/apple-watch-stress-tracking-explained) (vendor blog)

### Inferences
- For an iOS 18.0 target, none of the new types is a base input. RMSSD could be an optional enhancement on iOS 27 devices. `hypertensionEvent` is irrelevant to music selection and, under the "no medical claims" rule, should not be used.
- Apple's Readiness and Sleep Score cannot be read, so a "readiness-like" feature has to be rebuilt from raw samples (sleep, resting HR, HRV).

### Gaps
- The data used by hypertension notifications (PPG over many days, per press coverage) was not confirmed from an Apple primary source in this session.
- `getEarliestAuthorizedSampleDate(for:completion:)` (users granting only part of their history) is mentioned in Apple docs. The OS version that introduced it was not checked.

## Q6. Access mechanics: permissions, background delivery, history window

### Takeaway
HealthKit reads need per-type user authorization and the HealthKit entitlement. Background wakes need the `com.apple.developer.healthkit.background-delivery` entitlement (iOS 15+), and most types are capped at **hourly** wakes. Historical depth is a system-wide constraint rather than a per-app window (in practice the full on-phone history, unless the user grants less). CoreMotion is different: it keeps only 7 days.

### Cited Findings
- `enableBackgroundDelivery(for:frequency:)`:
  - On iOS 15 / watchOS 8 and later it requires the `com.apple.developer.healthkit.background-delivery` entitlement.
  - "The system wakes your app at most once per time period … Some sample types have a maximum frequency of hourly … on iOS, stepCount samples have an hourly maximum frequency."
  - On watchOS, most types are hourly. A few event types (high/low HR events, irregular rhythm, audio exposure events, vo2Max, etc.) can be immediate. Background updates share a budget of 4 per hour with app refresh, and only if the app has a complication on the active watch face.

  — [Apple Docs: enableBackgroundDelivery](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:))
- `earliestPermittedSampleDate()`: "a systemwide platform constraint that applies equally to all apps. It isn't related to what the person chooses to share with your app. To determine whether the person grants your app a limited portion of their health history, use `getEarliestAuthorizedSampleDate(for:completion:)`" — [Apple Docs](https://developer.apple.com/documentation/healthkit/hkhealthstore/earliestpermittedsampledate())
- iPhone usually locks during workouts. "For privacy reasons, health data usually isn't accessible while the device is locked" — [Apple Docs: HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- Community advice: "Leave background delivery at hourly unless a feature needs faster". Move to anchored queries and statistics collections as HR density grows — [Crosley](https://blakecrosley.com/blog/five-second-heart-rate-healthkit)

### Inferences
- A "right now" arousal estimate should query HealthKit **when the user opens the app or the moment fires**, not rely on background delivery. Data written by the watch also takes time to sync to the phone.
- Locked-device restrictions mean that wake-up moments, triggered before the phone is unlocked, may not read health data until unlock.
- Background knowledge, not re-verified in this session: HealthKit hides whether *read* access was denied. A denied type looks the same as "no data", which fits the project's "unknown is not zero" rule.

### Gaps
- How long Apple Watch itself keeps HealthKit data on the watch (relevant only if inference ran on watchOS) was not documented in sources read here.
- Typical watch-to-phone HealthKit sync latency is not documented by Apple.

## Q7. Non-HealthKit context: CoreMotion, CoreLocation, EventKit, Screen Time / DeviceActivity, SensorKit, ambient light, Spotify

### Takeaway
Without special entitlements, the app can use CoreMotion activity and pedometer data (7-day history), CoreLocation visits, EventKit calendar events (with permission) and Spotify's last 50 played tracks. Screen-time and app-usage data are only usable inside a sandboxed DeviceActivity extension. Raw ambient light, phone and keyboard usage, raw PPG/ECG and Watch heart rate via SensorKit need a **research-only SensorKit entitlement**, granted per approved study with IRB (ethics board) approval. That is not realistic for a consumer course app.

### Cited Findings
- `CMMotionActivityManager.queryActivityStarting`: "The system stores only the last seven days worth of activity data at most." "A delay of up to several minutes in reported activities is expected" — [Apple Docs](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/queryactivitystarting(from:to:to:withhandler:))
- `CMPedometer.queryPedometerData`: "Only the past seven days worth of data is stored and available" — [Apple Docs](https://developer.apple.com/documentation/coremotion/cmpedometer/querypedometerdata(from:to:withhandler:))
- `CMMotionActivity` flags (stationary, walking, running, automotive, cycling) are not mutually exclusive — [Apple Docs](https://developer.apple.com/documentation/coremotion/cmmotionactivity)
- `CLVisit` (iOS 8) gives arrival and departure times plus a location, created by the system. `startMonitoringVisits()` works with reduced accuracy if precise location is not granted — [Apple Docs: CLVisit](https://developer.apple.com/documentation/corelocation/clvisit), [startMonitoringVisits](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringvisits())
- EventKit `events(matching:)` returns committed events matching a predicate (requires calendar permission) — [Apple Docs](https://developer.apple.com/documentation/eventkit/ekeventstore/events(matching:))
- DeviceActivity (iOS 15): "a privacy-preserving way for an application to monitor a person's application and website activity". The app extension receives schedule and threshold callbacks, and reports are built in `DeviceActivityReportExtension` — [Apple Docs: DeviceActivity](https://developer.apple.com/documentation/deviceactivity)
- SensorKit (iOS 14): `SRSensor` includes:
  - phone use: deviceUsageReport, keyboardMetrics, phoneUsageReport, messagesUsageReport, mediaEvents, siri/telephony speech metrics, faceMetrics
  - context: onWristState, visits, ambientLightSensor, ambientPressure, odometer, pedometerData, acousticSettings, headphoneMotion
  - motion: accelerometer, rotationRate
  - physiology: heartRate (iOS 17), photoplethysmogram (iOS 17.4, needs the extra `ppg` entitlement key), electrocardiogram, wristTemperature, sleepSessions (iOS 26.0)

  — [Apple Docs: SensorKit](https://developer.apple.com/documentation/sensorkit), [SRSensor](https://developer.apple.com/documentation/sensorkit/srsensor), [SRSensor.photoplethysmogram](https://developer.apple.com/documentation/sensorkit/srsensor/photoplethysmogram), [SRSensor.heartRate](https://developer.apple.com/documentation/sensorkit/srsensor/heartrate)
- SensorKit entitlement (`com.apple.developer.sensorkit.reader.allow`): Apple grants it for approved research studies. "Once you have IRB … approval of your study and are ready to launch, you'll be provided the entitlement to distribute your app to study participants." A third-party guide adds that Distribution needs ethics approval, an informed-consent form and collaborator agreements — [Apple Docs: entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.sensorkit.reader.allow), [researchandcare.org guide](https://www.researchandcare.org/resources/accessing-sensorkit-data)
- Spotify `GET /me/player/recently-played`: `limit` default 20, max 50. Community and staff replies say only the last 50 tracks can be retrieved, even with cursors — [Spotify Web API reference](https://developer.spotify.com/web-api/console/get-recently-played), [Spotify Community](https://community.spotify.com/t5/Spotify-for-Developers/Get-all-recently-played-tracks-for-a-given-period/td-p/5860931)

### Inferences
- Realistic for Harmony without special entitlements:
  - CoreMotion activity state (stationary, walking, automotive) for the last minutes or hours. Its 7-day window is enough for the current moment.
  - Calendar "busyness" around the current time (event count or density in the next or last 2 h).
  - Spotify recently-played as a listening context. Song titles and artists are not health data, so the Worker rule is unaffected if they stay on the phone.
- Raw ambient light on iPhone is only available via SensorKit (research). The only consumer path is HealthKit `timeInDaylight` (a watch-derived daily or cumulative amount).
- Screen Time cannot be exported into a model running inside the main app; DeviceActivity data stays inside the extension's sandbox. (Inference from Apple's "privacy-preserving" framing. Exact data-flow restrictions not re-verified.)

### Gaps
- Not confirmed in this session: SensorKit's 24-hour holding period (data available only after a delay) and whether DeviceActivity requires the FamilyControls entitlement. Both are from background knowledge.
- Background knowledge, not verified here: the Spotify audio-features endpoint (valence/energy) is deprecated for new apps since late 2024. Relevant if listening history is meant to be turned into arousal features.

## Q8. Apple's own research on what Apple Watch / HealthKit data predicts (mood, stress, mental state)

### Takeaway
Apple's foundation-model papers use Apple Heart and Movement Study (AHMS) data. WBM uses 27 HealthKit-derived behavioural quantities, hourly over weekly windows. The PPG/ECG foundation model uses raw sensor data. Both predict **trait-level** conditions and medications well. Depression (self-reported history) reaches AUROC 0.76 with WBM and 0.80 with WBM+PPG. Neither predicts momentary mood, stress or arousal, and Apple releases **no weights** ("unable to release model weights and code due to … informed consent").

### Cited Findings
- WBM is built on behavioural metrics (movement, sleep, exercise) rather than raw sensors. It was trained on Apple Watch and iPhone data from 161,855 AHMS participants, over 2.5B hours, and evaluated on 57 tasks — [Apple ML Research: Beyond Sensor Data](https://machinelearning.apple.com/research/beyond-sensor), [arXiv 2507.00191](https://arxiv.org/html/2507.00191v1)
- Inputs: "27 interpretable HealthKit quantities". Hourly aggregation: sums for cumulative variables, means for momentary ones (HR, respiratory rate). Weekly windows. Mamba-2 backbone with contrastive training — [arXiv 2507.00191](https://arxiv.org/html/2507.00191v1)
- Variables include, among others: flights climbed (phone and watch), active energy, HRV (SDNN), respiratory rate, sleeping wrist temperature, step count (phone and watch), walking speed and steadiness, stand time, exercise minutes, VO2max, 6-minute-walk distance, BMI, oxygen saturation — [arXiv 2507.00191, Table 3 and reconstruction table](https://arxiv.org/html/2507.00191v1)
- Sleep was **not** an input. Weekly sleep metrics were downstream targets — [arXiv 2507.00191](https://arxiv.org/html/2507.00191v1)
- Trait-level ("baseline disease and medication") tasks: 47 survey outcomes, including depression, anti-anxiety medication and antipsychotics. Depression AUROC: baseline 0.728, WBM 0.764, PPG 0.781, WBM+PPG 0.799 (assuming the column order Baseline | WBM | PPG | WBM+PPG used in the paper's other tables). Time-varying tasks: infection, pregnancy, injury, diabetes (HbA1c), weekly sleep metrics — [arXiv 2507.00191, Table 26](https://arxiv.org/html/2507.00191v1)
- "We are unable to release model weights and code due to the specifics of the informed consent" — [arXiv 2507.00191](https://arxiv.org/html/2507.00191v1)
- PPG/ECG foundation models (ICLR 2024): self-supervised training on AHMS PPG and ECG recorded on Apple Watch from about 141K participants — [Apple ML Research: Large-scale Training of Foundation Models for Wearable Biosignals](https://machinelearning.apple.com/research/large-scale-training)
- Apple's 2025 sleep-staging update uses "foundation models developed using data from the Apple Heart and Movement Study" (accelerometer-based) — [Apple Sleep Stages paper, Oct 2025](https://www.apple.com/kr/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf)
- A search found no Apple-authored 2025–2026 study predicting momentary stress or mood from Apple Watch data. The closest academic work is a 33-participant pilot using Apple Watch ECG-derived HRV. Its models were "specific for 'no stress' states but … less successful at capturing 'stress' states" — [PubMed 36569803](https://pubmed.ncbi.nlm.nih.gov/36569803/)

### Inferences
- Apple's results support a weekly / trait framing (who is more depressed or less fit) more than a moment framing (is this person more activated than usual right now). The latter is what Harmony needs.
- Nothing usable can be imported as weights. What transfers is the design: hourly aggregates, missingness indicators ("unknown is not zero") and contrastive per-person representations.

### Gaps
- The full list of 57 tasks and their numbers for anxiety-related outcomes was only partly retrieved.
- Apple's Mind/mood research, if any exists beyond AHMS surveys, was not found.

## Q9. Which signals plausibly carry arousal / stress / valence (literature), and which also exist in training datasets

### Takeaway
The strongest physiological stress and arousal markers are HRV (lower parasympathetic activity under stress) and EDA (skin conductance). Apple Watch exposes HRV only sparsely and has **no EDA**. Valence is weakly recoverable from wearable physiology. In-the-wild performance is modest: LifeSnaps mood prediction reached about 70%, with few labelled days. For the team's training-data constraint, the inputs that also exist in EmoPhone (Fitbit Inspire HR + Android) are HR, steps and sleep, plus phone context (activity, location, app use, ambient light on Android). LifeSnaps (Fitbit Sense) is the main public dataset adding HRV RMSSD, respiratory rate, skin temperature, SpO2 and a device stress score, together with EMA mood (self-reports logged during the day).

### Cited Findings
- Meta-analysis of 37 publications: the variation in HRV most often associated with stress was "low parasympathetic activity, which is characterized by a decrease in the high-frequency band and an increase in the low-frequency band". HRV supports "objective assessment of psychological health and stress" — [Kim et al. 2018, Psychiatry Investig., PubMed 29486547](https://pubmed.ncbi.nlm.nih.gov/29486547/), [PMC5900369](https://pmc.ncbi.nlm.nih.gov/articles/PMC5900369)
- Consumer wearables: combining HRV and EDA "enhanced stress prediction across most scenarios", but device-specific limits hurt transfer across devices — [arXiv 2505.05694](https://arxiv.org/html/2505.05694v1). Wrist EDA has weak agreement with finger EDA, and cross-dataset balanced accuracies are "not encouraging" — [arXiv 2203.09669](https://arxiv.org/pdf/2203.09669)
- A 2026 JMIR scoping review: detecting stress in naturalistic settings "brings significant new challenges" — [JMIR mHealth 2026 e76632](https://mhealth.jmir.org/2026/1/e76632/PDF). Survey of wearable affect and stress recognition: [Schmidt et al., arXiv 1811.08854](https://ar5iv.arxiv.org/html/1811.08854)
- **LifeSnaps**: 71 participants, mid-2021 to early 2022, over 35 data types. Includes sleep, temperature, HR, SpO2, stress (device-assessed), HRV (RMSSD), respiratory rate and EMA mood via SEMA3. The Zenodo record is restricted — [Scientific Data, PMC9622868](https://pmc.ncbi.nlm.nih.gov/articles/PMC9622868), [Zenodo 6826682](https://zenodo.org/record/6826682)
- A 2025 medRxiv study on LifeSnaps (tense/anxious, happy, sad) reached about 70% accuracy. Only about 15% of days with complete Fitbit data also had EMA — [medRxiv 2025.02.13.25322254](https://medrxiv.org/content/10.1101/2025.02.13.25322254v1.full-text)
- **EmoPhone**: three waves (2020, 2021, 2022) with 297 participant-wave records from 282 people. Android phones running ABC Logger, plus the **Fitbit Inspire HR** in all waves. Shared ESM labels: valence, arousal, stress, disturbance. D-3 adds 8 affect-intensity items. Baselines are PSS-10 and GHQ-12, plus PHQ-9 in D-1 and D-2. About 7 ESM responses per active day. Keystroke sensing from D-2 onward — [Zhang et al., arXiv 2609.16581](https://arxiv.org/pdf/2609.16581)
- **K-EmoPhone**: 77 students, 7 days, 5,582 ESM responses. Valence, arousal, stress and attention labels. Android plus a wrist wearable — [Scientific Data 2023, PMC10238385](https://pmc.ncbi.nlm.nih.gov/articles/PMC10238385). (A university news item mentions Microsoft Band 2 for K-EmoPhone. EmoPhone, the multi-wave dataset, is Fitbit Inspire HR — [KU news](https://www.ku.ac.ae/?p=86715).)
- **GLOBEM**: 4 annual waves, 497 people, phone plus Fitbit, weekly PHQ-4, PSS-4 and PANAS. **DiversityOne**: 782 people, Android, mood/valence (as tabulated in the EmoPhone paper) — [arXiv 2609.16581, Table 1](https://arxiv.org/pdf/2609.16581)

### Inferences
Signal-by-signal against the training-data constraint:

| Apple signal | Arousal/stress relevance | In EmoPhone (Fitbit Inspire HR + Android)? | Other dataset with equivalent |
|---|---|---|---|
| HR (background, ~5 min) | Moderate (confounded by movement) | Yes (Fitbit HR) | All Fitbit studies |
| HR motion context / sedentary-only HR | Improves HR specificity | Derivable from steps / activity | Derivable |
| Steps, active energy, exercise minutes | Behavioural arousal / energy | Yes (steps, likely calories) | All |
| Sleep duration / stages | Next-day energy and mood | Fitbit sleep (team already uses measured sleep) | LifeSnaps, GLOBEM |
| HRV SDNN (sparse) / RMSSD (iOS 27) | Strongest physiological stress marker (Kim 2018) | Not confirmed for the Inspire HR (no HRV stream listed) | LifeSnaps (RMSSD, nightly) |
| Respiratory rate, wrist temp, SpO2 | Weak, nightly | No | LifeSnaps |
| EDA | Strong arousal marker | No (and Apple Watch has no EDA) | WESAD-type lab sets only |
| Phone context (activity, location visits, calendar, app use) | Context for stress | Yes (Android logger) | GLOBEM, DiversityOne |
| Ambient light | Context | Android sensor in EmoPhone; on iPhone only via SensorKit (research) or watch `timeInDaylight` | — |
| State of Mind valence | Valence labels (self-report) | Matches the valence ESM item conceptually | LifeSnaps EMA |

- The realistic additions that keep train–deploy parity with EmoPhone are mainly **derived** features from signals already used: HR restricted to sedentary periods, recent-hour activity load, sleep-structure features (wake after sleep onset, latency), CoreMotion activity state and calendar density. Adding HRV, respiration or temperature would need a second training dataset such as LifeSnaps, with domain shift (Fitbit Sense vs Apple Watch, nightly RMSSD vs sparse daytime SDNN).
- Outputs: valence and stress labels exist in EmoPhone (shared core). Literature and Apple's own work suggest physiology predicts valence poorly, so adding valence or stress outputs would mostly reflect behavioural and contextual signals. The project rules (no named emotion, no medical claims) also limit how these outputs could be shown.

### Gaps
- The exact EmoPhone sensor stream list (for example, whether Fitbit sleep stages, calories or HRV are released) could not be extracted from the arXiv PDF figure text. The team should check its local copy.
- No study was found that directly validates Apple Watch background SDNN against ECG for daily-life stress detection. Apple's 2024 white paper validates tachogram beat accuracy, not SDNN as a stress marker.
- No quantified in-the-wild versus lab performance drop was found in the reviews retrieved.
