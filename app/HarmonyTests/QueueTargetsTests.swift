import Testing
@testable import Harmony

/// TODO 3.2
@MainActor
struct QueueTargetsTests {
    /// e0 from 0 to 1 by 0.01.
    private let states = (0...100).map { Double($0) / 100 }

    @Test func longGapGivesFiveSongsWithTwoMatching() {
        let targets = QueueTargets.targets(e0: 0.2, situation: .wakeUp)
        #expect(targets.count == 5)
        #expect(targets[0] == 0.2)
        #expect(targets[1] == 0.2)
        #expect(abs(targets[2] - (0.2 + 0.5 / 3)) < 1e-12)
        #expect(abs(targets[3] - (0.2 + 1.0 / 3)) < 1e-12)
        #expect(targets[4] == 0.7)
    }

    @Test func shortGapGivesThreeSongsWithOneMatching() {
        let targets = QueueTargets.targets(e0: 0.5, situation: .wakeUp)
        #expect(targets.count == 3)
        #expect(targets[0] == 0.5)
        #expect(abs(targets[1] - 0.6) < 1e-12)
        #expect(targets[2] == 0.7)
    }

    @Test func gapOfExactlyPointThreeStaysShort() {
        #expect(QueueTargets.targets(e0: 0.5, situation: .windDown).count == 3)
    }

    @Test func lastTargetIsTheGoal() {
        #expect(QueueTargets.targets(e0: 0.9, situation: .windDown).last == 0.2)
        #expect(QueueTargets.targets(e0: 0.9, situation: .stress).last == 0.3)
        #expect(QueueTargets.targets(e0: 0.1, situation: .lowEnergy).last == 0.7)
    }

    @Test func windDownNeverEndsMoreEnergeticThanItStarts() {
        for e0 in states {
            let targets = QueueTargets.targets(e0: e0, situation: .windDown)
            #expect(targets.last! <= targets.first!, "e0 = \(e0)")
        }
    }

    @Test func targetsAreMonotoneInTheSituationDirection() {
        for situation in Situation.allCases {
            for e0 in states {
                let targets = QueueTargets.targets(e0: e0, situation: situation)
                #expect(targets.first == e0)
                for (a, b) in zip(targets, targets.dropFirst()) {
                    switch situation.direction {
                    case .up: #expect(b >= a, "\(situation) e0 = \(e0)")
                    case .down: #expect(b <= a, "\(situation) e0 = \(e0)")
                    }
                }
            }
        }
    }

    @Test func statePastTheGoalGivesAFlatQueue() {
        #expect(QueueTargets.targets(e0: 0.1, situation: .windDown) == [0.1, 0.1, 0.1])
        #expect(QueueTargets.targets(e0: 0.9, situation: .wakeUp) == [0.9, 0.9, 0.9])
    }
}
