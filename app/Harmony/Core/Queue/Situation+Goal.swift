import Foundation

/// What each situation aims for (TODO 3.1, PROJECT.md §2.3 and §8).
extension Situation {
    /// Which way a queue may move the energy.
    enum Direction {
        /// Wake-up, Low energy: never lower the energy.
        case up
        /// Stress, Wind-down: never raise the energy.
        case down
    }

    /// Energy at the end of the queue (`g`), 0…1.
    nonisolated var goal: Double {
        switch self {
        case .wakeUp: 0.7
        case .stress: 0.3
        case .lowEnergy: 0.7
        case .windDown: 0.2
        }
    }

    /// Stress and Low energy want positive songs: a song below 0.5 positivity gets a penalty.
    nonisolated var prefersPositive: Bool {
        self == .stress || self == .lowEnergy
    }

    nonisolated var direction: Direction {
        switch self {
        case .wakeUp, .lowEnergy: .up
        case .stress, .windDown: .down
        }
    }
}
