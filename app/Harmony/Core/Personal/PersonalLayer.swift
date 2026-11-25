import Foundation

/// One past answer as the personal layer sees it: its value, the common model's logit at the
/// answer, its fixed label and whether it may be learned from.
nonisolated struct PersonalObservation: Equatable, Sendable {
    let answeredAt: Date
    let value: Int
    let z: Double
    /// "Above your usual", fixed at the answer; nil with fewer than 5 earlier answers.
    let label: Bool?
    var usable = true
}

/// The personal layer (TODO 6.8, design v2 §4.4, PROJECT.md §6.8): a logit offset `b` learned on
/// the phone from the user's answers, on top of the frozen common model. Without a labelled answer
/// `b` is exactly 0, so day one is the common model. Same computation as `ml/personal_layer.py`,
/// checked against `ml/fixtures/personal_layer_cases.json`.
nonisolated enum PersonalLayer {
    /// Answers older than this are not used, for the label or the offset.
    static let window: TimeInterval = 14 * 86400
    /// A label needs at least this many earlier answers in the window.
    static let minimumPastAnswers = 5
    /// Forgetting: an answer weighs exp(−age / 2 days), half after ≈ 1.4 day (6.5: T = 2).
    static let decayDays = 2.0
    /// Gaussian prior on the offset (6.5: τ_E = 2, τ_V = 1.5).
    static let energyPriorStd = 2.0
    static let pleasantnessPriorStd = 1.5
    static let newtonSteps = 5

    struct Estimate: Equatable {
        /// `b`, the logit offset.
        let offset: Double
        /// σ(z + b).
        let probability: Double
        /// Usable labelled answers of the window: ≥ 5 lets the active mode use `probability`.
        let count: Int
    }

    /// The label of an answer, fixed when it is recorded: true when it is above the mean of the
    /// answers of [t − 14 days, t), with at least 5 of them (strictly above; equal is false).
    /// Usability does not matter here: the usual level counts every answer.
    static func pastLabel(at answeredAt: Date, value: Int, prior: [(answeredAt: Date, value: Int)]) -> Bool? {
        let values = prior.filter { answeredAt - window <= $0.answeredAt && $0.answeredAt < answeredAt }.map(\.value)
        guard values.count >= minimumPastAnswers else { return nil }
        return Double(value) > Double(values.reduce(0, +)) / Double(values.count)
    }

    /// The offset at `now` from the usable labelled answers of [now − 14 days, now): 5 Newton
    /// steps from 0 on the weighted log-loss plus the prior. Ages are measured from `now`, so
    /// `b` goes back toward 0 when the answers stop.
    static func estimate(now: Date, z: Double, observations: [PersonalObservation],
                         priorStd: Double = energyPriorStd) -> Estimate {
        let used = observations.filter {
            $0.usable && $0.label != nil && now - window <= $0.answeredAt && $0.answeredAt < now
        }
        guard !used.isEmpty else { return Estimate(offset: 0, probability: sigmoid(z), count: 0) }
        let prior = 1 / (priorStd * priorStd)
        var offset = 0.0
        for _ in 0..<newtonSteps {
            var gradient = offset * prior
            var hessian = prior
            for item in used {
                let weight = exp(-(now.timeIntervalSince(item.answeredAt) / 86400) / decayDays)
                let probability = sigmoid(item.z + offset)
                gradient += weight * (probability - (item.label! ? 1 : 0))
                hessian += weight * probability * (1 - probability)
            }
            offset -= gradient / hessian
        }
        return Estimate(offset: offset, probability: sigmoid(z + offset), count: used.count)
    }

    static func sigmoid(_ value: Double) -> Double { 1 / (1 + exp(-value)) }

    /// The logit of a probability of the common model (strictly between 0 and 1).
    static func logit(_ probability: Double) -> Double { log(probability / (1 - probability)) }
}
