import Foundation

/// How the targets go from `e0` to the goal (design v2 §4.6, decision D7). Every queue logs its
/// strategy (`QueueRecord.strategy`); S1 is the rule of PROJECT.md §8.
nonisolated enum QueueStrategy: String, Codable, CaseIterable {
    /// « progressif »
    case s1
    /// « demi-pas »
    case s2
    /// « correspondance longue »
    case s3
}

/// The energy each song of a queue aims at (TODO 3.2, PROJECT.md §8; strategy S1 « progressif »
/// of design v2 §4.6): `m` songs at the current state `e0`, then steps evenly from `e0` to the goal.
nonisolated enum QueueTargets {
    /// Above this gap between `e0` and the goal, the queue has 5 songs instead of 3.
    static let longGap = 0.3

    /// `n = 5` if |e0 − g| > 0.3, else 3, for every strategy. Then:
    /// - S1: `m = 2` matching songs if n = 5, else 1; then `n − m` targets evenly spaced up to
    ///   the goal, the last one exactly at the goal;
    /// - S2: one song at `e0`, then `n − 1` targets evenly from (e0 + g) / 2 to the goal;
    /// - S3: `n − 2` songs at `e0`, then (e0 + g) / 2 and the goal.
    /// All go monotonically from `e0` to the goal: Wind-down never ends more energetic.
    static func targets(e0: Double, situation: Situation, strategy: QueueStrategy = .s1) -> [Double] {
        let goal = goal(e0: e0, situation: situation)
        let count = abs(e0 - goal) > longGap ? 5 : 3
        let half = (e0 + goal) / 2
        switch strategy {
        case .s1:
            let matching = count == 5 ? 2 : 1
            let steps = count - matching
            let moving = (1...steps).map { step in
                let t = Double(step) / Double(steps)
                return e0 * (1 - t) + goal * t
            }
            return Array(repeating: e0, count: matching) + moving
        case .s2:
            let steps = count - 2
            return [e0] + (0...steps).map { step in
                let t = Double(step) / Double(steps)
                return half * (1 - t) + goal * t
            }
        case .s3:
            return Array(repeating: e0, count: count - 2) + [half, goal]
        }
    }

    /// Where the songs' positivity ends in Stress and Low energy when `v0` is known.
    static let positivityGoal = 0.7

    /// Active mode with `v0` (design v2 §4.5, provisional form to settle with the customer): the
    /// positivity each song aims at, evenly from `v0` to max(v0, 0.7), one per energy target.
    static func positivityTargets(v0: Double, count: Int) -> [Double] {
        let goal = max(v0, positivityGoal)
        return (0..<count).map { v0 + (goal - v0) * Double($0) / Double(max(count - 1, 1)) }
    }

    /// The situation's goal, or `e0` when the state is already past it: Wake-up and Low energy
    /// never lower the energy, Stress and Wind-down never raise it (the queue stays flat).
    static func goal(e0: Double, situation: Situation) -> Double {
        switch situation.direction {
        case .up: max(situation.goal, e0)
        case .down: min(situation.goal, e0)
        }
    }
}
