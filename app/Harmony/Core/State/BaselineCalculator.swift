import Foundation

/// The six window quantities of PROJECT.md §6 « Features v1 », measured at an instant t over
/// `(t − w, t]`: mean heart rate and log(1 + steps) for w = 15, 30, 60 min.
enum WindowQuantity: String, CaseIterable, Sendable {
    case hr15 = "hr_15", hr30 = "hr_30", hr60 = "hr_60"
    case logSteps15 = "log_steps_15", logSteps30 = "log_steps_30", logSteps60 = "log_steps_60"

    var minutes: Double {
        switch self {
        case .hr15, .logSteps15: 15
        case .hr30, .logSteps30: 30
        case .hr60, .logSteps60: 60
        }
    }

    var isHeartRate: Bool { [.hr15, .hr30, .hr60].contains(self) }
}

/// Heart rate and steps of the watch, ready for window sums (§6, as `ml/features.py`).
/// Lives in memory only: raw samples are never stored (§11).
struct WatchSeries {
    /// One heart rate per 5-minute slice of the clock: the first reading of the slice.
    let heartRate: [HealthSample]
    private let heartRateTimes: [TimeInterval]
    private let heartRateSums: [Double]
    private let stepTimes: [TimeInterval]
    private let stepSums: [Double]

    static let resampleSeconds: TimeInterval = 5 * 60

    /// A step sample counts at its `start`, like a heart rate (the Python series are points).
    init(heartRate: [HealthSample], steps: [HealthSample]) {
        // Stable sort: of two readings at the same instant, the first one given wins.
        let sorted = heartRate.enumerated()
            .sorted { ($0.element.start, $0.offset) < ($1.element.start, $1.offset) }
            .map(\.element)
        var kept: [HealthSample] = []
        for sample in sorted where kept.last.map({ Self.slice($0.start) != Self.slice(sample.start) }) ?? true {
            kept.append(sample)
        }
        self.heartRate = kept
        heartRateTimes = kept.map(\.start.timeIntervalSince1970)
        heartRateSums = Self.prefixSums(kept.map(\.value))

        let steps = steps.enumerated()
            .sorted { ($0.element.start, $0.offset) < ($1.element.start, $1.offset) }
            .map(\.element)
        stepTimes = steps.map(\.start.timeIntervalSince1970)
        stepSums = Self.prefixSums(steps.map(\.value))
    }

    /// The window quantities at `t`; a missing key is unknown.
    /// - `hr_w`: mean heart rate, unknown without any reading.
    /// - `log_steps_w`: log(1 + steps); 0 when the watch is worn (a heart rate in the window)
    ///   without steps; unknown with neither heart rate nor steps.
    func values(at t: Date) -> [WindowQuantity: Double] {
        let end = t.timeIntervalSince1970
        var values: [WindowQuantity: Double] = [:]
        for quantity in WindowQuantity.allCases {
            let start = end - quantity.minutes * 60
            let (lo, hi) = (Self.upperBound(heartRateTimes, start), Self.upperBound(heartRateTimes, end))
            if quantity.isHeartRate {
                if hi > lo {
                    values[quantity] = (heartRateSums[hi] - heartRateSums[lo]) / Double(hi - lo)
                }
            } else {
                let (stepLo, stepHi) = (Self.upperBound(stepTimes, start), Self.upperBound(stepTimes, end))
                if hi > lo || stepHi > stepLo {
                    values[quantity] = log1p(stepSums[stepHi] - stepSums[stepLo])
                }
            }
        }
        return values
    }

    private static func slice(_ date: Date) -> Double {
        (date.timeIntervalSince1970 / resampleSeconds).rounded(.down)
    }

    private static func prefixSums(_ values: [Double]) -> [Double] {
        values.reduce(into: [0]) { $0.append($0.last! + $1) }
    }

    /// Index of the first time > `x` in sorted `times`.
    private static func upperBound(_ times: [TimeInterval], _ x: TimeInterval) -> Int {
        var (lo, hi) = (0, times.count)
        while lo < hi {
            let mid = (lo + hi) / 2
            if times[mid] <= x { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

/// A personal reference: mean and standard deviation (n − 1).
struct Reference: Equatable, Sendable {
    let mean: Double
    let std: Double

    /// (value − mean) / std; unknown when the value is unknown or the deviation is 0.
    func z(_ value: Double?) -> Double? {
        guard let value, std > 0 else { return nil }
        return (value - mean) / std
    }
}

/// The personal references at an instant t (§6): what the z-scores compare with.
struct Baseline: Equatable, Sendable {
    /// Reference of each window quantity; missing until it is ready.
    let references: [WindowQuantity: Reference]
    /// Mean `hr_30` of the grid points of each 3-hour block (0 = 00–03 h … 7 = 21–24 h);
    /// missing until the block is ready.
    let hr30BlockMeans: [Int: Double]

    func z(_ quantity: WindowQuantity, _ value: Double?) -> Double? {
        references[quantity]?.z(value)
    }

    /// `zb_hr_30`: (hr_30 − mean of its block) / standard deviation of the whole `hr_30` grid.
    func zBlock(_ hr30: Double?, block: Int) -> Double? {
        guard let blockMean = hr30BlockMeans[block], let std = references[.hr30]?.std else { return nil }
        return Reference(mean: blockMean, std: std).z(hr30)
    }
}

/// Personal references on a regular grid, from the 14 days before t only (TODO 2.18, §6).
enum BaselineCalculator {
    static let referenceDays = 14
    /// A reference is ready when its values come from at least 7 distinct local days.
    static let readyDays = 7
    /// Grid: every 30 min from 08:00 to 23:30, local time (32 points a day).
    static let gridFirstHour = 8
    static let gridStepMinutes = 30
    static let gridPointsPerDay = 32
    static let blockHours = 3

    /// Grid instants in `[t − 14 days, t)`: nothing at or after t.
    static func gridPoints(before t: Date, calendar: Calendar) -> [Date] {
        let start = t.addingTimeInterval(-Double(referenceDays) * 86400)
        var points: [Date] = []
        var day = calendar.startOfDay(for: start)
        while day < t {
            for i in 0..<gridPointsPerDay {
                let minutes = gridFirstHour * 60 + i * gridStepMinutes
                let point = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)!
                if point >= start && point < t {
                    points.append(point)
                }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return points
    }

    /// 3-hour block of the local time of day: 0 = 00:00–03:00 … 7 = 21:00–24:00.
    static func block(of date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) / blockHours
    }

    /// Mean and standard deviation (n − 1) of known values; nil unless they come from at
    /// least `minDays` distinct days (`day` = start of the local day).
    static func reference(_ values: [(value: Double, day: Date)], minDays: Int) -> Reference? {
        guard Set(values.map(\.day)).count >= minDays else { return nil }
        let mean = values.reduce(0) { $0 + $1.value } / Double(values.count)
        let squares = values.reduce(0) { $0 + ($1.value - mean) * ($1.value - mean) }
        return Reference(mean: mean, std: (squares / Double(values.count - 1)).squareRoot())
    }

    /// The references at t: the window quantities on every grid point, unknown points left out.
    static func baseline(at t: Date, series: WatchSeries, calendar: Calendar) -> Baseline {
        var known: [WindowQuantity: [(value: Double, day: Date)]] = [:]
        var blocks: [Int: [(value: Double, day: Date)]] = [:]
        for point in gridPoints(before: t, calendar: calendar) {
            let day = calendar.startOfDay(for: point)
            let values = series.values(at: point)
            for (quantity, value) in values {
                known[quantity, default: []].append((value, day))
            }
            if let hr30 = values[.hr30] {
                blocks[block(of: point, calendar: calendar), default: []].append((hr30, day))
            }
        }
        return Baseline(
            references: known.compactMapValues { reference($0, minDays: readyDays) },
            hr30BlockMeans: blocks.compactMapValues { reference($0, minDays: readyDays)?.mean }
        )
    }
}
