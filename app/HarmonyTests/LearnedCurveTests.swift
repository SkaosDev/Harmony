import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 6.16: the "Your answers" card of About, built from the stored answers: the waiting frame
/// before 6 answers, then the two estimates of each answer of the last 14 days and a sentence from
/// the offset; nothing left after the 30-day purge or "Reset what Harmony learned".
@MainActor
struct LearnedCurveTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let defaults: UserDefaults
    private let suite = "LearnedCurveTests-\(UUID().uuidString)"
    private let start: Date

    init() throws {
        container = try HarmonyStore.container(inMemory: true)
        context = container.mainContext
        defaults = try #require(UserDefaults(suiteName: suite))
        start = StateFixtures.calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 10))!
    }

    private var recorder: CheckInRecorder {
        CheckInRecorder(context: context, defaults: defaults, calendar: StateFixtures.calendar)
    }

    /// Answers every 6 hours from `start`, the common model at 0.5.
    private func answer(_ energies: [Int]) throws {
        for (index, energy) in energies.enumerated() {
            try recorder.record(energy: energy, channel: .notification, at: start + Double(index) * 6 * 3600,
                                common: StateEstimate(value: 0.5, mode: .body))
        }
    }

    private func content(at now: Date) throws -> LearnedCurve.Content {
        LearnedCurve.content(answers: try context.fetch(FetchDescriptor<CheckIn>()), now: now)
    }

    @Test func noAnswerShowsTheWaitingFrame() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(try content(at: start) == .few(count: 0))
    }

    @Test func theCurveAppearsAtTheSixthAnswer() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try answer([0, -2, 2, 0, 0])
        #expect(try content(at: start + 2 * 86400) == .few(count: 5))
        try recorder.record(energy: 2, channel: .sheet, at: start + 30 * 3600, common: StateEstimate(value: 0.5, mode: .body))
        guard case .curve(let points, _) = try content(at: start + 2 * 86400) else {
            Issue.record("no curve after 6 answers")
            return
        }
        #expect(points.count == 6)
    }

    @Test func eachPointKeepsBothEstimatesAndTheLabel() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try answer([-2, 0, 0, -2, 0, 2, 3, 2])
        let stored = try context.fetch(FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.answeredAt)]))
        guard case .curve(let points, let headline) = try content(at: start + 43 * 3600) else {
            Issue.record("no curve after 8 answers")
            return
        }
        #expect(points.map(\.answeredAt) == stored.map(\.answeredAt))
        #expect(points.map(\.watchOnly) == stored.map { $0.pCommonBefore! })
        #expect(points.map(\.withAnswers) == stored.map { $0.pPersonalBefore! })
        #expect(points.map(\.above) == [nil, nil, nil, nil, nil, true, true, true])
        // Three answers above the usual: the offset is well past the threshold.
        #expect(headline == .more)
    }

    @Test func headlineUsesTheThresholdOfTheQueueReason() {
        #expect(LearnedCurve.headline(offset: Explainer.notableOffset) == .more)
        #expect(LearnedCurve.headline(offset: -Explainer.notableOffset) == .less)
        #expect(LearnedCurve.headline(offset: 0.49) == .noClearDifference)
        #expect(LearnedCurve.headline(offset: 0) == .noClearDifference)
    }

    @Test func answersLeaveTheCurveAfterFourteenDaysAndThePhoneAfterThirty() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try answer([-2, 0, 0, -2, 0, 2, 3, 2])
        // Day 20: still stored, but outside the 14 days of the curve.
        try recorder.deleteExpired(now: start + 20 * 86400)
        #expect(try context.fetchCount(FetchDescriptor<CheckIn>()) == 8)
        #expect(try content(at: start + 20 * 86400) == .few(count: 0))
        // Day 32: all are more than 30 days old (the last was at day 2), the purge removes them.
        try recorder.deleteExpired(now: start + 32 * 86400)
        #expect(try context.fetchCount(FetchDescriptor<CheckIn>()) == 0)
        #expect(try content(at: start + 32 * 86400) == .few(count: 0))
    }

    @Test func resetEmptiesTheCurve() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try answer([-2, 0, 0, -2, 0, 2, 3, 2])
        try recorder.reset(now: start + 2 * 86400)
        #expect(try content(at: start + 2 * 86400) == .few(count: 0))
    }
}
