import CoreML
import Foundation

/// The state 0…1: how likely the person is more activated than usual (TODO 2.20). A number,
/// never an emotion (NFR7). The 13-feature model is `StateModel.mlmodel` (`ml/export.py`):
/// imputation of unknown values by the training medians, standardization and logistic
/// regression, all inside Core ML.
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
