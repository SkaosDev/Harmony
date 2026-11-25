import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Harmony

/// TODO 6.10: what an action on the question stores. The lock screen and the watch are checked on
/// the iPhone.
@MainActor
struct CheckInNotificationsTests {
    private let now = Date(timeIntervalSince1970: 1_790_050_000)

    private func prompt(_ context: ModelContext) throws -> PromptLog {
        let log = PromptLog(scheduledAt: now - 600)
        context.insert(log)
        try context.save()
        return log
    }

    @Test func actionsFollowTheDesign() {
        #expect(CheckInNotifications.Action.allCases.map(\.title) == ["Not now", "Low", "Medium", "High"])
        #expect(CheckInNotifications.Action.allCases.map(\.energy) == [nil, -2, 0, 2])
        #expect(CheckInNotifications.body == "Quick check: energy right now?")
    }

    @Test func anAnswerIsStoredAndWaitsForItsState() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let log = try prompt(context)
        await CheckInNotifications.shared.handle(id: log.id.uuidString, action: "high", deliveredAt: now - 600,
                                                 now: now, context: context)
        let checkIn = try #require(try context.fetch(FetchDescriptor<CheckIn>()).first)
        #expect(checkIn.energy == 2 && checkIn.channel == .notification)
        #expect(checkIn.promptedAt == now - 600 && checkIn.answeredAt == now)
        // Locked phone: no state yet (`completePending` at the next return to the app).
        #expect(checkIn.zEnergy == nil)
        #expect(log.outcome == .answered && log.checkInId == checkIn.id && log.deliveredAt == now - 600)
    }

    /// Unknown is not zero: "Not now" and a dismissed question add no answer.
    @Test func notNowAndDismissAddNothing() async throws {
        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let first = try prompt(context)
        let second = try prompt(context)
        await CheckInNotifications.shared.handle(id: first.id.uuidString, action: "notNow", deliveredAt: now,
                                                 now: now, context: context)
        await CheckInNotifications.shared.handle(id: second.id.uuidString, action: UNNotificationDismissActionIdentifier,
                                                 deliveredAt: now, now: now, context: context)
        #expect(try context.fetchCount(FetchDescriptor<CheckIn>()) == 0)
        #expect(first.outcome == .notNow && second.outcome == .ignored)
    }

    @Test func windowsDefaultToTheDesignAndCanChange() throws {
        let suite = "CheckInNotificationsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(QuestionSettings.windows(defaults) == CheckInSchedule.defaultWindows)
        #expect(!QuestionSettings.isEnabled(defaults))
        QuestionSettings.setWindow(CheckInWindow(start: 8 * 60, end: 9 * 60 + 30), at: 0, defaults)
        #expect(QuestionSettings.windows(defaults)[0] == CheckInWindow(start: 480, end: 570))
        #expect(QuestionSettings.windows(defaults)[1] == CheckInSchedule.defaultWindows[1])
    }
}
