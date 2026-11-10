import Foundation
import SwiftData

/// One night of watch sleep, over the 21:00 → 12:00 window (TODO 1.10, PROJECT.md §10).
/// Unknown is not zero: a night without enough watch data has nil sleep, never 0 minutes.
@Model
final class NightSummary {
    /// Start of the day on which the window ends (the wake-up day), local time. One row per night.
    @Attribute(.unique) var date: Date
    /// Minutes asleep (Apple Watch, asleep* values only); nil if the night is unknown.
    var sleepMinutes: Double?
    /// End of the main sleep; nil if the night is unknown.
    var sleepEnd: Date?
    /// Share of the window covered by heart-rate readings, 0…1 (watch worn).
    var wornFraction: Double

    init(date: Date, sleepMinutes: Double?, sleepEnd: Date?, wornFraction: Double) {
        self.date = date
        self.sleepMinutes = sleepMinutes
        self.sleepEnd = sleepEnd
        self.wornFraction = wornFraction
    }
}
