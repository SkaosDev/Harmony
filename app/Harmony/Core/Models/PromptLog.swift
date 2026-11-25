import Foundation
import SwiftData

/// One scheduled check-in notification (TODO 6.7, design v2 §6), for the answer rate. Its `id` is
/// the notification's identifier. A notification cancelled before it is sent leaves no row.
@Model
final class PromptLog {
    @Attribute(.unique) var id: UUID
    var scheduledAt: Date
    /// When iOS showed it, when the app could see it; nil otherwise.
    var deliveredAt: Date?
    /// Nil while waiting for an answer.
    var outcome: PromptOutcome?
    /// The `CheckIn` it gave.
    var checkInId: UUID?

    init(id: UUID = UUID(), scheduledAt: Date, deliveredAt: Date? = nil, outcome: PromptOutcome? = nil,
         checkInId: UUID? = nil) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.deliveredAt = deliveredAt
        self.outcome = outcome
        self.checkInId = checkInId
    }
}

/// `ignored`: the notification expired or was dismissed without an answer. "Not now" and
/// `ignored` are no information, never a low answer (design v2 §5.3).
nonisolated enum PromptOutcome: String, Codable {
    case answered, notNow, ignored
}
