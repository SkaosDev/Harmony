import Foundation
import SwiftData

/// A queue the app built and played (TODO 1.11, PROJECT.md §8).
@Model
final class QueueRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var situation: Situation
    /// Estimated state when the queue was built (e0), 0…1.
    var startEnergy: Double
    var kind: QueueKind
    /// The explanation shown to the user (fixed sentences, never an emotion word).
    var reason: String
    /// Unordered (SwiftData): sort by `QueueItem.position`. Deleted with the queue.
    @Relationship(deleteRule: .cascade, inverse: \QueueItem.queue) var items: [QueueItem]

    init(
        id: UUID = UUID(),
        createdAt: Date,
        situation: Situation,
        startEnergy: Double,
        kind: QueueKind,
        reason: String,
        items: [QueueItem]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.situation = situation
        self.startEnergy = startEnergy
        self.kind = kind
        self.reason = reason
        self.items = items
    }
}

/// One song of a queue.
@Model
final class QueueItem {
    /// 0-based place in the queue.
    var position: Int
    var spotifyId: String
    /// Energy the queue builder aimed at for this place, 0…1.
    var targetEnergy: Double
    /// True for a MuSe song outside the library, shown as "new".
    var isSuggestion: Bool
    var queue: QueueRecord?

    init(position: Int, spotifyId: String, targetEnergy: Double, isSuggestion: Bool) {
        self.position = position
        self.spotifyId = spotifyId
        self.targetEnergy = targetEnergy
        self.isSuggestion = isSuggestion
    }
}

/// The four situations of the home screen (PROJECT.md §2.3).
enum Situation: String, Codable {
    case wakeUp, stress, lowEnergy, windDown
}

/// How the queue was built: from the body state, or from the time of day only
/// (pilot comparison, TODO 4.4).
enum QueueKind: String, Codable {
    case body, timeOnly
}
