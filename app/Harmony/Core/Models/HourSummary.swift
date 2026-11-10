import Foundation
import SwiftData

/// One hour of watch data (TODO 1.9). Raw HealthKit samples are summarised here, then
/// dropped (PROJECT.md §11). Unknown is not zero: no watch data gives nil, never 0.
@Model
final class HourSummary {
    /// Start of the hour, local time. One row per hour.
    @Attribute(.unique) var hourStart: Date
    /// Mean heart rate (beats per minute); nil if no measurement in the hour.
    var meanHR: Double?
    /// Number of heart-rate measurements in the hour.
    var hrCount: Int
    /// Mean HRV (SDNN, ms); nil if no measurement. Used for explanations only, not by the model.
    var sdnnHRV: Double?
    /// Steps in the hour; nil if the watch was not worn (unknown), 0 if worn without steps.
    var steps: Int?

    init(hourStart: Date, meanHR: Double?, hrCount: Int, sdnnHRV: Double?, steps: Int?) {
        self.hourStart = hourStart
        self.meanHR = meanHR
        self.hrCount = hrCount
        self.sdnnHRV = sdnnHRV
        self.steps = steps
    }
}
