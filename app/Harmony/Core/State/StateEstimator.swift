import CoreML
import Foundation

/// The state 0…1: how likely the person is more activated than usual. A number, never an
/// emotion (NFR7).
struct StateEstimate: Equatable {
    typealias Mode = EstimateMode

    let value: Double
    let mode: Mode
    /// How likely the moment is more pleasant than usual, same mode (TODO 6.4). Internal: never
    /// shown as an emotion, never used alone (PROJECT.md §6.8); nil without a valence model.
    var valence: Double? = nil
}

/// Which model gave the state; stored with each queue (`QueueRecord.stateMode`).
nonisolated enum EstimateMode: String, Codable {
    /// The 17-feature model: time, heart rate, steps and sleep (TODO 2.20, 6.4).
    case body
    /// Time of day only (TODO 2.21): no heart rate in the last 30 min.
    case timeOnly
}

/// Estimates the state from the features of `FeatureBuilder` (TODO 2.20, 2.21, 6.4). The energy
/// model is `StateModel.mlmodel` (`ml/export.py`): imputation of unknown values by the training
/// medians, standardization and logistic regression, all inside Core ML. The valence models are
/// the same computation from `model_params.json` (`LogisticParams`).
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

    /// Time-only mode when `raw_hr_30` is unknown: no heart rate in the last 30 min. Otherwise
    /// the model, even without a reference yet: unknown z-scores take the training medians
    /// (v3 rule, PROJECT.md §6.8). The valence follows the same rule.
    func estimate(_ features: [String: Double?]) throws -> StateEstimate {
        if (features["raw_hr_30"] ?? nil) == nil {
            let row = try FeatureBuilder.row(features, order: params.timeOnly.features)
            return StateEstimate(value: params.timeOnly.probability(row), mode: .timeOnly,
                                 valence: try valence(params.valenceTimeOnly, features))
        }
        let row = try FeatureBuilder.row(features, order: params.features)
        return StateEstimate(value: try modelProbability(row), mode: .body,
                             valence: try valence(params.valence, features))
    }

    /// The energy probability by the same mode rule, from `model_params.json` instead of Core ML:
    /// for the points of the rank grid (TODO 6.11).
    func gridProbability(_ features: [String: Double?]) throws -> Double {
        let model = (features["raw_hr_30"] ?? nil) == nil ? params.timeOnly : params.energy
        return model.probability(try FeatureBuilder.row(features, order: model.features))
    }

    private func valence(_ model: LogisticParams?, _ features: [String: Double?]) throws -> Double? {
        guard let model else { return nil }
        return model.probability(try FeatureBuilder.row(features, order: model.features))
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
