import Foundation
import Testing
@testable import Harmony

/// TODO 3.7
@MainActor
struct ExplainerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func at(_ hour: Int, day: Int = 23) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: 10))!
    }

    private func reason(_ situation: Situation, e0: Double, hour: Int, mode: StateEstimate.Mode = .body,
                        sleep: Double? = nil, heartRate: Double? = nil, hrv: Double? = nil) -> String {
        Explainer.reason(situation: situation, e0: e0,
                         context: .init(date: at(hour), mode: mode, zSleep: sleep, zHeartRate: heartRate, zHRV: hrv),
                         calendar: calendar)
    }

    /// Words that name an emotion or a state of mind, or make a medical claim (NFR7).
    /// "calm" is allowed: it describes the songs, as in the design ("Calm songs first…").
    static let forbidden = [
        "happy", "happi", "sad", "angry", "anger", "anxious", "anxiety", "stress", "depress", "upset", "fear",
        "afraid", "scared", "nervous", "worr", "mood", "feel", "emotion", "joy", "cheer", "glad", "lonely",
        "excite", "panic", "tense", "tension", "frustrat", "irritat", "tired", "exhaust", "bored", "relax",
        "content", "pleasant", "unpleasant", "heal", "cure", "therap", "treat", "diagnos", "medic", "symptom",
        "disorder", "insomnia", "illness", "sick", "disease", "doctor", "wellness",
    ]

    @Test func exampleOfTheReport() {
        // FR11: "short night, morning: calm songs first, then more energy".
        #expect(reason(.wakeUp, e0: 0.2, hour: 7, sleep: -1.4) == "Short night, morning: calm songs first, then more energy.")
    }

    @Test func heartRateAndHrvAreSaidWhenFarFromUsual() {
        #expect(reason(.windDown, e0: 0.5, hour: 22, heartRate: 1.2, hrv: -1.0)
                == "Night, heart rate higher than usual, heart rate variability lower than usual: medium songs first, then a little calmer.")
        #expect(reason(.windDown, e0: 0.5, hour: 18, heartRate: -2, hrv: 1.5)
                == "Evening, heart rate lower than usual, heart rate variability higher than usual: medium songs first, then a little calmer.")
        // Close to the usual: nothing said.
        #expect(reason(.stress, e0: 0.8, hour: 14, sleep: 0.9, heartRate: 0.5, hrv: -0.99)
                == "Afternoon: energetic songs first, then calmer.")
    }

    @Test func timeOnlyQueueSaysOnlyTheTimeOfDay() {
        #expect(reason(.lowEnergy, e0: 0.4, hour: 15, mode: .timeOnly, sleep: -3, heartRate: 3, hrv: 3)
                == "Afternoon: medium songs first, then a little more energy.")
    }

    @Test func flatQueueStaysAtTheSameLevel() {
        #expect(reason(.windDown, e0: 0.1, hour: 23) == "Night: calm songs all the way.")
        #expect(reason(.wakeUp, e0: 0.9, hour: 6) == "Morning: energetic songs all the way.")
    }

    @Test func partsOfTheDay() {
        let names = (0..<24).map { Explainer.partOfDay(at($0), calendar: calendar) }
        #expect(names[4] == "night" && names[5] == "morning" && names[11] == "morning")
        #expect(names[12] == "afternoon" && names[16] == "afternoon" && names[17] == "evening")
        #expect(names[20] == "evening" && names[21] == "night" && names[0] == "night")
    }

    @Test func noReasonEverUsesAForbiddenWord() {
        let zs: [Double?] = [nil, -2, 0, 2]
        var reasons = Set<String>()
        for situation in Situation.allCases {
            for e0 in stride(from: 0.0, through: 1.0, by: 0.05) {
                for hour in 0..<24 {
                    for mode in [StateEstimate.Mode.body, .timeOnly] {
                        for sleep in zs { for heartRate in zs { for hrv in zs {
                            reasons.insert(reason(situation, e0: e0, hour: hour, mode: mode,
                                                  sleep: sleep, heartRate: heartRate, hrv: hrv))
                        } } }
                    }
                }
            }
        }
        for text in reasons {
            let words = text.lowercased().split { !$0.isLetter }
            for word in words {
                #expect(!Self.forbidden.contains { word.hasPrefix($0) }, "\(text)")
            }
        }
        #expect(reasons.count > 100)
    }

    @Test func hrvComparesTheLatestValueWithTheFourteenDaysBefore() {
        let now = at(10)
        // 7 days of HRV at 9:00 alternating 40 and 60 (mean 50, std ≈ 10.8), then 80 an hour ago.
        var hours = (1...7).map { (start: at(9, day: 23 - $0), hrv: $0 % 2 == 0 ? 40.0 : 60.0) }
        hours.append((start: at(9), hrv: 80))
        let z = try! #require(Explainer.hrvZ(hours: hours, now: now, calendar: calendar))
        #expect(z > 2)

        // Nothing in the last 6 hours: unknown.
        #expect(Explainer.hrvZ(hours: Array(hours.dropLast()), now: now, calendar: calendar) == nil)
        // Fewer than 7 days before: not ready.
        #expect(Explainer.hrvZ(hours: Array(hours.suffix(7)), now: now, calendar: calendar) == nil)
    }
}
