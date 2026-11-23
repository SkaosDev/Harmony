# How fully Harmony uses EmoPhone and UC Irvine: inventory, unused parts, on-device feasibility

Scope and method. Local data were read only in aggregate. Scripts (all outside the repo, nothing in the repo changed):
`/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/scripts/` —
`headers.py` (column names), `inventory.py` (streams every EmoPhone sensor archive; per-file counts, ESM coverage, category shares),
`esm_stats.py` (label counts, correlations, ICC), `uci_stats.py`, `uci_sleep_corr.py`. Raw outputs: `.../scratchpad/out/*.txt|json`.
`UserInfo.csv` was opened for its header line only. The `altitude` column of `Location.csv` was never read. No model was trained.
"ESM coverage 60/15" = share of all ESM responses of a wave (pooled) whose participant has at least one record of that stream in the 60 / 15 minutes before `actualTriggerTime`.
Local sources are cited as file paths; LOCAL-INV = `.../scratchpad/out/inventory.json` (from `inventory.py`), LOCAL-ESM = `.../scratchpad/out/esm.txt`, LOCAL-UCI = `.../scratchpad/out/uci.txt`, LOCAL-UCISLEEP = `.../scratchpad/out/uci_sleep.txt`.

## Q1. Which EmoPhone sensor streams exist per wave, which are used, and which have an iPhone + Apple Watch equivalent?

### Takeaway
EmoPhone ships ~25-30 CSV streams per participant (phone: 19-24, Fitbit: 4, plus 4 undocumented `Fitness-*` files in D-2 and D-3); Harmony uses 2 of them (`Fitbit-HeartRate`, `Fitbit-StepCount`) plus time of day. Of the unused streams, only motion-activity type, phone steps/activity segments, calories/METs, distance, and location-derived mobility have a realistic third-party iOS/watchOS equivalent; the phone-interaction streams that make up most of EmoPhone's feature space (screen, app usage, notifications, keyboard, calls/messages, ambient light, Wi-Fi/Bluetooth, ringer, traffic) are not available to a normal App Store app (only through SensorKit, which requires an Apple-approved research study).

### Cited Findings
**What Harmony uses today**
- Used: `Fitbit-HeartRate.csv` (1 sample / ~5 s), `Fitbit-StepCount.csv` (steps per minute, minutes without steps absent), and from `EsmResponse.csv` only `pcode`, `actualTriggerTime`, `arousal` (and `stress` for a side result) — [docs/PROJECT.md §5.1](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- No measured sleep and no HRV exist in EmoPhone; Python estimates sleep from Fitbit HR + steps; HealthKit HRV (SDNN) is read by the app but is outside the model — [docs/PROJECT.md §3, §5.1, §6.3](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- The app reads HealthKit `heartRate`, `stepCount`, `heartRateVariabilitySDNN`, `sleepAnalysis` (Apple Watch source only) — [docs/PROJECT.md §10](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)

**Files present per wave (full pass over 102 / 112 / 106 archives)**
- Archives: D-1 102 (1.9 GB), D-2 112 (2.8 GB), D-3 106 (1.1 GB); ESM: 10,259 / 21,042 / 21,838 responses from 92 / 99 / 106 participants — [LOCAL-INV and `ls`](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/inv_table.txt)
- Present in all three waves: ActivityEvent, ActivityTransition, AppUsageEvent, BatteryEvent, BluetoothScan, CallEvent, ChargeEvent, DataTraffic, DozeModeEvent, Fitbit-Calorie, Fitbit-Distance, Fitbit-HeartRate, Fitbit-StepCount, InstalledApp, Location, MessageEvent, NotificationEvent, OnOffEvent, PowerSaveEvent, RingerModeEvent, ScreenEvent, WifiScan, WirelessStateEvent. Wave-specific: `Light.csv` D-1 and D-2 only (absent from every D-3 archive); `KeyEvent.csv` D-2 and D-3; `Proximity.csv` D-2 only; `Fitness-Activity/Calorie/Distance/StepCount.csv` in all 112 D-2 archives **and all 106 D-3 archives** (non-empty in 100%) — [LOCAL-INV](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/inv_table.txt)
- This contradicts PROJECT.md, which says D-3 has neither `Proximity.csv` nor the `Fitness-*` files (the Proximity part is right, the Fitness part is not) — [docs/PROJECT.md §5.1 "Différences entre vagues"](/Users/clement/Hanyang/Harmony/docs/PROJECT.md) vs [LOCAL-INV](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/inv_table.txt)
- The paper's own tables are also inexact versus the release: Table 16 lists `Light.csv` for D-1, D-2, D-3 (no D-3 file exists); Table 18 says WiFiScan is D-1/D-2 only (D-3 archives have `WifiScan.csv` with 0.99 ESM coverage); Table 15 lists a `DeviceEvent.csv` that does not exist (the release has separate ScreenEvent, RingerModeEvent, ChargeEvent, OnOffEvent, PowerSaveEvent, DozeModeEvent, WirelessStateEvent files); the `Fitness-*` and `Proximity` files are not documented at all (0 mentions) — [arXiv:2609.16581 App. A.6–A.7](https://arxiv.org/html/2609.16581) vs [LOCAL-INV](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/inv_table.txt)
- Columns: Fitbit-HeartRate/StepCount/Distance `timestamp,value`; Fitbit-Calorie `timestamp,value,level,mets`; Fitness-* `timestamp,fromTime,toTime,value`; ActivityEvent `timestamp` + 8 confidences (Still, Unknown, InVehicle, OnBicycle, OnFoot, Walking, Running, Tilting); ActivityTransition `typeEnter,typeExit`; Location `timestamp,latitude,longitude,altitude,accuracy,speed`; KeyEvent `name,packageName,keyboardType,prevKeyType,currKeyType,distance,timeTaken,category`; AppUsageEvent `name,packageName,type,isSystemApp,isUpdatedSystemApp,category` (D-3 adds `name_y`, `source`); NotificationEvent `name,packageName,visibility,category` (+`isClearable,isOngoing,isPosted` from D-2); CallEvent `type,contactType,number,isStarred,isPinned,duration,presentation,dataUsage`; MessageEvent `number,messageClass,messageBox,contactType,isStarred,isPinned`; BatteryEvent `level,temperature,status,pluggedType`; DataTraffic `fromTime,toTime,rxBytes,txBytes,mobileRxBytes,mobileTxBytes`; WifiScan `address,rssi,frequency`; BluetoothScan `address,rssi` (+`bondState,deviceType,classType` from D-2); Light, Proximity `timestamp,value`; the rest `timestamp,type` — [headers.py output](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/headers.txt)
- Paper sampling rates: Fitbit HR 1 Hz, steps/calories/distance 1/60 Hz; Light 5 Hz; WiFi/Bluetooth scans 1/min; activity and location event-based. Privacy: longitude shifted by a per-participant constant, numbers MD5-hashed, BSSID/MAC replaced by UUIDs. DataTraffic "experienced a collection application malfunction in D-2". A Polar H10 chest strap was used in sub-periods of D-1/D-2 (not in the release as far as the file listing shows) — [arXiv:2609.16581 App. A.3.2, A.6](https://arxiv.org/html/2609.16581)
- `Location.csv` has an `altitude` column; PROJECT.md says it appears to contain real latitudes and must never be used — [docs/PROJECT.md §5.1](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)

**Coverage of each stream around ESM prompts (pooled share of responses; D-1 / D-2 / D-3)**

| Stream | ESM cov. 60 min | ESM cov. 15 min | Notes |
|---|---|---|---|
| Fitbit-HeartRate (used) | 0.94 / 0.64 / 0.94 | 0.91 / 0.62 / 0.92 | D-2: 35 of 112 archives have empty Fitbit files (non-empty 0.69) |
| Fitbit-StepCount (used) | 0.84 / 0.58 / 0.85 | 0.60 / 0.41 / 0.60 | minutes without steps absent |
| Fitbit-Calorie (kcal/min, level 0-3, METs) | 0.97 / 0.66 / 0.97 | 0.97 / 0.66 / 0.97 | every minute; level 0 = 85-87% of minutes |
| Fitbit-Distance | 0.84 / 0.58 / 0.85 | 0.60 / 0.41 / 0.60 | same rows as steps |
| Fitness-StepCount (D-2, D-3) | – / 0.64 / 0.67 | – / 0.36 / 0.39 | 30-s intervals |
| Fitness-Activity (D-2, D-3) | – / 0.94 / 0.39 | – / 0.94 / 0.21 | D-2 segments 94% "still"; D-3 has no "still" (walking 62%, in_vehicle 32%) |
| ActivityEvent (activity recognition) | 0.92 / 0.52 / 0.90 | 0.72 / 0.38 / 0.68 | |
| ActivityTransition | 0.47 / 0.48 / 0.52 | 0.24 / 0.25 / 0.27 | still/walking ~40% each, vehicle 15% |
| Location | 0.71 / 0.88 / 0.94 | 0.52 / 0.60 / 0.79 | |
| ScreenEvent | 0.92 / 0.92 / 0.94 | 0.69 / 0.67 / 0.71 | on/off/user_present |
| AppUsageEvent | 0.34 / 0.99 / 0.95 | 0.09 / 0.62 / 0.32 | logger format differs by wave |
| NotificationEvent | 0.98 / 0.99 / 0.99 | 0.90 / 0.98 / 0.98 | |
| KeyEvent | – / 0.54 / 0.74 | – / 0.30 / 0.42 | 70% QWERTY_KOR; 76-81% in COMMUNICATION apps |
| Light | 0.98 / 0.97 / – | 0.95 / 0.93 / – | median of per-person median ~104-119 |
| Proximity | – / 0.89 / – | – / 0.62 / – | |
| BatteryEvent | 0.99 / 0.98 / 1.00 | 0.96 / 0.94 / 0.96 | |
| WifiScan | 0.89 / 0.98 / 0.99 | 0.79 / 0.97 / 0.99 | |
| BluetoothScan | 0.77 / 0.97 / 0.99 | 0.71 / 0.93 / 0.97 | |
| DataTraffic | 0.50 / 0.70 / 1.00 | 0.33 / 0.66 / 1.00 | D-2 malfunction (paper) |
| CallEvent | 0.16 / 0.14 / 0.17 | 0.05 / 0.02 / 0.02 | median ~100-124 calls per person-wave |
| MessageEvent | 0.01 / 0.30 / 0.30 | 0.00 / 0.09 / 0.08 | D-1: empty for 53% of archives |
| ChargeEvent | 0.32 / 0.34 / 0.34 | 0.13 / 0.13 / 0.13 | |
| RingerMode, Doze, PowerSave, OnOff, WirelessState | ≤ 0.13 | ≤ 0.03 | rare events |

Source for the whole table: [LOCAL-INV / inv_table.txt and inv_cats.txt](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/inv_table.txt). Fitbit sampling and D-2 HR participant count (77) agree with [docs/PROJECT.md §5.1](/Users/clement/Hanyang/Harmony/docs/PROJECT.md).

- `Fitness-*` files look like Google-Fit-style phone data (activity names still/walking/in_vehicle/biking/running, 30-s step intervals): daily step totals correlate with Fitbit daily steps at r = 0.82 (D-2, 2,157 participant-days) and 0.88 (D-3, 3,098 participant-days), with a median Fitness/Fitbit ratio of 0.71 and 0.74 — [LOCAL-INV](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/inv_cats.txt)
- EmoPhone has no sleep stream; the paper's sleep features (Sleep#Duration, Onset, Midpoint) are derived from screen events over 21:00 (previous day) to 14:00 — [arXiv:2609.16581 App. A.7.3](https://arxiv.org/html/2609.16581)

**iOS / watchOS equivalents available to a third-party app**
- HealthKit `physicalEffort` (METs, recorded automatically by Apple Watch) exists from iOS 17 / watchOS 10 — [Apple: physicalEffort](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/physicaleffort)
- HealthKit `timeInDaylight` (cumulative time in daylight) exists from iOS 17 / watchOS 10 — [Apple: timeInDaylight](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/timeindaylight)
- `CMMotionActivityManager` reports walking / running / vehicle / stationary and can query past activity; "the system stores only the last seven days worth of activity data at most" — [Apple: CMMotionActivityManager](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [queryActivityStarting](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/queryactivitystarting(from:to:to:withhandler:))
- `CMPedometer` gives the phone's historic step counts and distance — [Apple: CMPedometer](https://developer.apple.com/documentation/coremotion/cmpedometer)
- Screen Time data (`DeviceActivityReport`) runs in a sandboxed extension that "prevents your extension from making network requests or moving sensitive content outside the extension's address space"; it needs Family Controls authorization — [Apple: DeviceActivityReport](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport), [DeviceActivity](https://developer.apple.com/documentation/deviceactivity)
- `CXCallObserver` only manages "a list of active calls" (no history) — [Apple: CXCallObserver](https://developer.apple.com/documentation/callkit/cxcallobserver)
- Proximity monitoring is a `UIDevice` flag meant to be enabled only while the app needs it; battery level is readable only once battery monitoring is enabled in the running app — [Apple: isProximityMonitoringEnabled](https://developer.apple.com/documentation/uikit/uidevice/isproximitymonitoringenabled), [Apple: batteryLevel](https://developer.apple.com/documentation/uikit/uidevice/batterylevel)
- SensorKit exposes ambient light, device usage report, keyboard metrics, phone usage, messages usage, visits, on-wrist state, wrist temperature, pedometer, PPG and ECG, but reading it requires the `com.apple.developer.sensorkit.reader.allow` entitlement, obtained only by submitting a research study that Apple approves — [Apple: SensorKit](https://developer.apple.com/documentation/sensorkit), [Apple: SRSensor](https://developer.apple.com/documentation/sensorkit/srsensor), [Apple: SensorKit entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.sensorkit.reader.allow)
- `CMSensorRecorder` can record accelerometer data for later analysis (watchOS 2+) — [Apple: CMSensorRecorder](https://developer.apple.com/documentation/coremotion/cmsensorrecorder)

### Inferences
- Feasibility table (yes / partial / no for a normal App Store app; "no" without a citation means no public API found, which is an inference):

| EmoPhone stream (unused unless noted) | What it measures | On-device equivalent | Verdict |
|---|---|---|---|
| Fitbit-HeartRate (used) | HR 1 Hz | HealthKit heartRate, ~1 / 4-5 min on Apple Watch (§6.4) | yes (sparser) |
| Fitbit-StepCount (used) | steps/min | HealthKit stepCount | yes |
| Fitbit-Calorie | kcal/min, level 0-3, METs | HealthKit activeEnergyBurned; physicalEffort (METs, iOS 17+) | yes |
| Fitbit-Distance | m/min | HealthKit distanceWalkingRunning | yes, but nearly a rescaled copy of steps |
| Fitness-* (D-2, D-3) | phone activity segments, steps, kcal, distance | CMPedometer + CMMotionActivityManager (7-day history) | yes (iPhone must be carried) |
| ActivityEvent / ActivityTransition | activity-type confidences / transitions | CMMotionActivityManager (stationary, walking, running, automotive, cycling, confidence) | yes |
| Location | GPS (longitude offset per person) | Core Location (needs "Always" permission for background) | partial: technically yes, heavy privacy cost; only relative features (radius, places, time away) transfer |
| ScreenEvent | screen on/off/unlock | none outside SensorKit (deviceUsageReport) | no |
| AppUsageEvent, InstalledApp | foreground apps, categories | Screen Time data sandboxed in report extension | no |
| NotificationEvent | notifications of other apps | none | no |
| KeyEvent | typing dynamics | SensorKit keyboardMetrics only | no |
| CallEvent / MessageEvent | call/SMS logs | CXCallObserver = active calls only; SensorKit phone/messages usage only | no |
| Light | ambient lux | SensorKit only; HealthKit timeInDaylight as a coarse daily proxy | no (proxy: partial) |
| Proximity (D-2) | near/far | UIDevice proximity while app is foreground | no |
| BatteryEvent / ChargeEvent | level, charging | UIDevice battery while app runs (no history) | partial (current value only) |
| WifiScan / BluetoothScan | nearby APs / devices | no Wi-Fi scan API; BLE scan limited | no |
| DataTraffic, RingerMode, Doze, PowerSave, OnOff, WirelessState | system states | none or current-value only | no |

- The streams that are both available on iOS and plausibly informative for "more activated than usual" are motion-activity type (walking / vehicle / still just before the moment), calories/METs (intensity, not just step count), and the Apple Watch `physicalEffort`. All of these are physical-activity proxies strongly tied to steps and HR, which the model already has, so the expected gain is small; it is cheap to test because ActivityEvent and Fitbit-Calorie have ≥ 0.90 ESM coverage in D-1 and D-3.
- An important mismatch to keep in mind if activity type is added: EmoPhone's activity recognition and `Fitness-*` come from the phone, and the app would use the iPhone too (CoreMotion), so the source matches; but the iPhone must be carried, otherwise the value is unknown (Unknown is not zero).
- Most of EmoPhone's "richness" (screen, apps, notifications, keyboard, social, light, Wi-Fi/BT) cannot be used by Harmony at inference time; training on it would produce a model the app cannot feed.
- PROJECT.md §5.1 should be corrected: D-3 does contain the four `Fitness-*` files (but not Light.csv, which PROJECT.md does not mention as missing).

### Gaps
- The paper does not document the `Fitness-*` or `Proximity` files; their exact source (Google Fit API on the phone vs. Fitbit sync) is not stated anywhere I found. The 0.71-0.74 step ratio and the activity labels suggest phone-based Google Fit data, but that is an inference.
- No Apple document was fetched for Wi-Fi scanning, ringer mode, screen-lock events or per-interval data traffic; "no API" for those rests on the absence of a public API (and on SensorKit being the only documented route for screen/device usage).
- How often Apple Watch records `HKHeartbeatSeriesSample` / SDNN outside Breathe sessions was not measured; PROJECT.md only reports that SDNN is read.

## Q2. Which ESM label items exist, on what scales, which are used, and is a multi-output model (arousal + valence) meaningful?

### Takeaway
Every wave has valence, arousal and stress (7 points), plus disturbance; D-1/D-2 add attention, mental load, duration and change items; D-3 adds 8 custom affect adjectives (not PANAS). Harmony uses only arousal. About 80% of the variance of valence and arousal is within-person (ICC ≈ 0.18–0.22), and within a person valence and arousal correlate only r ≈ 0.27–0.28 (binary phi 0.17–0.25), so valence is a distinct second target that maps naturally to song positivity; stress is mostly the negative of valence (within-person r −0.42 to −0.54) and nearly unrelated to arousal.

### Cited Findings
- Item lists (header lines): D-1 `pcode, actualTriggerTime, reactionTime, responseTime, valence, arousal, stress, duration, attention, disturbance, mental, change`; D-2 adds `intendedTriggerTime` and replaces `change` with `valenceChange, arousalChange`; D-3 `pcode, intendedTriggerTime, actualTriggerTime, reactionTime, responseTime, happy, relaxed, cheerful, content, sad, anxious, depressed, angry, valence, arousal, stress, disturbance` (no attention, mental, duration, change) — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt); consistent with [docs/PROJECT.md §5.1](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- Scales (paper): valence "very negative → very positive", arousal "very calm → very excited", stress "not stressed at all → very stressed", attention "very bored → very engaged", disturbance = task disturbance, mental = mental load of the ongoing task, duration = duration of the current emotional state in minutes (0–60 / N/A), change = emotion change while answering; D-2 ChangedValence/ChangedArousal = state immediately after answering; D-3 adjectives "custom, non-standardized affect-intensity" items 0–6, "not the original PANAS/PANAS-X"; D-3 stress and disturbance rescaled to 0–6 — [arXiv:2609.16581 Tables 11–13, §3.4, App. A.3.3](https://arxiv.org/html/2609.16581)
- Observed: all 7-point items take 7 distinct values (−3..+3; D-3 0..6). `duration` reaches 540 (D-1) and 1,680 (D-2) min, beyond the documented 0–60 range. Item counts: every item non-null in all responses except `duration` (10,087 / 21,019) — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt)
- Responses per participant: median 92 (D-1), 213 (D-2), 206 (D-3); paper: 6.70 / 6.99 / 7.03 responses per active day from 15 / 12 / 10 prompts sent per day — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt), [arXiv:2609.16581 Table 2](https://arxiv.org/html/2609.16581)
- Means / SD / ICC(1) (between-person share; D-3 rescaled −3..+3):

| Item | D-1 mean (SD), ICC | D-2 mean (SD), ICC | D-3 mean (SD), ICC |
|---|---|---|---|
| valence | 0.67 (1.31), 0.219 | 0.68 (1.20), 0.207 | 0.43 (1.42), 0.194 |
| arousal | −0.18 (1.55), 0.185 | −0.21 (1.47), 0.176 | −0.59 (1.67), 0.181 |
| stress | −0.40 (1.66), 0.264 | −0.26 (1.60), 0.215 | −0.67 (1.72), 0.343 |
| disturbance | 0.13 (1.79), 0.305 | 0.31 (1.64), 0.230 | −0.06 (1.98), 0.459 |
| attention | 0.32 (1.49), 0.138 | 0.41 (1.43), 0.184 | – |
| mental | −0.09 (1.63), 0.253 | −0.23 (1.58), 0.200 | – |
| duration (min) | 26.0 (21.9), 0.324 | 23.6 (20.8), 0.305 | – |
| change / valenceChange / arousalChange | −0.04 (0.97), 0.308 | 0.42 (1.17), 0.214 / −0.25 (1.34), 0.228 | – |
| D-3 happy / relaxed / cheerful / content | | | ICC 0.307 / 0.300 / 0.248 / 0.257 |
| D-3 sad / anxious / depressed / angry | | | ICC 0.447 / 0.404 / 0.433 / 0.432 (means −1.1 to −2.0 on −3..+3: floor-heavy) |

  Source: [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt)
- Correlations among valence, arousal, stress (pooled / within-person, person-mean centred): D-1 V–A 0.28 / 0.28, V–S −0.35 / −0.42, A–S 0.15 / 0.04; D-2 V–A 0.24 / 0.27, V–S −0.45 / −0.48, A–S 0.08 / −0.00; D-3 V–A 0.26 / 0.28, V–S −0.51 / −0.54, A–S −0.15 / −0.16 — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt). The paper reports the same pattern with Spearman (V–S strengthening D-1→D-3, A–S from weak positive to ≈0/negative, V–A weakly positive) — [arXiv:2609.16581 App. B.2](https://arxiv.org/html/2609.16581)
- Other within-person links: attention–arousal 0.39 (D-1), 0.40 (D-2); mental–stress 0.28 / 0.42; valenceChange–valence 0.70 and arousalChange–arousal 0.66 (D-2, near-duplicates); duration ≈ 0 with everything — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt)
- D-3 adjectives vs core labels (within-person): happy / cheerful / content r ≈ 0.60–0.61 with valence and 0.27–0.36 with arousal; relaxed 0.39 with valence, −0.07 with arousal; anxious 0.54 and depressed 0.48 with stress — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt)
- Binary "above own mean" labels (the Harmony rule): base rates arousal 0.475 / 0.459 / 0.426, valence 0.538 / 0.579 / 0.563, stress 0.454 / 0.466 / 0.451; phi(arousal_hi, valence_hi) 0.248 / 0.214 / 0.166; phi(arousal_hi, stress_hi) 0.029 / −0.002 / −0.106; phi(valence_hi, stress_hi) −0.227 / −0.306 / −0.343. Quadrant shares (D-1): low A–low V 0.30, low A–high V 0.22, high A–low V 0.16, high A–high V 0.32 — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt)
- Response stickiness: 41–45% of arousal answers and 45–54% of valence answers equal the participant's own modal value; ≤ 5% of participants have a within-person SD < 0.5 — [LOCAL-ESM](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/esm.txt)
- The queue currently uses one state value (e0) against target energy, and positivity only as a penalty (+0.2 if positivity < 0.5 for Stress/Low energy) — [docs/PROJECT.md §8](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)

### Inferences
- A second output for valence ("more or less positive than usual") is statistically meaningful: it carries mostly within-person variance (like arousal) and is only weakly tied to arousal, so it adds information rather than repeating the arousal output. It matches the songs' positivity score, which the queue now treats only as a penalty.
- Stress is not a good third output: within a person it is largely "low valence" (r up to −0.54) and almost independent of arousal; a valence output covers most of what a stress output would give, and stress is the hardest label cross-user (Q3).
- Attention / mental load (D-1, D-2 only) could serve as auxiliary training targets in a multi-task network, but with logistic regression "multi-output" just means separate models, and they are missing in D-3. `duration`, `change`, `valenceChange`, `arousalChange` are not useful targets (≈ 0 correlations or near-duplicates of the core items).
- D-3 adjectives are named emotions; even as internal targets they would sit awkwardly with the "never show a named emotion" rule, and they exist only for 106 participants of one wave.
- Labels are coarse and sticky (≈ 45% at each person's mode), which caps achievable AUROC whatever the inputs.

### Gaps
- No predictability of valence with Harmony's own 13 features has been measured (no training was allowed in this task); the only valence predictability evidence is the paper's (Q3).

## Q3. What does the EmoPhone paper report as benchmarks, and does the full multimodal feature set beat wearable-only?

### Takeaway
The paper (Zhang, Park, Kang et al., KAIST, arXiv 2609.16581, 15 Sep 2026) benchmarks 4 shared labels (valence, arousal, stress, disturbance) plus 8 D-3 adjectives in three settings with ~8,000–10,600 phone + Fitbit features per wave and dozens of models (XGBoost, LightGBM, tabular nets, DG, UDA). Best AUROCs are modest: within-user temporal 0.60–0.63, cross-user within-wave 0.55–0.59, cross-wave 0.52–0.56. The paper reports **no** wearable-only vs. multimodal ablation, so the question cannot be answered from it; indirectly, Harmony's 13 time + Fitbit features reach the same range as the paper's thousands of features on arousal.

### Cited Findings
- Title/date: "EmoPhone: A Multi-Wave Dataset for In-the-Wild Mobile and Wearable Affect Sensing", submitted 2026-09-15; abstract: supervised baselines best in the temporal setting, UDA strongest within-wave, DG strongest cross-wave "although its margin over strong baselines is modest" — [arXiv:2609.16581 abstract](https://arxiv.org/abs/2609.16581)
- 297 participant-wave records from 282 distinct people; "14 participants are confirmed to recur across waves (13 in exactly two waves, one in all three)"; cross-wave splits are therefore "not fully identity-disjoint" — [arXiv:2609.16581 §3.1, Table 3](https://arxiv.org/html/2609.16581). PROJECT.md still says recurrence is unknown and pending confirmation — [docs/PROJECT.md §5.1, §6.6](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- Settings: temporal = per-user chronological 60/20/20 within the first 30 days (baselines only); within-wave = user-grouped stratified 5-fold; cross-wave = leave-one-wave-out, 6 one-source + 3 two-source directions, on the intersection of features — [arXiv:2609.16581 Table 3, §4.4–4.6](https://arxiv.org/html/2609.16581)
- Labels: HIGH/LOW "use the label-wise median of the labeled training data only" (per-user median only in the temporal setting; training participants / source waves otherwise) — [arXiv:2609.16581 §4.3, App. A.7.6](https://arxiv.org/html/2609.16581). MLP-backbone arousal prevalence of HIGH is 0.31–0.34 — [App. C, Table 30b](https://arxiv.org/html/2609.16581)
- Features: 8,037 (D-1), 10,122 (D-2), 10,581 (D-3) columns, 4,890 shared; windows ImmediatePast_15 and _30 plus six 3-hour epochs for today and yesterday; descriptors mean, SD, skewness, kurtosis, median, binned entropy, etc.; sleep from screen events; missing numeric values set to 0.0; six categories: social (calls, messages), physical activity (activity recognition + Fitbit steps/distance/calories), context/mobility (location, traffic), phone usage (apps, notifications, device events, battery, keystrokes), physiological (Fitbit HR), wireless (Wi-Fi, Bluetooth) — [arXiv:2609.16581 App. A.7.2–A.7.7, Tables 18, 20](https://arxiv.org/html/2609.16581)
- Within-user temporal best AUROC: stress 0.627 (XGB), arousal 0.609 (XGB), valence 0.601 (XGB), disturbance 0.555; D-3 adjectives 0.548 (depressed) to 0.673 (angry) — [arXiv:2609.16581 Table 4](https://arxiv.org/html/2609.16581)
- Within-wave cross-user family-best (mean over waves; baseline / DG / UDA): stress 0.549 / 0.558 / 0.558; arousal 0.576 / 0.574 / 0.587; valence 0.560 / 0.561 / 0.577; disturbance 0.543 / 0.550 / 0.563. Cross-wave: stress 0.525 / 0.525 / 0.522; arousal 0.552 / 0.564 / 0.538; valence 0.540 / 0.541 / 0.525; disturbance 0.535 / 0.537 / 0.532 — [arXiv:2609.16581 Table 5](https://arxiv.org/html/2609.16581)
- Per-wave within-wave arousal (baseline / DG / UDA family-best): D-1 0.557 / 0.546 / 0.576; D-2 0.562 / 0.567 / 0.573; D-3 0.610 / 0.609 / 0.611; plain MLP arousal D-1 0.549 [95% CI 0.529–0.568], D-2 0.544, D-3 0.605. Valence: D-1 0.558 / 0.551 / 0.570; D-2 0.545 / 0.554 / 0.575; D-3 0.576 / 0.579 / 0.586 — [arXiv:2609.16581 App. C Table 30a–b](https://arxiv.org/html/2609.16581)
- DG/UDA beat their MLP backbone but "neither family consistently exceeds the strongest supervised model"; in cross-wave "neither family exceeds the tree-based supervised models" — [arXiv:2609.16581 §5.2–5.3, §6.1](https://arxiv.org/html/2609.16581)
- No modality ablation: the paper text contains no "ablation", "wearable-only", "phone-only" or feature-importance analysis (full-text search of the HTML) — [arXiv:2609.16581 HTML](https://arxiv.org/html/2609.16581)
- Harmony, same data, 13 or fewer features: v0 per wave (CV by participant) arousal 0.572 / 0.576 / 0.598 (D-1 / D-2 / D-3), time + HR 0.576 / 0.570 / 0.593, time only 0.530 / 0.538 / 0.542; v1 CV D-1+D-2 0.563, held-out D-3 0.576; gradient boosting 0.558 — [docs/PROJECT.md §6.5](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)

### Inferences
- On arousal, Harmony's time + Fitbit model (0.57–0.60 within wave, 0.576 cross-wave to D-3) sits at the level of the paper's best models built on ~5,000–10,000 phone + wearable features (0.55–0.61 within wave, 0.55–0.56 cross-wave). This is indirect evidence that the phone streams add little for cross-user arousal — but the targets differ (paper: global training median, which mixes between-person level; Harmony: above own mean), so the numbers are not strictly comparable.
- The jump to 0.60–0.63 appears only in the within-user temporal setting, where the model is trained on the same person's earlier labels. If anything raises Harmony's accuracy, it is personal labels (e.g., the app's feedback) more than extra sensors or outputs; this conflicts with the existing decision not to train per user (§3), so it would need a team decision.
- Valence is predictable at about the same level as arousal within a wave (0.56–0.59) but drops more across waves (0.54); a valence output would likely be weaker than the arousal one.
- The 14 recurring participants make the D-3 hold-out very slightly non-independent; with ≤ 14 of 106 D-3 people possibly seen in training, the effect on 0.576 is likely small, but PROJECT.md §5.1/§6.6 should be updated with the paper's statement.

### Gaps
- Whether phone + wearable features beat wearable-only on EmoPhone is not reported; answering it would require training (out of scope here). The feature-extraction pipeline is reference [63] of the paper; it was not fetched.
- Several numbers inside the paper's prose (e.g., Spearman values in App. B.2) were rendered as math and lost in text extraction; table values above were readable.

## Q4. What does UC Irvine offer beyond what is used, is it better or worse than EmoPhone, and can it serve a narrower purpose?

### Takeaway
The local UC Irvine copy (24 IDs) contains far more physiology than EmoPhone (Oura sleep stages, nightly RMSSD, readiness, temperature, respiration; Samsung PPG at ~25 s, 32 HRV metrics per 1 and 5 min, IMU, barometer, rich pedometer) but only one PANAS rating of "today" per day (3,949 responses) and no arousal item. It is a worse training set for a momentary, within-person target, and in a quick aggregate check measured sleep and nocturnal HRV barely co-vary with same-day affect within a person (|r| ≤ 0.085).

### Cited Findings
- Files per participant directory (n directories with the file; total size): `ema/daily.csv` 24, `ema/weekly.csv` 22, `assessment/surveys.csv` 24, `assessment/events.csv` 12, `oura/activity.csv` 24, `oura/activity_level.csv` 23, `oura/heart_rate.csv` 24, `oura/readiness.csv` 24, `oura/sleep.csv` 23, `oura/sleep_hypnogram.csv` 23, `personicle/personicle.csv` 23, `samsung/awake_times.csv` 24, `samsung/hrv_1min.csv` 22, `samsung/hrv_5min.csv` 21, `samsung/imu.csv` 24 (20.0 GB), `samsung/pedometer.csv` 24, `samsung/ppg.csv` 24 (10.8 GB), `samsung/pressure.csv` 24 (4.6 GB) — [LOCAL-UCI](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/uci.txt)
- Column content (README): Oura `heart_rate.csv` = 5-min HR and RMSSD during sleep only; `sleep.csv` = sleep score and contributors, duration, awake/light/REM/deep seconds, onset latency, efficiency, restlessness, hr_average, hr_lowest, rmssd, breath_average, temperature_delta, bedtime start/end; `sleep_hypnogram.csv` = 5-level stages; `readiness.csv` = readiness score and sub-scores (HRV balance, resting HR, recovery index, temperature…); Samsung `hrv_1min/5min` = 32 time, frequency and non-linear HRV metrics (meanNN, SDNN, RMSSD, pNN50, LF, HF, LF/HF, SD1/SD2…); `imu.csv` = 3-axis accelerometer + gyroscope; `pressure.csv` = barometric hPa; `pedometer.csv` = cumulative total/walking/running steps, distance, kcal, speed, step frequency, state — [data/uci/README.md](/Users/clement/Hanyang/Harmony/data/uci/README.md)
- Also present: `oura/activity.csv` (daily scores, steps, MET minutes), `oura/activity_level.csv` (MET class time series), `personicle/personicle.csv` (activity names, venue type, time band, step count), `assessment/surveys.csv` (monthly BDI-II, BSI, GAD-7, loneliness, relationship scales…), `assessment/events.csv`; daily EMA also has `covid_worried`, `health_worried` and a free-text field available only on request — [LOCAL-UCI headers](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/uci.txt), [data/uci/README.md](/Users/clement/Hanyang/Harmony/data/uci/README.md)
- Used by Harmony: daily EMA six items (Active, Alert, Excited, Enthusiastic, Jittery, Nervous) averaged as an activation score; Samsung PPG `hr` (+ Oura sleep HR merged); Samsung pedometer `num_total_steps`; Oura `sleep.total` only as a control. Explicitly ignored: the other 14 PANAS items, worries, weekly EMA, hrv_1min/5min, awake_times, imu, pressure, Oura activity/activity_level/readiness/hypnogram, Oura RMSSD — [docs/PROJECT.md §5.3, §6.2](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- Coverage: per-participant share of local dates with ≥ 1 measurement in 08–24 h / 00–06 h: PPG 0.975 / 0.650, HRV 1 min 0.528 / 0.351, Oura HR 0.313 / 0.511; an Oura period exists for 3,061 of 3,559 nights with an EMA (0.860); the HR-based estimated sleep does not correlate with Oura measured sleep (r = −0.001, 1,074 nights) — [docs/PROJECT.md §5.3](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- Oura availability (share non-missing and non-zero): sleep.csv 3,997 rows / 23 participants, nearly all fields 1.00 (temperature_delta 0.98); readiness 3,997 rows, score_hrv_balance only 0.63 — [LOCAL-UCI](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/uci.txt)
- Daily EMA: 3,949 responses, 24 participants, median 180 each; 20 PANAS items 0–100 (README labels "very slightly … extremely"); item ICC(1) 0.21 (Irritable) to 0.54 (Strong); composites ICC: activation (6 items) 0.444, PA 0.617, NA 0.413, PA−NA 0.559. Weekly EMA: 605 rows, 22 participants, adds `week_felt` 0–100 (ICC 0.230) — [LOCAL-UCI](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/uci.txt)
- Within-person correlations (daily): activation–PA 0.75, activation–NA 0.39, PA–NA −0.04, activation–(PA−NA) 0.22 — [LOCAL-UCI](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/uci.txt)
- Measured sleep / nocturnal HRV vs same-day affect (3,315 EMA with an Oura night ending ≤ 18 h before, 84%, 23 participants). Within-person r with activation / PA / NA: total sleep −0.080 / −0.045 / −0.085; efficiency −0.019 / −0.023 / 0.009; RMSSD −0.040 / −0.035 / −0.043; lowest HR 0.013 / 0.010 / 0.034; deep −0.052 / −0.037 / −0.071; REM −0.079 / −0.048 / −0.062; respiration −0.050 / −0.046 / 0.030; temperature −0.011 / −0.012 / 0.000; sleep score −0.057 / −0.034 / −0.073. Pooled r were larger (e.g., RMSSD–NA −0.279, restless–activation −0.203), i.e. mostly between-person. Naive |r| for p < .05 at this n is 0.034, ignoring clustering — [LOCAL-UCISLEEP](/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/out/uci_sleep.txt)
- Results already measured: within-UCI CV 13 features 0.538, time only 0.510, time + HR 0.503; EmoPhone model on UCI 0.494–0.496; UCI model on EmoPhone D-3 0.528; decision 22 Nov 2026: keep EmoPhone, do not integrate UCI — [docs/PROJECT.md §3, §6.5](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- README describes 21 students; the local copy has 24 `par_N` directories; no duplicated files or shared EMA instants between IDs were found — [docs/PROJECT.md §5.3](/Users/clement/Hanyang/Harmony/docs/PROJECT.md)
- Apple Watch equivalents for the UCI extras: sleep stages via `sleepAnalysis` core/deep/REM samples; nightly wrist temperature (Series 8 / Ultra; one value per night); respiratory rate and resting HR recorded automatically; HRV only as SDNN; raw beat-to-beat via `HKHeartbeatSeriesSample` (iOS 13+) — [Apple: HKCategoryValueSleepAnalysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis), [Apple: appleSleepingWristTemperature](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature), [Apple: respiratoryRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/respiratoryrate), [Apple: restingHeartRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate), [Apple: heartRateVariabilitySDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn), [Apple: HKHeartbeatSeriesSample](https://developer.apple.com/documentation/healthkit/hkheartbeatseriessample)

### Inferences
- As a main training set UC Irvine is worse than EmoPhone for Harmony: 13× fewer labels (3,949 vs 53,139), one "today" rating per day instead of momentary prompts, no arousal item (activation built from PANAS, which also loads on NA), a much larger between-person share (activation ICC 0.44 vs arousal 0.18 in EmoPhone, so less within-person variance for a "vs your own average" target), US cohort, Samsung/Oura devices.
- Narrow purpose: UC Irvine is the only local data with measured sleep, sleep stages, respiration, temperature and HRV, all of which an Apple Watch also records. The aggregate check suggests these nightly measures carry little within-person signal for same-day affect (all |r| ≤ 0.085), which supports keeping sleep minimal in the model and keeping HRV out. A proper test would add these as features in the existing UCI GroupKFold protocol; that is training and was not done here.
- Samsung 1-min HRV has no Apple Watch counterpart at that density (Apple gives sporadic SDNN; beat-to-beat series exist but are sparse), so features built on it would not transfer to the app.
- `week_felt`, worries, monthly surveys and Personicle self-logs have no on-device equivalent without asking the user, and the clinical scales (BDI-II, GAD-7) would raise medical-claim issues.

### Gaps
- The Data in Brief article (Labbaf et al. 2024) was not fetched; descriptions come from the local README. The 21 vs 24 participant discrepancy remains unexplained.
- Frequency of Apple Watch heartbeat-series samples (needed to compute RMSSD) was not measured on a real watch.

## Q5. Which published models does the report (docs/main.tex) compare Harmony against?

### Takeaway
The report compares the state model only to EmoPhone's own benchmark, and claims parity ("0.573, the level of the best published models on this wave, which use thousands of phone and watch features"); that holds numerically for D-1 arousal, but the report misdescribes the benchmark's labels as "relative to each person's average".

### Cited Findings
- main.tex: "Our four-input model reaches an AUROC of 0.573, the level of the best published models on this wave, which use thousands of phone and watch features" — [docs/main.tex l. 450](/Users/clement/Hanyang/Harmony/docs/main.tex)
- main.tex: "EmoPhone and its benchmark provide the training data and an evaluation method: features from the minutes before each mood answer, normalisation per person, and labels relative to each person's average" — [docs/main.tex l. 326](/Users/clement/Hanyang/Harmony/docs/main.tex)
- The paper's within-wave and cross-wave labels use the median of the training participants' labels, and only the temporal setting uses a per-user median; standardization is fitted on training data, not per person — [arXiv:2609.16581 §4.3, App. A.7.6, Table 3](https://arxiv.org/html/2609.16581)
- Paper D-1 within-wave arousal: 0.557 (best baseline), 0.546 (best DG), 0.576 (best UDA, MCD) — [arXiv:2609.16581 App. C Table 30a](https://arxiv.org/html/2609.16581)
- Related-software table compares products from their public pages, not models — [docs/main.tex l. 122–127](/Users/clement/Hanyang/Harmony/docs/main.tex)
- Bibliography entry: P. Zhang, M. Park, S. Kang et al., arXiv:2609.16581, 2026; Dataverse doi:10.7910/DVN/QGRVU8 — [docs/main.tex l. 600](/Users/clement/Hanyang/Harmony/docs/main.tex)

### Inferences
- The parity claim is fair in number (0.573 vs 0.557–0.576 on D-1) but compares different targets; the sentence at l. 326 should say the benchmark uses training-median labels and that Harmony uses a within-person target. On D-3 the paper's best (0.61) is above Harmony's v0 within-D-3 model (0.598) and its v1 cross-wave result (0.576), though the paper's cross-wave arousal best (0.564, IRM, averaged over nine directions) is below 0.576.

### Gaps
- No other published model (e.g., on other datasets) is compared in the report's results section as far as the grep of main.tex showed.

## Summary for the report writer (assessment)
- **Is EmoPhone's full potential used?** In label terms no (only arousal of ≥ 4 shared items; valence unused). In sensor terms the team uses the two streams that matter most and that the app can reproduce; most unused streams (screen, apps, notifications, keyboard, calls, light, Wi-Fi/BT) are not obtainable by an App Store iOS app (only via SensorKit research entitlement). Usable-on-device but unused: motion-activity type, calories/METs, distance, phone steps (`Fitness-*`), location-derived mobility.
- **Would more inputs help?** Weak evidence against large gains: the paper's 5,000–10,000-feature models land at the same AUROC as Harmony's 13 features. Small, testable additions with on-device equivalents: activity type and METs/calories (≥ 0.90 ESM coverage in D-1/D-3).
- **Would more outputs help?** A valence output is meaningful (mostly within-person variance, weakly correlated with arousal, maps to song positivity) but likely weaker (paper cross-wave valence 0.54). Stress is largely redundant with low valence and hard to predict cross-user.
- **Would UC Irvine be better?** No as a training set; yes as a narrow test bed for measured sleep / HRV, where a first aggregate check shows near-zero within-person association with same-day affect.
- **Documentation fixes surfaced:** PROJECT.md §5.1 (D-3 does have `Fitness-*`; paper confirms 14 recurring participants) and main.tex l. 326 (benchmark labels are training-median, not per-person).
