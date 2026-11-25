import Foundation
import SwiftData

/// Chooses the targets' strategy of a queue in active mode (TODO 6.12b, design v2 §4.6): Thompson
/// sampling on the rewards of the person's earlier queues of the same situation, mixed with a
/// uniform draw so each strategy keeps a probability of at least 0.15. The state is the queue
/// history itself: deleting the data, or "Reset what Harmony learned", starts it again.
nonisolated enum QueueBandit {
    /// Share of uniform draws: 0.45 / 3 = 0.15 per strategy at least.
    static let uniformShare = 0.45
    static let likeBonus = 0.2
    /// Monte-Carlo draws for the logged probability of the chosen strategy.
    static let draws = 2000

    struct Choice: Equatable {
        let strategy: QueueStrategy
        /// The probability it had of being chosen.
        let probability: Double
    }

    /// Beta posterior of a strategy, from the prior Beta(1, 1).
    struct Posterior: Equatable {
        var alpha = 1.0
        var beta = 1.0
    }

    /// r ∈ [0, 1] of a queue: "Did it fit?" Yes 1, Nope 0; without an answer, 1 − share of skips
    /// among the songs skipped or finished; +0.2 per like, at most 1. Nil when the queue has
    /// neither an answer nor a skipped or finished song: nothing to learn.
    static func reward(_ events: [FeedbackType]) -> Double? {
        let likes = Double(events.filter { $0 == .like }.count)
        let decided = events.filter { $0 == .skip || $0 == .finish }
        let base: Double
        if let fit = events.last(where: { $0 == .fitYes || $0 == .fitNo }) {
            base = fit == .fitYes ? 1 : 0
        } else if !decided.isEmpty {
            base = 1 - Double(decided.filter { $0 == .skip }.count) / Double(decided.count)
        } else {
            return nil
        }
        return min(1, base + likeBonus * likes)
    }

    /// α += r, β += 1 − r for each rewarded queue of the strategy.
    static func posteriors(_ history: [(strategy: QueueStrategy, reward: Double)]) -> [QueueStrategy: Posterior] {
        var posteriors = Dictionary(uniqueKeysWithValues: QueueStrategy.allCases.map { ($0, Posterior()) })
        for item in history {
            posteriors[item.strategy]!.alpha += item.reward
            posteriors[item.strategy]!.beta += 1 - item.reward
        }
        return posteriors
    }

    /// The uniform draw with probability 0.45, else the strategy with the highest Beta draw; its
    /// probability is 0.15 + 0.55 × its Thompson share, estimated over 2000 draws.
    static func choose(_ posteriors: [QueueStrategy: Posterior], using rng: inout some RandomNumberGenerator) -> Choice {
        let arms = QueueStrategy.allCases
        let strategy = Double.random(in: 0..<1, using: &rng) < uniformShare
            ? arms.randomElement(using: &rng)!
            : thompson(posteriors, using: &rng)
        var wins = 0
        for _ in 0..<draws where thompson(posteriors, using: &rng) == strategy {
            wins += 1
        }
        let share = Double(wins) / Double(draws)
        return Choice(strategy: strategy,
                      probability: uniformShare / Double(arms.count) + (1 - uniformShare) * share)
    }

    /// The choice for a queue of `situation`, from the queues recorded since `since` (the last
    /// "Reset what Harmony learned").
    @MainActor
    static func choose(for situation: Situation, since: Date?, in context: ModelContext,
                       using rng: inout some RandomNumberGenerator) throws -> Choice {
        let start = since ?? .distantPast
        let queues = try context.fetch(FetchDescriptor<QueueRecord>(predicate: #Predicate { $0.createdAt >= start }))
            .filter { $0.situation == situation && $0.strategy != nil }
        let ids = Set(queues.map(\.id))
        let events = try context.fetch(FetchDescriptor<FeedbackEvent>(predicate: #Predicate { $0.time >= start }))
            .filter { ids.contains($0.queueId) }
        let byQueue = Dictionary(grouping: events, by: \.queueId)
        let history = queues.compactMap { queue -> (strategy: QueueStrategy, reward: Double)? in
            let sorted = (byQueue[queue.id] ?? []).sorted { $0.time < $1.time }.map(\.event)
            return reward(sorted).map { (queue.strategy!, $0) }
        }
        return choose(posteriors(history), using: &rng)
    }

    private static func thompson(_ posteriors: [QueueStrategy: Posterior],
                                 using rng: inout some RandomNumberGenerator) -> QueueStrategy {
        let draws = QueueStrategy.allCases.map { ($0, beta(posteriors[$0]!, using: &rng)) }
        return draws.max { $0.1 < $1.1 }!.0
    }

    /// X / (X + Y) with X ~ Gamma(α), Y ~ Gamma(β).
    private static func beta(_ posterior: Posterior, using rng: inout some RandomNumberGenerator) -> Double {
        let x = gamma(posterior.alpha, using: &rng)
        let y = gamma(posterior.beta, using: &rng)
        return x / (x + y)
    }

    /// Marsaglia and Tsang (2000), for shape ≥ 1 (the prior makes α, β ≥ 1).
    private static func gamma(_ shape: Double, using rng: inout some RandomNumberGenerator) -> Double {
        let d = shape - 1.0 / 3
        let c = 1 / (9 * d).squareRoot()
        while true {
            let x = normal(using: &rng)
            let v = pow(1 + c * x, 3)
            guard v > 0 else { continue }
            let u = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &rng)
            if log(u) < 0.5 * x * x + d - d * v + d * log(v) { return d * v }
        }
    }

    /// Box–Muller.
    private static func normal(using rng: inout some RandomNumberGenerator) -> Double {
        let u = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &rng)
        let v = Double.random(in: 0..<1, using: &rng)
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }
}
