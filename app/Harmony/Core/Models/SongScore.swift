import Foundation
import SwiftData

/// Energy and positivity of a song, both between 0 and 1 (TODO 1.8, PROJECT.md §7).
/// Kept apart from `Track`: MuSe suggestions outside the library have a score too.
/// One row per Spotify ID, so a song is never scored twice.
@Model
final class SongScore {
    @Attribute(.unique) var spotifyId: String
    /// 0 = calm, 1 = energetic (MuSe arousal or LLM).
    var energy: Double
    /// 0 = negative, 1 = positive (MuSe valence or LLM).
    var positivity: Double
    var origin: ScoreOrigin

    init(spotifyId: String, energy: Double, positivity: Double, origin: ScoreOrigin) {
        self.spotifyId = spotifyId
        self.energy = energy
        self.positivity = positivity
        self.origin = origin
    }
}

/// Where a score comes from. `neutral` is the 0.5 / 0.5 placeholder used when neither MuSe
/// nor the LLM gave a valid score.
enum ScoreOrigin: String, Codable {
    case muse, llm, neutral
}
