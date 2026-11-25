import Foundation

/// `Resources/model_params.json`, written by `ml/export.py` (PROJECT.md §6.7). The app takes the
/// order of the model inputs from it (TODO 2.19); the energy model itself runs in Core ML.
/// `time_only` is the time-of-day model of the fallback mode (TODO 2.21). Version 3 (TODO 6.4)
/// has 17 features and the valence models `valence` and `valence_time_only` (PROJECT.md §6.8).
struct ModelParams: Decodable {
    let version: Int
    /// The feature names, in the order of the model inputs (v3: the 13 of v1, then the 4 raw windows).
    let features: [String]
    let timeOnly: LogisticParams
    /// Valence: internal, never shown, never used alone (PROJECT.md §6.8); nil before v3.
    let valence: LogisticParams?
    let valenceTimeOnly: LogisticParams?
    /// The energy model of `StateModel.mlmodel` as a plain logistic regression (the top-level
    /// medians, means, scales, coefficients and intercept): the same numbers (6.4: Core ML within
    /// 1e-16), cheap enough for the ~450 points of the rank grid (TODO 6.11).
    let energy: LogisticParams

    enum CodingKeys: String, CodingKey {
        case version, features, valence, timeOnly = "time_only", valenceTimeOnly = "valence_time_only"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        features = try container.decode([String].self, forKey: .features)
        timeOnly = try container.decode(LogisticParams.self, forKey: .timeOnly)
        valence = try container.decodeIfPresent(LogisticParams.self, forKey: .valence)
        valenceTimeOnly = try container.decodeIfPresent(LogisticParams.self, forKey: .valenceTimeOnly)
        energy = try LogisticParams(from: decoder)
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
