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
    /// Estimate the queue really started from (without recent heart rate it falls back to time
    /// only); nil for queues recorded before TODO 4.4.
    var stateMode: EstimateMode?
    /// Design v2 log (TODO 6.12), nil for queues recorded before it: the targets' strategy and the
    /// probability it had of being chosen (S1 and 1 in shadow mode), where `e0` came from, the
    /// common and personal probabilities at the start, and `v0` when the answers gave it.
    var strategy: QueueStrategy?
    var strategyProbability: Double?
    var e0Source: E0Source?
    var pCommon: Double?
    var pPersonal: Double?
    var v0: Double?
    /// The explanation shown to the user (fixed sentences, never an emotion word).
    var reason: String
    /// Unordered (SwiftData): sort by `QueueItem.position`. Deleted with the queue.
    @Relationship(deleteRule: .cascade, inverse: \QueueItem.queue) var items: [QueueItem]

    init(
        id: UUID = UUID(),
        createdAt: Date,
        situation: Situation,
        startEnergy: Double,
        stateMode: EstimateMode? = nil,
        strategy: QueueStrategy? = nil,
        strategyProbability: Double? = nil,
        e0Source: E0Source? = nil,
        pCommon: Double? = nil,
        pPersonal: Double? = nil,
        v0: Double? = nil,
        reason: String,
        items: [QueueItem]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.situation = situation
        self.startEnergy = startEnergy
        self.stateMode = stateMode
        self.strategy = strategy
        self.strategyProbability = strategyProbability
        self.e0Source = e0Source
        self.pCommon = pCommon
        self.pPersonal = pPersonal
        self.v0 = v0
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
enum Situation: String, Codable, CaseIterable {
    case wakeUp, stress, lowEnergy, windDown
}
