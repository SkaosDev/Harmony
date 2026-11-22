import CoreML
import Foundation

/// The state 0…1: how likely the person is more activated than usual. A number, never an
/// emotion (NFR7).
struct StateEstimate: Equatable {
    enum Mode {
        /// The 13-feature model: time, heart rate, steps and sleep (TODO 2.20).
        case body
        /// Time of day only (TODO 2.21): no reference yet, or no heart rate in the last 30 min.
        case timeOnly
    }

    let value: Double
    let mode: Mode
}

/// Estimates the state from the features of `FeatureBuilder` (TODO 2.20, 2.21). The 13-feature
/// model is `StateModel.mlmodel` (`ml/export.py`): imputation of unknown values by the training
/// medians, standardization and logistic regression, all inside Core ML.
struct StateEstimator {
    let params: ModelParams
    private let model: MLModel

    struct MissingProbability: Error {}

    static func bundled(_ bundle: Bundle = .main) throws -> StateEstimator {
        guard let url = bundle.url(forResource: "StateModel", withExtension: "mlmodelc") else {
            throw CocoaError(.fileNoSuchFile)
        }
        // CPU only: double precision, the same numbers as scikit-learn (PROJECT.md §6.7).
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        return StateEstimator(params: try .bundled(bundle),
                              model: try MLModel(contentsOf: url, configuration: configuration))
    }

    /// Time-only mode when `z_hr_30` is unknown: no heart rate in the last 30 min, no reference
    /// yet (fewer than 7 days) or a flat reference (standard deviation 0). Otherwise the model.
    func estimate(_ features: [String: Double?]) throws -> StateEstimate {
        if (features["z_hr_30"] ?? nil) == nil {
            let row = try FeatureBuilder.row(features, order: params.timeOnly.features)
            return StateEstimate(value: params.timeOnly.probability(row), mode: .timeOnly)
        }
        let row = try FeatureBuilder.row(features, order: params.features)
        return StateEstimate(value: try modelProbability(row), mode: .body)
    }

    /// Probability of class 1 (`arousal_high`) for a row in `params.features` order;
    /// unknown (nil) goes in as NaN, which the model replaces by the training median.
    func modelProbability(_ row: [Double?]) throws -> Double {
        precondition(row.count == params.features.count, "one value per model feature")
        var inputs: [String: MLFeatureValue] = [:]
        for (name, value) in zip(params.features, row) {
            inputs[name] = MLFeatureValue(double: value ?? .nan)
        }
        let output = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: inputs))
        let probabilities = output.featureValue(for: "classProbability")?.dictionaryValue ?? [:]
        guard let high = probabilities.first(where: { ($0.key.base as? NSNumber)?.int64Value == 1 }) else {
            throw MissingProbability()
        }
        return high.value.doubleValue
    }
}
