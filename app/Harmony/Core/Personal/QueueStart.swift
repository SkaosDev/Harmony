import Foundation
import SwiftData

/// Shadow or active (decision D4, design v2 §4.5, §15). In shadow, the personal layer is computed
/// and logged only: queues start from the rank and always use S1, Home has no energy row. In
/// active, the answers change `e0`, `v0`, the queue reason and the strategy.
nonisolated enum PersonalMode {
    case shadow, active

    /// The one switch. Active from the evening of pilot day 1 (D4 revised, `docs/pilot-protocol.md`
    /// §10.6); shadow before.
    static let current: PersonalMode = .active
}

/// Where a queue's `e0` came from (`QueueRecord.e0Source`, TODO 6.12).
nonisolated enum E0Source: String, Codable {
    /// The rank among the person's own grid predictions (§4.3).
    case rank
    /// The common probability, fewer than 32 grid points.
    case raw
    /// σ(z_E + b_E): at least 5 labelled energy answers in the 14 days (active mode only).
    case personal
}

/// The state a queue starts from (TODO 6.11, design v2 §4.5).
struct QueueStart: Equatable {
    let e0: Double
    let e0Source: E0Source
    /// Pleasantness 0…1 from the answers: active mode with at least 5 labelled pleasantness
    /// answers. Internal, never shown (D2).
    let v0: Double?
    /// The common model's probability at the start.
    let pCommon: Double
    /// The personal probability σ(z_E + b_E), computed in both modes (b_E = 0 without answers).
    let pPersonal: Double
    /// b_E when it chose `e0`, for the queue reason; nil otherwise.
    let energyOffset: Double?

    /// - shadow: the rank, or the raw probability with fewer than 32 grid points;
    /// - active: σ(z_E + b_E) with at least 5 labelled energy answers in the 14 days, else as
    ///   shadow; `v0` with at least 5 labelled pleasantness answers.
    static func choose(state: CurrentState, personal: PersonalState, mode: PersonalMode) -> QueueStart {
        let usesAnswers = mode == .active && personal.energy.count >= PersonalLayer.minimumPastAnswers
        let fromGrid: E0Source = state.gridProbabilities.count >= PersonalRank.minimumRows ? .rank : .raw
        return QueueStart(
            e0: usesAnswers ? personal.energy.probability : state.rank,
            e0Source: usesAnswers ? .personal : fromGrid,
            v0: mode == .active && personal.pleasantness.count >= PersonalLayer.minimumPastAnswers
                ? personal.pleasantness.probability : nil,
            pCommon: state.estimate.value,
            pPersonal: personal.energy.probability,
            energyOffset: usesAnswers ? personal.energy.offset : nil)
    }

    /// `choose` with the answers stored on the phone.
    static func make(state: CurrentState, context: ModelContext, mode: PersonalMode = .current) throws -> QueueStart {
        choose(state: state, personal: try CheckInRecorder(context: context).personal(at: state.date, common: state.estimate),
               mode: mode)
    }
}
