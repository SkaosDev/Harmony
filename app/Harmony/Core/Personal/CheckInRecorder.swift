import Foundation
import SwiftData

/// The personal layer at an instant: the energy offset and, when the user answers the optional
/// pleasantness question, the pleasantness offset (internal, never shown as an emotion, D2).
struct PersonalState: Equatable {
    let energy: PersonalLayer.Estimate
    let pleasantness: PersonalLayer.Estimate
}

/// Records the answers to "Energy right now?" (TODO 6.8, design v2 §4.4, §6) and computes the
/// personal layer from them. Everything stays on the phone.
struct CheckInRecorder {
    let context: ModelContext
    var defaults: UserDefaults = .standard
    var calendar: Calendar = .current

    /// Day 1 of `CheckIn.dayOfUse`: the day of the first answer, again after "Reset what Harmony
    /// learned" or "Delete everything".
    static let firstDayKey = "personal.firstDay"
    /// Time of the last "Reset what Harmony learned": the strategy choice only learns from the
    /// queues after it (`QueueBandit`).
    static let resetAtKey = "personal.resetAt"
    static let keys = [firstDayKey, resetAtKey]
    /// Answers given during a queue or within this time after it are not learned from.
    static let afterQueue: TimeInterval = 60 * 60
    /// Check-ins are kept for 30 days (`V2-MesDonnees`); after 14 days they weigh nothing.
    static let retention: TimeInterval = 30 * 86400
    /// Pleasantness prior without a valence model: logit(0.566), the base rate of D-1 + D-2 (§6.8).
    static let constantPleasantness = 0.566

    /// Records an answer. `common` is the common model's state at the answer; nil when the
    /// health data cannot be read (phone locked): `completePending` fills it later.
    @discardableResult
    func record(energy: Int, pleasantness: Int? = nil, channel: CheckInChannel, promptedAt: Date? = nil,
                at date: Date, common: StateEstimate?) throws -> CheckIn {
        let earlier = try context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.answeredAt < date }))
        let checkIn = CheckIn(
            answeredAt: date, channel: channel, promptedAt: promptedAt, energy: energy, pleasantness: pleasantness,
            labelEnergy: PersonalLayer.pastLabel(at: date, value: energy,
                                                 prior: earlier.map { ($0.answeredAt, $0.energy) }),
            labelPleasantness: pleasantness.flatMap { value in
                PersonalLayer.pastLabel(at: date, value: value,
                                        prior: earlier.compactMap { item in item.pleasantness.map { (item.answeredAt, $0) } })
            },
            usableForLearning: try !Self.isNearQueue(date, in: context),
            dayOfUse: dayOfUse(date))
        if let common {
            fill(checkIn, common: common, earlier: earlier)
        }
        context.insert(checkIn)
        try context.save()
        return checkIn
    }

    /// Gives the answers recorded without the common model (phone locked) their logits and the
    /// chronological pair, oldest first, at the instant of each answer. Stops at the first state
    /// that cannot be computed (still locked). Returns the number completed.
    @discardableResult
    func completePending(state: (Date) async throws -> StateEstimate) async throws -> Int {
        let pending = try context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.zEnergy == nil },
                                                                 sortBy: [SortDescriptor(\.answeredAt)]))
        var done = 0
        for checkIn in pending {
            guard let common = try? await state(checkIn.answeredAt) else { break }
            let date = checkIn.answeredAt
            fill(checkIn, common: common,
                 earlier: try context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.answeredAt < date })))
            done += 1
        }
        if done > 0 { try context.save() }
        return done
    }

    /// The personal layer at `now`, on top of the common model's state at `now`.
    func personal(at now: Date, common: StateEstimate) throws -> PersonalState {
        let answers = try context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.answeredAt < now }))
        return PersonalState(
            energy: PersonalLayer.estimate(now: now, z: PersonalLayer.logit(common.value),
                                           observations: Self.energyObservations(answers)),
            pleasantness: PersonalLayer.estimate(now: now, z: Self.pleasantnessZ(common),
                                                 observations: Self.pleasantnessObservations(answers),
                                                 priorStd: PersonalLayer.pleasantnessPriorStd))
    }

    /// Removes check-ins and notification rows older than 30 days.
    func deleteExpired(now: Date = .now) throws {
        let limit = now - Self.retention
        try context.delete(model: CheckIn.self, where: #Predicate { $0.answeredAt < limit })
        try context.delete(model: PromptLog.self, where: #Predicate { $0.scheduledAt < limit })
        try context.save()
    }

    /// "Reset what Harmony learned": the answers go, the offsets are back to 0, the day of use
    /// starts again and the strategy choice forgets the earlier queues (TODO 6.13).
    func reset(now: Date = .now) throws {
        try context.delete(model: CheckIn.self)
        try context.delete(model: PromptLog.self)
        try context.save()
        defaults.removeObject(forKey: Self.firstDayKey)
        defaults.set(now.timeIntervalSince1970, forKey: Self.resetAtKey)
    }

    /// The last "Reset what Harmony learned", if any.
    var resetAt: Date? {
        (defaults.object(forKey: Self.resetAtKey) as? Double).map(Date.init(timeIntervalSince1970:))
    }

    // MARK: Rules

    /// True during a queue or less than an hour after it. A queue ends at its last feedback
    /// event (skip, like, finish, "Did it fit?"), or at its start when it has none.
    static func isNearQueue(_ date: Date, in context: ModelContext) throws -> Bool {
        try queueSpans(before: date, in: context).contains { $0.lowerBound <= date && date < $0.upperBound + afterQueue }
    }

    /// Start and end of the queues started in the day before `date`.
    static func queueSpans(before date: Date, in context: ModelContext) throws -> [ClosedRange<Date>] {
        let since = date - 86400
        let queues = try context.fetch(FetchDescriptor<QueueRecord>(predicate: #Predicate {
            $0.createdAt >= since && $0.createdAt <= date
        }))
        guard !queues.isEmpty else { return [] }
        let events = try context.fetch(FetchDescriptor<FeedbackEvent>(predicate: #Predicate { $0.time >= since }))
        let lastEvent = Dictionary(events.map { ($0.queueId, $0.time) }, uniquingKeysWith: { max($0, $1) })
        return queues.map { $0.createdAt...max($0.createdAt, lastEvent[$0.id] ?? $0.createdAt) }
    }

    private static func energyObservations(_ answers: [CheckIn]) -> [PersonalObservation] {
        answers.compactMap { answer in
            answer.zEnergy.map {
                PersonalObservation(answeredAt: answer.answeredAt, value: answer.energy, z: $0,
                                    label: answer.labelEnergy, usable: answer.usableForLearning)
            }
        }
    }

    private static func pleasantnessObservations(_ answers: [CheckIn]) -> [PersonalObservation] {
        answers.compactMap { answer in
            guard let value = answer.pleasantness, let z = answer.zPleasantness else { return nil }
            return PersonalObservation(answeredAt: answer.answeredAt, value: value, z: z,
                                       label: answer.labelPleasantness, usable: answer.usableForLearning)
        }
    }

    private static func pleasantnessZ(_ common: StateEstimate) -> Double {
        PersonalLayer.logit(common.valence ?? constantPleasantness)
    }

    private func fill(_ checkIn: CheckIn, common: StateEstimate, earlier: [CheckIn]) {
        let z = PersonalLayer.logit(common.value)
        checkIn.zEnergy = z
        checkIn.zPleasantness = Self.pleasantnessZ(common)
        checkIn.estimateMode = common.mode
        checkIn.pCommonBefore = common.value
        checkIn.pPersonalBefore = PersonalLayer.estimate(now: checkIn.answeredAt, z: z,
                                                         observations: Self.energyObservations(earlier)).probability
    }

    private func dayOfUse(_ date: Date) -> Int {
        let today = calendar.startOfDay(for: date)
        let first: Date
        if let stored = defaults.object(forKey: Self.firstDayKey) as? Double {
            first = Date(timeIntervalSince1970: stored)
        } else {
            first = today
            defaults.set(today.timeIntervalSince1970, forKey: Self.firstDayKey)
        }
        return calendar.dateComponents([.day], from: first, to: today).day! + 1
    }
}
