import Foundation

/// `Resources/model_params.json`, written by `ml/export.py` (PROJECT.md §6.7). The app takes the
/// order of the model inputs from it (TODO 2.19); the 13-feature model itself runs in Core ML.
struct ModelParams: Decodable {
    let version: Int
    /// The 13 feature names, in the order of the model inputs.
    let features: [String]

    static func bundled(_ bundle: Bundle = .main) throws -> ModelParams {
        guard let url = bundle.url(forResource: "model_params", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(ModelParams.self, from: Data(contentsOf: url))
    }
}
