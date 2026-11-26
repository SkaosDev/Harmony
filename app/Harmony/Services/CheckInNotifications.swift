import Foundation
import SwiftData
import UserNotifications

/// Settings › Questions (`V2-Questions`, TODO 6.10, 6.13): on/off and the two windows.
enum QuestionSettings {
    static let enabledKey = "questions.enabled"
    /// Start and end of each window, in minutes after midnight.
    static let windowKeys = [("questions.window1Start", "questions.window1End"),
                             ("questions.window2Start", "questions.window2End")]
    /// Pilot only (`docs/pilot-protocol.md` §10.6): Settings › Debug plans with the four pilot
    /// windows instead of these two; Settings › Questions is unchanged.
    static let pilotFourKey = "questions.pilotFour"
    static var keys: [String] { [enabledKey, pilotFourKey] + windowKeys.flatMap { [$0.0, $0.1] } }

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func windows(_ defaults: UserDefaults = .standard) -> [CheckInWindow] {
        zip(windowKeys, CheckInSchedule.defaultWindows).map { keys, fallback in
            CheckInWindow(start: defaults.object(forKey: keys.0) as? Int ?? fallback.start,
                          end: defaults.object(forKey: keys.1) as? Int ?? fallback.end)
        }
    }

    /// The windows the questions are planned in.
    static func plannedWindows(_ defaults: UserDefaults = .standard) -> [CheckInWindow] {
        defaults.bool(forKey: pilotFourKey) ? CheckInSchedule.pilotWindows : windows(defaults)
    }

    static func setWindow(_ window: CheckInWindow, at index: Int, _ defaults: UserDefaults = .standard) {
        defaults.set(window.start, forKey: windowKeys[index].0)
        defaults.set(window.end, forKey: windowKeys[index].1)
    }
}

/// The two daily questions (TODO 6.10, design v2 §5.2–5.3, `V2-Notification`): local
/// notifications with Not now / Low / Medium / High, answered from the lock screen or the Apple
/// Watch without opening the app. Each planned question has a `PromptLog` row (its id is the
/// request's); an answer becomes a `CheckIn` (−2 / 0 / +2), "Not now" and silence add nothing.
final class CheckInNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CheckInNotifications()

    nonisolated static let category = "CHECKIN"
    static let body = CheckInTexts.notification
    /// A question left this long without an answer is ignored, and taken off the screen.
    static let ignoredAfter: TimeInterval = 2 * 3600

    /// "Not now" first: the Apple Watch's Double Tap runs the first action (design v2 §5.1).
    enum Action: String, CaseIterable {
        case notNow, low, medium, high

        var title: String {
            switch self {
            case .notNow: CheckInTexts.notNow
            case .low: CheckInTexts.low
            case .medium: CheckInTexts.medium
            case .high: CheckInTexts.high
            }
        }

        /// The stored answer on the −3…+3 scale; nil for "Not now".
        var energy: Int? {
            switch self {
            case .notNow: nil
            case .low: -2
            case .medium: 0
            case .high: 2
            }
        }
    }

    /// Set at launch (`HarmonyApp`): the store the answers go to, and the health data the answers
    /// are completed with.
    var container: (() -> ModelContainer)?
    var healthProvider: (() throws -> any HealthProvider)?
    /// Where the settings are read, whether iOS allows the questions and how one reaches iOS;
    /// tests replace them (the test host is never allowed to notify).
    var defaults: UserDefaults = .standard
    var isAuthorized: () async -> Bool = {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
    }
    var addRequest: (UNNotificationRequest) async throws -> Void = { try await UNUserNotificationCenter.current().add($0) }
    private var center: UNUserNotificationCenter { .current() }

    /// At launch, before any answer can arrive.
    func register() {
        let actions = Action.allCases.map { UNNotificationAction(identifier: $0.rawValue, title: $0.title, options: []) }
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: actions, intentIdentifiers: [],
                                   options: [.customDismissAction]),
        ])
        center.delegate = self
    }

    /// "Allow notifications" (onboarding, Settings): true when the user allows them.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // MARK: Planning

    /// The plan being made. A new plan waits for it: two plans made at once would each keep
    /// their own questions (the old ones are deleted before the first wait).
    private var planning: Task<Void, Never>?

    /// Plans the questions of the next 3 days again: after a change of settings, at each return
    /// to the app and when a queue starts (none in the 80 min after it). `now` defaults to the
    /// time the plan is made, after the one before it.
    func reschedule(context: ModelContext, now: Date? = nil) async {
        let previous = planning
        let current = Task {
            await previous?.value
            await plan(context: context, now: now ?? .now)
        }
        planning = current
        await current.value
    }

    private func plan(context: ModelContext, now: Date) async {
        do {
            let future = try context.fetch(FetchDescriptor<PromptLog>(predicate: #Predicate { $0.scheduledAt > now }))
                .filter { $0.outcome == nil }
            center.removePendingNotificationRequests(withIdentifiers: future.map(\.id.uuidString))
            future.forEach(context.delete)
            try context.save()
            guard QuestionSettings.isEnabled(defaults), await isAuthorized() else { return }

            let dayAgo = now - 86400
            let asked = try context.fetch(FetchDescriptor<PromptLog>(predicate: #Predicate {
                $0.scheduledAt >= dayAgo && $0.scheduledAt <= now
            })).map(\.scheduledAt)
            var lastQueue = FetchDescriptor<QueueRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            lastQueue.fetchLimit = 1
            let quietUntil = try context.fetch(lastQueue).first.map { $0.createdAt + CheckInSchedule.quietAfterQueue }
            var rng = SystemRandomNumberGenerator()
            let times = CheckInSchedule.times(now: now, windows: QuestionSettings.plannedWindows(defaults), asked: asked,
                                              quietUntil: quietUntil, calendar: .current, using: &rng)
            for time in times {
                try await add(at: time, context: context)
            }
            print("Questions planned: \(times.count)")
        } catch {
            print("Questions not planned: \(error)")
        }
    }

    /// Takes every question off: before "Reset what Harmony learned" and "Delete everything"
    /// delete their log. The app sends no other notification.
    func removeAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Debug (TODO 6.10 check on the iPhone): one question in `seconds`, for the lock screen and
    /// the watch.
    func sendTest(in seconds: TimeInterval, context: ModelContext) async throws {
        try await add(at: .now + seconds, context: context)
    }

    /// At each return to the app: questions left 2 h without an answer are ignored; answers given
    /// on the lock screen get their state now that Apple Health can be read; check-ins older than
    /// 30 days go; then the plan is made again.
    func refresh(context: ModelContext, now: Date = .now) async {
        do {
            let past = try context.fetch(FetchDescriptor<PromptLog>(predicate: #Predicate { $0.scheduledAt <= now }))
                .filter { $0.outcome == nil }
            var stale: [String] = []
            for log in past {
                log.deliveredAt = log.deliveredAt ?? log.scheduledAt
                if now.timeIntervalSince(log.scheduledAt) >= Self.ignoredAfter {
                    log.outcome = .ignored
                    stale.append(log.id.uuidString)
                }
            }
            center.removeDeliveredNotifications(withIdentifiers: stale)
            try context.save()
            try await complete(context: context)
            try CheckInRecorder(context: context).deleteExpired(now: now)
        } catch {
            print("Questions not refreshed: \(error)")
        }
        await reschedule(context: context, now: now)
    }

    private func add(at time: Date, context: ModelContext) async throws {
        let log = PromptLog(scheduledAt: time)
        let content = UNMutableNotificationContent()
        content.body = Self.body
        content.categoryIdentifier = Self.category
        content.sound = .default
        let clock = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time)
        try await addRequest(UNNotificationRequest(identifier: log.id.uuidString, content: content,
                                                   trigger: UNCalendarNotificationTrigger(dateMatching: clock, repeats: false)))
        context.insert(log)
        try context.save()
    }

    // MARK: Answers

    /// An action on the notification, the app possibly still in the background and the phone
    /// locked: the answer is stored at once, without its state (`CheckInRecorder.completePending`).
    func handle(id: String, action: String, deliveredAt: Date, now: Date = .now, context: ModelContext) async {
        do {
            let logId = UUID(uuidString: id) ?? UUID()
            let log = try context.fetch(FetchDescriptor<PromptLog>(predicate: #Predicate { $0.id == logId })).first
            log?.deliveredAt = deliveredAt
            switch action {
            case UNNotificationDismissActionIdentifier:
                log?.outcome = .ignored
            case Action.notNow.rawValue:
                log?.outcome = .notNow
            default:
                if let energy = Action(rawValue: action)?.energy {
                    let checkIn = try CheckInRecorder(context: context).record(
                        energy: energy, channel: .notification, promptedAt: deliveredAt, at: now, common: nil)
                    log?.outcome = .answered
                    log?.checkInId = checkIn.id
                }
            }
            try context.save()
        } catch {
            print("Answer not stored: \(error)")
        }
    }

    /// Gives the waiting answers their state at the time they were given; stops while Apple
    /// Health cannot be read (phone locked).
    func complete(context: ModelContext) async throws {
        guard let healthProvider,
              try context.fetchCount(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.zEnergy == nil })) > 0
        else { return }
        let provider = try healthProvider()
        let estimator = try StateEstimator.bundled()
        let done = try await CheckInRecorder(context: context).completePending { date in
            try await CurrentState.compute(provider: provider, estimator: estimator, now: date).estimate
        }
        if done > 0 { print("Answers completed: \(done)") }
    }

    /// On the main actor: iOS's completion handler, called when this returns, must run on the
    /// main thread (a background thread stopped the app on the iPhone).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.categoryIdentifier == Self.category else { return }
        let id = response.notification.request.identifier
        let action = response.actionIdentifier
        let date = response.notification.date
        await answer(id: id, action: action, deliveredAt: date)
    }

    private func answer(id: String, action: String, deliveredAt: Date) async {
        guard let container else { return }
        let context = container().mainContext
        await handle(id: id, action: action, deliveredAt: deliveredAt, context: context)
        // The state now if Apple Health can be read, else at the next return to the app.
        do {
            try await complete(context: context)
        } catch {
            print("Answer not completed: \(error)")
        }
    }

    /// The question shows even while the app is open. On the main actor, like the answer.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
