import Testing
@testable import Harmony

/// TODO 3.1
@MainActor
struct SituationTests {
    @Test func goalsFollowTheSituationTable() {
        #expect(Situation.wakeUp.goal == 0.7)
        #expect(Situation.stress.goal == 0.3)
        #expect(Situation.lowEnergy.goal == 0.7)
        #expect(Situation.windDown.goal == 0.2)
    }

    @Test func onlyStressAndLowEnergyPreferPositiveSongs() {
        #expect(Situation.allCases.filter(\.prefersPositive) == [.stress, .lowEnergy])
    }

    @Test func directionGoesTowardTheGoal() {
        #expect(Situation.wakeUp.direction == .up)
        #expect(Situation.lowEnergy.direction == .up)
        #expect(Situation.stress.direction == .down)
        #expect(Situation.windDown.direction == .down)
    }
}
