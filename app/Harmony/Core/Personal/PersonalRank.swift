import Foundation

/// `e0` without answers (TODO 6.11, design v2 §4.3, PROJECT.md §6.8): the rank of the current
/// probability among the person's own predictions on the reference grid (every 30 min, 08:00–23:30,
/// 14 days before, watch worn). It spreads `e0` over 0…1 where the raw probability stays in
/// ≈ 0.36–0.55. Same rule as `ml/simulate_wp_b0.py` and `ml/features.py` `rank_reference`, checked
/// against `ml/fixtures/rank_cases.json` and `rank_grid_cases.json`.
enum PersonalRank {
    /// About one day of wear; below it, `e0` is the raw probability.
    nonisolated static let minimumRows = 32

    /// Share of the grid probabilities ≤ `probability` (ties count), or `probability` itself with
    /// fewer than 32 grid points.
    nonisolated static func e0(probability: Double, grid: [Double]) -> Double {
        guard grid.count >= minimumRows else { return probability }
        return Double(grid.filter { $0 <= probability }.count) / Double(grid.count)
    }

    /// The worn grid points (a heart rate in their last 30 min; steps alone do not count), each
    /// with its features scored with the single reference of the prediction instant (`baseline`,
    /// `sleepReference`), its own window values, time and the night of its own day.
    static func rows(grid: [GridPoint], baseline: Baseline, sleepReference: Reference?, nights: [NightSummary],
                     calendar: Calendar) -> [(time: Date, features: [String: Double?])] {
        grid.filter { $0.values[.hr30] != nil }.map { point in
            (point.time, FeatureBuilder.features(at: point.time, values: point.values, baseline: baseline,
                                                 sleepReference: sleepReference, nights: nights, calendar: calendar))
        }
    }
}
