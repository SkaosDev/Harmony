import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 6.8: answers recorded with their label, usability, day of use and chronological pair;
/// lock-screen answers completed later; the personal state from the stored answers.
@MainActor
struct CheckInRecorderTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let defaults: UserDefaults
    private let suite = "CheckInRecorderTests-\(UUID().uuidString)"
    private let calendar = StateFixtures.calendar
    private let start: Date

    init() throws {
        container = try HarmonyStore.container(inMemory: true)
        context = container.mainContext
        defaults = try #require(UserDefaults(suiteName: suite))
        start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 10))!
    }

    private var recorder: CheckInRecorder {
        CheckInRecorder(context: context, defaults: defaults, calendar: calendar)
    }

    private func common(_ value: Double) -> StateEstimate {
        StateEstimate(value: value, mode: .body, valence: 0.5)
    }

    /// Answers every 6 hours from `start`, the common model at 0.5.
    private func answer(_ energies: [Int], from first: Date? = nil) throws -> [CheckIn] {
        try energies.enumerated().map { index, energy in
            try recorder.record(energy: energy, channel: .notification, at: (first ?? start) + Double(index) * 6 * 3600,
                                common: common(0.5))
        }
    }

    @Test func noAnswerLeavesTheCommonModel() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = try recorder.personal(at: start, common: common(0.4))
        #expect(state.energy.offset == 0 && state.energy.count == 0)
        #expect(state.energy.probability == 0.4)
        #expect(state.pleasantness.offset == 0)
    }

    @Test func labelComesAfterFiveAnswersAndTheLayerLearns() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let answers = try answer([-2, 0, 0, -2, 0, 2, 3, 2])
        #expect(answers.prefix(5).allSatisfy { $0.labelEnergy == nil })
        // Sixth: mean of the five before is −0.8, so +2 is above the usual.
        #expect(answers[5].labelEnergy == true && answers[6].labelEnergy == true)
        #expect(answers.allSatisfy { $0.usableForLearning && $0.zEnergy == 0 && $0.pCommonBefore == 0.5 })
        // pPersonalBefore uses only the answers before: the 7th sees one "above", the 8th two.
        #expect(answers[5].pPersonalBefore == 0.5)
        let sixth = try #require(answers[6].pPersonalBefore)
        let seventh = try #require(answers[7].pPersonalBefore)
        #expect(seventh > sixth && sixth > 0.5)

        let later = answers.last!.answeredAt + 3600
        let state = try recorder.personal(at: later, common: common(0.5))
        #expect(state.energy.count == 3 && state.energy.offset > 0 && state.energy.probability > 0.5)
    }

    @Test func dayOfUseCountsFromTheFirstAnswer() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = try recorder.record(energy: 0, channel: .sheet, at: start, common: common(0.5))
        let next = try recorder.record(energy: 0, channel: .sheet, at: start + 2 * 86400 + 3600, common: common(0.5))
        #expect(first.dayOfUse == 1 && next.dayOfUse == 3)
        try recorder.reset()
        let afterReset = try recorder.record(energy: 0, channel: .sheet, at: start + 5 * 86400, common: common(0.5))
        #expect(afterReset.dayOfUse == 1)
        #expect(try context.fetchCount(FetchDescriptor<CheckIn>()) == 1)
    }

    /// During a queue and in the hour after its last event, answers are kept but not learned from.
    @Test func answersNearAQueueAreNotLearnedFrom() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let queue = QueueRecord(createdAt: start, situation: .wakeUp, startEnergy: 0.5, reason: "", items: [])
        context.insert(queue)
        context.insert(FeedbackEvent(queueId: queue.id, spotifyId: "a", event: .finish, seconds: 200, time: start + 20 * 60))
        try context.save()

        let before = try recorder.record(energy: 1, channel: .sheet, at: start - 60, common: common(0.5))
        let during = try recorder.record(energy: 1, channel: .sheet, at: start + 10 * 60, common: common(0.5))
        let soonAfter = try recorder.record(energy: 1, channel: .sheet, at: start + 79 * 60, common: common(0.5))
        let later = try recorder.record(energy: 1, channel: .sheet, at: start + 81 * 60, common: common(0.5))
        #expect(before.usableForLearning && !during.usableForLearning && !soonAfter.usableForLearning)
        #expect(later.usableForLearning)
    }

    /// Lock screen: the answer waits for its logits; the label and usability are fixed already.
    @Test func pendingAnswersAreCompletedAtTheirOwnTime() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = try answer([0, 0, 0, 0, 0])
        let locked = try recorder.record(energy: 3, channel: .notification, promptedAt: start + 30 * 3600 - 60,
                                         at: start + 30 * 3600, common: nil)
        #expect(locked.zEnergy == nil && locked.pCommonBefore == nil && locked.labelEnergy == true)

        var asked: [Date] = []
        let done = try await recorder.completePending { date in
            asked.append(date)
            return StateEstimate(value: 0.3, mode: .timeOnly)
        }
        #expect(done == 1 && asked == [locked.answeredAt])
        #expect(locked.estimateMode == .timeOnly && locked.pCommonBefore == 0.3)
        expectClose(locked.zEnergy, PersonalLayer.logit(0.3), "z")
        // No earlier labelled answer: the personal probability is the common one.
        expectClose(locked.pPersonalBefore, 0.3, "pPersonalBefore")
    }

    @Test func stillLockedLeavesThePendingAnswers() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let locked = try recorder.record(energy: 0, channel: .notification, at: start, common: nil)
        struct Locked: Error {}
        let done = try await recorder.completePending { _ in throw Locked() }
        #expect(done == 0 && locked.zEnergy == nil)
    }

    @Test func oldAnswersAreDeletedAfterThirtyDays() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = try recorder.record(energy: 0, channel: .sheet, at: start, common: common(0.5))
        context.insert(PromptLog(scheduledAt: start))
        _ = try recorder.record(energy: 0, channel: .sheet, at: start + 20 * 86400, common: common(0.5))
        try recorder.deleteExpired(now: start + 31 * 86400)
        #expect(try context.fetchCount(FetchDescriptor<CheckIn>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PromptLog>()) == 0)
    }

    /// TODO 6.13: "Reset what Harmony learned" brings the offsets back to 0.
    @Test func resetBringsTheOffsetBackToZero() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let answers = try answer([-2, -2, -2, -2, -2, 3, 3, 3])
        let later = answers.last!.answeredAt + 3600
        #expect(try recorder.personal(at: later, common: common(0.5)).energy.offset > 0)
        try recorder.reset()
        let state = try recorder.personal(at: later, common: common(0.5))
        #expect(state.energy.offset == 0 && state.energy.count == 0)
        #expect(defaults.object(forKey: CheckInRecorder.firstDayKey) == nil)
    }
}
