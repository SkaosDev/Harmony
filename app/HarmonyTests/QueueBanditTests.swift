import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 6.12b: the strategies S1/S2/S3 and their choice (design v2 §4.6).
@MainActor
struct QueueBanditTests {
    /// SplitMix64: the same draws on every run.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test func everyStrategyGoesMonotonicallyFromE0ToTheGoal() {
        for strategy in QueueStrategy.allCases {
            for situation in Situation.allCases {
                for e0 in stride(from: 0.0, through: 1.0, by: 0.05) {
                    let targets = QueueTargets.targets(e0: e0, situation: situation, strategy: strategy)
                    let goal = QueueTargets.goal(e0: e0, situation: situation)
                    #expect(targets.count == (abs(e0 - goal) > QueueTargets.longGap ? 5 : 3))
                    #expect(targets.first == e0)
                    expectClose(targets.last, goal, "\(strategy) \(situation) \(e0)")
                    let steps = zip(targets, targets.dropFirst()).map { $1 - $0 }
                    switch situation.direction {
                    case .up: #expect(steps.allSatisfy { $0 >= -1e-12 }, "\(strategy) \(situation) \(e0)")
                    case .down: #expect(steps.allSatisfy { $0 <= 1e-12 }, "\(strategy) \(situation) \(e0)")
                    }
                }
            }
        }
        // Wind-down from 0.9 (goal 0.2): the three shapes.
        #expect(QueueTargets.targets(e0: 0.9, situation: .windDown, strategy: .s3).prefix(3) == [0.9, 0.9, 0.9])
        let s2 = QueueTargets.targets(e0: 0.9, situation: .windDown, strategy: .s2)
        expectClose(s2[1], 0.55, "S2 half step")
    }

    @Test func rewardFollowsTheAnswerThenTheSkips() {
        #expect(QueueBandit.reward([.skip, .finish, .fitYes]) == 1)
        #expect(QueueBandit.reward([.finish, .finish, .fitNo]) == 0)
        #expect(QueueBandit.reward([.skip, .finish, .finish, .skip]) == 0.5)
        expectClose(QueueBandit.reward([.skip, .finish, .like]), 0.7, "like bonus")
        #expect(QueueBandit.reward([.finish, .like, .like]) == 1)
        #expect(QueueBandit.reward([.like]) == nil)
        #expect(QueueBandit.reward([]) == nil)
    }

    @Test func everyStrategyKeepsAtLeastFifteenPercent() {
        var rng = SeededGenerator(state: 2026)
        // S1 always fitted, the others never: S1 wins most, the others keep 0.15.
        let history = (0..<30).flatMap { _ in
            [(strategy: QueueStrategy.s1, reward: 1.0), (.s2, 0.0), (.s3, 0.0)]
        }
        let posteriors = QueueBandit.posteriors(history)
        #expect(posteriors[.s1] == .init(alpha: 31, beta: 1))
        var chosen: [QueueStrategy: Int] = [:]
        for _ in 0..<200 {
            let choice = QueueBandit.choose(posteriors, using: &rng)
            #expect(choice.probability >= 0.15 && choice.probability <= 1)
            chosen[choice.strategy, default: 0] += 1
            if choice.strategy == .s1 {
                #expect(choice.probability > 0.65)
            } else {
                #expect(choice.probability < 0.2)
            }
        }
        #expect(chosen[.s2, default: 0] > 10 && chosen[.s3, default: 0] > 10 && chosen[.s1, default: 0] > 100)

        // No history: a third each.
        let fresh = QueueBandit.choose(QueueBandit.posteriors([]), using: &rng)
        #expect(abs(fresh.probability - 1.0 / 3) < 0.03)
    }

    /// Active mode: the queue logs the chosen strategy and its probability; the history counts
    /// only after the last reset.
    @Test func activeQueueLogsTheChosenStrategy() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_790_050_000)
        for index in 0..<40 {
            let id = "lib\(index)"
            context.insert(Track(spotifyId: id, title: "Song \(index)", artists: ["Artist \(index)"],
                                 coverURL: nil, source: .saved, addedAt: now))
            context.insert(SongScore(spotifyId: id, energy: Double(index) / 39, positivity: 0.7, origin: .muse))
        }
        let old = QueueRecord(createdAt: now - 86400, situation: .windDown, startEnergy: 0.8, strategy: .s3,
                              strategyProbability: 0.15, reason: "", items: [])
        context.insert(old)
        context.insert(FeedbackEvent(queueId: old.id, spotifyId: nil, event: .fitNo, seconds: nil, time: now - 86000))
        try context.save()

        var rng = SeededGenerator(state: 7)
        let withHistory = try QueueBandit.choose(for: .windDown, since: nil, in: context, using: &rng)
        let afterReset = try QueueBandit.choose(for: .windDown, since: now - 3600, in: context, using: &rng)
        // One "Nope" for S3 lowers its chance; after the reset, it is forgotten.
        #expect(abs(afterReset.probability - 1.0 / 3) < 0.03)
        if withHistory.strategy == .s3 { #expect(withHistory.probability < 0.3) }

        var maker = QueueMaker(context: context, catalog: nil, music: LookUpOnlyProvider())
        maker.mode = .active
        let queue = try await maker.prepare(.windDown, state: CurrentState(
            date: now, features: [:], estimate: StateEstimate(value: 0.8, mode: .body)))
        #expect(queue.strategyProbability >= 0.15 && queue.strategyProbability < 1)
        #expect(queue.entries.map(\.target) == QueueTargets.targets(e0: 0.8, situation: .windDown, strategy: queue.strategy))
        let record = try maker.record(queue, at: now)
        #expect(record.strategy == queue.strategy && record.strategyProbability == queue.strategyProbability)
    }
}
