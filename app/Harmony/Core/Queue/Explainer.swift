import Foundation

/// The reason shown with a queue (TODO 3.7, FR11, PROJECT.md §8): fixed sentences, a context then
/// a plan, e.g. "Short night, morning: calm songs first, then more energy." Never an emotion word,
/// never a medical claim (NFR7): the context compares the watch data with the person's usual
/// values, the plan describes the songs.
enum Explainer {
    /// A z-score at least this far from 0 is worth saying ("higher than usual").
    static let notable = 1.0
    /// Below this energy a song is "calm", above `livelyFrom` it is "energetic".
    static let calmBelow = 0.35
    static let livelyFrom = 0.65
    /// A move toward the goal of at most this much is "a little".
    static let smallMove = QueueTargets.longGap
    /// No move below this.
    static let flat = 0.05

    /// What the reason says about the moment. Body values are nil when unknown.
    struct Context {
        var date: Date
        /// `.timeOnly`: the queue did not use the watch, so the reason only gives the time of day.
        var mode: StateEstimate.Mode
        /// `z_sleep_min`: last night's sleep against the person's usual nights.
        var zSleep: Double?
        /// `z_hr_30`: heart rate of the last 30 min against the usual.
        var zHeartRate: Double?
        /// Latest HRV against the usual (`hrvZ`).
        var zHRV: Double?
    }

    static func reason(situation: Situation, e0: Double, context: Context, calendar: Calendar = .current) -> String {
        var parts: [String] = []
        if context.mode == .body, let z = context.zSleep, abs(z) >= notable {
            parts.append(z < 0 ? "short night" : "long night")
        }
        parts.append(partOfDay(context.date, calendar: calendar))
        if context.mode == .body {
            if let z = context.zHeartRate, abs(z) >= notable {
                parts.append(z > 0 ? "heart rate higher than usual" : "heart rate lower than usual")
            }
            if let z = context.zHRV, abs(z) >= notable {
                parts.append(z > 0 ? "heart rate variability higher than usual" : "heart rate variability lower than usual")
            }
        }
        return capitalized(parts.joined(separator: ", ")) + ": " + plan(situation: situation, e0: e0)
    }

    /// "calm songs first, then more energy.", "medium songs first, then a little calmer.",
    /// "energetic songs all the way." (lower case: it follows the context in `reason`).
    static func plan(situation: Situation, e0: Double) -> String {
        let level = e0 < calmBelow ? "calm" : e0 > livelyFrom ? "energetic" : "medium"
        let move = QueueTargets.goal(e0: e0, situation: situation) - e0
        if abs(move) < flat { return "\(level) songs all the way." }
        let little = abs(move) <= smallMove ? "a little " : ""
        return "\(level) songs first, then \(little)\(move > 0 ? "more energy" : "calmer")."
    }

    static func partOfDay(_ date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "night"
        }
    }

    /// The latest hourly HRV (`HourSummary.sdnnHRV`) of the last 6 hours against the hourly HRVs
    /// of the 14 days before it, ready at 7 days (as the other references, §6). Nil = unknown.
    static func hrvZ(hours: [(start: Date, hrv: Double)], now: Date, calendar: Calendar = .current) -> Double? {
        let recent = hours.filter { $0.start <= now && $0.start > now - 6 * 3600 }
        guard let latest = recent.max(by: { $0.start < $1.start }) else { return nil }
        let earlier = hours.filter {
            $0.start < latest.start && $0.start >= latest.start - Double(BaselineCalculator.referenceDays) * 86400
        }
        let reference = BaselineCalculator.reference(earlier.map { ($0.hrv, calendar.startOfDay(for: $0.start)) },
                                                     minDays: BaselineCalculator.readyDays)
        return reference?.z(latest.hrv)
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
