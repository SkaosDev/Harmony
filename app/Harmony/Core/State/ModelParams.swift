import Foundation

/// `Resources/model_params.json`, written by `ml/export.py` (PROJECT.md §6.7). The app takes the
/// order of the model inputs from it (TODO 2.19); the 13-feature model itself runs in Core ML.
/// `time_only` is the time-of-day model of the fallback mode (TODO 2.21).
struct ModelParams: Decodable {
    let version: Int
    /// The 13 feature names, in the order of the model inputs.
    let features: [String]
    let timeOnly: LogisticParams

    enum CodingKeys: String, CodingKey {
        case version, features, timeOnly = "time_only"
    }

    static func bundled(_ bundle: Bundle = .main) throws -> ModelParams {
        guard let url = bundle.url(forResource: "model_params", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(ModelParams.self, from: Data(contentsOf: url))
    }
}

/// A logistic regression as exported by `ml/export.py`: median imputation, standardization,
/// then the logistic function (the same computation as `export.predict`).
struct LogisticParams: Decodable {
    let features: [String]
    let medians: [Double]
    let means: [Double]
    let scales: [Double]
    let coefficients: [Double]
    let intercept: Double

    /// Probability of class 1 for a row in `features` order; nil = unknown (median).
    func probability(_ row: [Double?]) -> Double {
        precondition(row.count == features.count, "one value per feature")
        var logit = intercept
        for i in row.indices {
            logit += coefficients[i] * ((row[i] ?? medians[i]) - means[i]) / scales[i]
        }
        return 1 / (1 + exp(-logit))
    }
}
