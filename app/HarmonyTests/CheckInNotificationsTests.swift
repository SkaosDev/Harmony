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

    /// Two plans made at once (the permission alert closing as the app comes back, or a queue
    /// starting as the app comes back) keep one set of questions: at most one per window, 2 h
    /// apart, not two sets on top of each other.
    @Test func overlappingPlansKeepOneSetOfQuestions() async throws {
        let suite = "CheckInNotificationsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: QuestionSettings.enabledKey)
        func notifications() -> CheckInNotifications {
            let notifications = CheckInNotifications()
            notifications.defaults = defaults
            notifications.isAuthorized = { await Task.yield(); return true }
            notifications.addRequest = { _ in await Task.yield() }
            return notifications
        }

        let aloneContainer = try HarmonyStore.container(inMemory: true)
        let alone = aloneContainer.mainContext
        await notifications().reschedule(context: alone, now: now)
        let expected = try alone.fetchCount(FetchDescriptor<PromptLog>())
        #expect(expected > 0)

        let container = try HarmonyStore.container(inMemory: true)
        let context = container.mainContext
        let shared = notifications()
        let first = Task { await shared.reschedule(context: context, now: now) }
        let second = Task { await shared.reschedule(context: context, now: now) }
        await first.value
        await second.value
        let times = try context.fetch(FetchDescriptor<PromptLog>(sortBy: [SortDescriptor(\.scheduledAt)])).map(\.scheduledAt)
        #expect(times.count == expected)
        for (earlier, later) in zip(times, times.dropFirst()) {
            #expect(later.timeIntervalSince(earlier) >= CheckInSchedule.minimumGap)
        }
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

    /// iOS must hear back on the main thread once an answer is handled, or the app stops
    /// ("Call must be made on main thread", seen on the iPhone on 26 Nov). The notification and
    /// the response have no public initializer: made here as in Apple's own tests.
    @Test func iOSHearsBackOnTheMainThread() async throws {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CheckInNotifications.category
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let notification = try #require(UNNotification.perform(NSSelectorFromString("notificationWithRequest:date:"),
                                                               with: request, with: now)?.takeUnretainedValue() as? UNNotification)
        let response = try #require(UNNotificationResponse.perform(
            NSSelectorFromString("responseWithNotification:actionIdentifier:"),
            with: notification, with: CheckInNotifications.Action.notNow.rawValue)?.takeUnretainedValue() as? UNNotificationResponse)
        // No store: the answer goes nowhere, only the way back to iOS is checked.
        let delegate: UNUserNotificationCenterDelegate = CheckInNotifications()
        let answered = await withCheckedContinuation { continuation in
            delegate.userNotificationCenter?(.current(), didReceive: response) {
                continuation.resume(returning: Thread.isMainThread)
            }
        }
        let presented = await withCheckedContinuation { continuation in
            delegate.userNotificationCenter?(.current(), willPresent: notification) { _ in
                continuation.resume(returning: Thread.isMainThread)
            }
        }
        #expect(answered)
        #expect(presented)
    }
}
