import Foundation

/// The situation highlighted on Home ("For you", TODO 3.8, FR5, PROJECT.md §8): Wake-up within
/// 2 hours after the end of last night's sleep; else Wind-down from 21:00 to 04:59; else Low
/// energy from 13:00 to 16:59 when the state is below 0.4; else none. Stress is never suggested:
/// the model is too weak on stress.
enum SituationSuggester {
    static let wakeUpHours = 2.0
    static let lowEnergyBelow = 0.4

    /// - Parameters:
    ///   - hoursSinceWake: the `hours_since_wake` feature; nil when last night is unknown.
    ///   - e0: the state the queue starts from (`QueueStart`, TODO 6.11).
    static func suggestion(at date: Date, hoursSinceWake: Double?, e0: Double, calendar: Calendar = .current) -> Situation? {
        if let hours = hoursSinceWake, hours >= 0, hours <= wakeUpHours { return .wakeUp }
        let hour = calendar.component(.hour, from: date)
        if hour >= 21 || hour < 5 { return .windDown }
        if (13..<17).contains(hour) && e0 < lowEnergyBelow { return .lowEnergy }
        return nil
    }
}
