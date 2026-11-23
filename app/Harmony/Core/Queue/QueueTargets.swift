import Foundation

/// The energy each song of a queue aims at (TODO 3.2, PROJECT.md §8; strategy S1 « progressif »
/// of design v2 §4.6): `m` songs at the current state `e0`, then steps evenly from `e0` to the goal.
nonisolated enum QueueTargets {
    /// Above this gap between `e0` and the goal, the queue has 5 songs instead of 3.
    static let longGap = 0.3

    /// `n = 5` if |e0 − g| > 0.3, else 3; `m = 2` matching songs if n = 5, else 1; then
    /// `n − m` targets evenly spaced up to the goal, the last one exactly at the goal.
    static func targets(e0: Double, situation: Situation) -> [Double] {
        let goal = goal(e0: e0, situation: situation)
        let count = abs(e0 - goal) > longGap ? 5 : 3
        let matching = count == 5 ? 2 : 1
        let steps = count - matching
        let moving = (1...steps).map { step in
            let t = Double(step) / Double(steps)
            return e0 * (1 - t) + goal * t
        }
        return Array(repeating: e0, count: matching) + moving
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
