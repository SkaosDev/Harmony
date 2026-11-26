import Foundation

/// What the "Your answers" card of About shows (TODO 6.16, design `V2-APropos`): for each answer
/// of the last 14 days, the estimate of the watch alone and the one with the answers, both taken
/// just before the answer (`pCommonBefore`, `pPersonalBefore`), whether the answer was above the
/// usual, and a sentence from the offset learned so far. Never an emotion, never shown elsewhere.
enum LearnedCurve {
    /// The curve appears from this many answers in the 14 days: the 6th is the first compared to the usual.
    static let minimumAnswers = PersonalLayer.minimumPastAnswers + 1

    struct Point: Equatable {
        let answeredAt: Date
        let watchOnly: Double
        let withAnswers: Double
        /// "Above your usual", fixed at the answer; nil before 5 earlier answers.
        let above: Bool?
    }

    enum Headline: Equatable {
        case more, less, noClearDifference
    }

    enum Content: Equatable {
        /// Fewer than `minimumAnswers` answers in the 14 days: how many so far.
        case few(count: Int)
        case curve(points: [Point], headline: Headline)
    }

    static func content(answers: [CheckIn], now: Date) -> Content {
        let recent = answers.filter { now - PersonalLayer.window <= $0.answeredAt && $0.answeredAt <= now }
        guard recent.count >= minimumAnswers else { return .few(count: recent.count) }
        // An answer given with the phone locked has no estimates until the next unlock: not drawn yet.
        let points = recent.sorted { $0.answeredAt < $1.answeredAt }.compactMap { answer -> Point? in
            guard let watchOnly = answer.pCommonBefore, let withAnswers = answer.pPersonalBefore else { return nil }
            return Point(answeredAt: answer.answeredAt, watchOnly: watchOnly, withAnswers: withAnswers,
                         above: answer.labelEnergy)
        }
        // The offset does not depend on the common model's value at `now`, only on the answers.
        let offset = PersonalLayer.estimate(now: now, z: 0, observations: CheckInRecorder.energyObservations(answers)).offset
        return .curve(points: points, headline: headline(offset: offset))
    }

    /// Same threshold as the queue's reason "your answers show more/less energy than usual".
    static func headline(offset: Double) -> Headline {
        if offset >= Explainer.notableOffset { return .more }
        if offset <= -Explainer.notableOffset { return .less }
        return .noClearDifference
    }
}
