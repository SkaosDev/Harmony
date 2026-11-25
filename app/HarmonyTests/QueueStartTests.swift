import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 6.11: the state a queue starts from (design v2 §4.5), in shadow and active mode.
@MainActor
struct QueueStartTests {
    private let now = Date(timeIntervalSince1970: 1_790_050_000)

    /// 40 grid probabilities 0.30, 0.31 … 0.69 around a common probability of 0.45.
    private func state(gridPoints: Int = 40) -> CurrentState {
        CurrentState(date: now, features: [:], estimate: StateEstimate(value: 0.45, mode: .body),
                     gridProbabilities: (0..<gridPoints).map { 0.30 + Double($0) / 100 })
    }

    private func personal(energy: Int, pleasantness: Int = 0) -> PersonalState {
        PersonalState(energy: .init(offset: 0.8, probability: 0.64, count: energy),
                      pleasantness: .init(offset: -0.2, probability: 0.52, count: pleasantness))
    }

    @Test func shadowStartsFromTheRankWhateverTheAnswers() {
        let start = QueueStart.choose(state: state(), personal: personal(energy: 9, pleasantness: 9), mode: .shadow)
        // 16 of the 40 grid probabilities are ≤ 0.45.
        #expect(start.e0 == 16.0 / 40 && start.e0Source == .rank)
        #expect(start.v0 == nil && start.energyOffset == nil)
        // The personal probability is still computed and logged.
        #expect(start.pCommon == 0.45 && start.pPersonal == 0.64)
    }

    @Test func fewerThanThirtyTwoGridPointsStartsFromTheRawProbability() {
        let start = QueueStart.choose(state: state(gridPoints: 31), personal: personal(energy: 0), mode: .shadow)
        #expect(start.e0 == 0.45 && start.e0Source == .raw)
    }

    @Test func activeUsesTheAnswersFromFiveLabelledOnes() {
        let four = QueueStart.choose(state: state(), personal: personal(energy: 4), mode: .active)
        #expect(four.e0Source == .rank && four.energyOffset == nil)
        let five = QueueStart.choose(state: state(), personal: personal(energy: 5), mode: .active)
        #expect(five.e0 == 0.64 && five.e0Source == .personal && five.energyOffset == 0.8)
        #expect(five.v0 == nil)
        let both = QueueStart.choose(state: state(), personal: personal(energy: 5, pleasantness: 5), mode: .active)
        #expect(both.v0 == 0.52)
    }

    /// Design v2 §8 S6: without answers, the active queue is the queue of rule A.
    @Test func withoutAnswersTheActiveQueueIsRuleA() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        for index in 0..<40 {
            let id = "lib\(index)"
            context.insert(Track(spotifyId: id, title: "Song \(index)", artists: ["Artist \(index)"],
                                 coverURL: nil, source: .saved, addedAt: now))
            context.insert(SongScore(spotifyId: id, energy: Double(index) / 39, positivity: Double(index % 7) / 6,
                                     origin: .muse))
        }
        try context.save()
        var maker = QueueMaker(context: context, catalog: nil, music: LookUpOnlyProvider())
        maker.mode = .shadow
        let shadow = try await maker.prepare(.stress, state: state())
        maker.mode = .active
        let active = try await maker.prepare(.stress, state: state())
        #expect(active == shadow)
        #expect(shadow.e0 == 16.0 / 40 && shadow.start?.e0Source == .rank)
    }

    @Test func positivityTargetsGoFromV0ToTheGoal() {
        for (got, want) in zip(QueueTargets.positivityTargets(v0: 0.4, count: 3), [0.4, 0.55, 0.7]) {
            expectClose(got, want, "positivity target")
        }
        #expect(QueueTargets.positivityTargets(v0: 0.8, count: 5) == Array(repeating: 0.8, count: 5))
    }

    /// With `v0`, Stress and Low energy prefer the song nearest the positivity target, not just
    /// any song above 0.5; other situations ignore it.
    @Test func positivityTargetReplacesTheFixedPenalty() {
        let songs = [0.3, 0.9].map { positivity in
            QueueCandidate(spotifyId: "p\(positivity)", title: "", artists: ["A\(positivity)"], energy: 0.5,
                           positivity: positivity, origin: .muse)
        }
        func pick(_ situation: Situation, _ target: Double?) -> String? {
            TrackPicker.pick(target: 0.5, situation: situation, from: songs, usedIds: [], artistsInQueue: [],
                             positivityTarget: target)?.spotifyId
        }
        #expect(pick(.stress, nil) == "p0.9")
        #expect(pick(.stress, 0.35) == "p0.3")
        #expect(pick(.lowEnergy, 0.8) == "p0.9")
        // Wind-down has no positivity rule: tie, smaller ID.
        #expect(pick(.windDown, 0.9) == "p0.3")
    }
}
