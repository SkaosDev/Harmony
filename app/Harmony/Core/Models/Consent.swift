import Foundation
import SwiftData

/// The user's choice for one health signal (TODO 1.11). HealthKit never says whether reading
/// was refused, so this records what the user chose in the app.
@Model
final class Consent {
    var source: HealthSignal
    var granted: Bool
    var time: Date

    init(source: HealthSignal, granted: Bool, time: Date) {
        self.source = source
        self.granted = granted
        self.time = time
    }
}

/// The Apple Health data the app can read (PROJECT.md §10, design `V2-Sante`).
enum HealthSignal: String, Codable, CaseIterable {
    case heartRate, steps, sleep, hrv
}
