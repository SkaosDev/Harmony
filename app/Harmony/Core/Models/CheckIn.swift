import Foundation
import SwiftData

/// One answer to "Energy right now?" (TODO 6.7, design v2 §6). Treated as health data: it stays
/// on the phone, goes into the JSON export and is removed by "Delete everything" and by "Reset
/// what Harmony learned". Never shown back as an emotion.
@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var answeredAt: Date
    var channel: CheckInChannel
    /// When the notification was sent; nil for an answer given in the app.
    var promptedAt: Date?
    /// −3…+3 (the in-app scale); a notification answer is −2 (Low), 0 (Medium) or +2 (High).
    var energy: Int
    /// −3…+3, optional question of the in-app sheet only.
    var pleasantness: Int?
    /// Logit of the common model at the answer, by the mode rule of the shipped model (§6.8).
    /// Nil until it is computed: an answer given on the lock screen gets it at the next unlock.
    var zEnergy: Double?
    var zPleasantness: Double?
    var estimateMode: EstimateMode?
    /// "Above your usual": the answer is above the mean of the answers of the 14 days before,
    /// with at least 5 of them; nil otherwise. Fixed at the answer.
    var labelEnergy: Bool?
    var labelPleasantness: Bool?
    /// False for an answer given during a queue or less than 60 min after it (the music
    /// influences the answer, design v2 §4.4).
    var usableForLearning: Bool
    /// σ(z) and σ(z + b) computed before this answer was added: the chronological evaluation
    /// of the pilot (D8). Nil until `zEnergy` is known.
    var pCommonBefore: Double?
    var pPersonalBefore: Double?
    /// Day of use, 1 on the first day (`CheckInRecorder.firstDayKey`).
    var dayOfUse: Int

    init(id: UUID = UUID(), answeredAt: Date, channel: CheckInChannel, promptedAt: Date? = nil,
         energy: Int, pleasantness: Int? = nil, zEnergy: Double? = nil, zPleasantness: Double? = nil,
         estimateMode: EstimateMode? = nil, labelEnergy: Bool? = nil, labelPleasantness: Bool? = nil,
         usableForLearning: Bool, pCommonBefore: Double? = nil, pPersonalBefore: Double? = nil, dayOfUse: Int) {
        self.id = id
        self.answeredAt = answeredAt
        self.channel = channel
        self.promptedAt = promptedAt
        self.energy = energy
        self.pleasantness = pleasantness
        self.zEnergy = zEnergy
        self.zPleasantness = zPleasantness
        self.estimateMode = estimateMode
        self.labelEnergy = labelEnergy
        self.labelPleasantness = labelPleasantness
        self.usableForLearning = usableForLearning
        self.pCommonBefore = pCommonBefore
        self.pPersonalBefore = pPersonalBefore
        self.dayOfUse = dayOfUse
    }
}

/// Where the answer was given: the in-app sheet (opened from Home) or the notification.
nonisolated enum CheckInChannel: String, Codable {
    case sheet, notification
}
