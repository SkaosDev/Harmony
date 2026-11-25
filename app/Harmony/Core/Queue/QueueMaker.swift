import Foundation
import SwiftData

/// A queue ready to play.
struct PreparedQueue: Equatable {
    let situation: Situation
    /// State the queue starts from, 0…1.
    let e0: Double
    let reason: String
    let entries: [QueueEntry]
    /// Title, artists and cover of each entry, in queue order.
    let songs: [TrackInfo]
    /// Estimate the queue really started from: time only when the watch gave no recent heart rate.
    var stateMode: EstimateMode = .body
    /// How `e0` was chosen, with the common and personal probabilities (TODO 6.11, 6.12).
    var start: QueueStart? = nil
    /// The targets' strategy and the probability it had of being chosen (TODO 6.12).
    var strategy: QueueStrategy = .s1
    var strategyProbability = 1.0
}

/// Builds a queue from what is stored on the phone (TODO 3.2–3.8): library songs with a score,
/// earlier queues and feedback, the state, and the MuSe table; records it once it plays.
struct QueueMaker {
    let context: ModelContext
    /// Nil: no MuSe suggestion.
    let catalog: MuseCatalog?
    /// Checks the suggestions (TODO 3.6).
    let music: any MusicProvider
    var calendar: Calendar = .current
    var mode: PersonalMode = .current

    /// The queue for a situation, from the library (at most two MuSe suggestions).
    func prepare(_ situation: Situation, state: CurrentState) async throws -> PreparedQueue {
        let tracks = try context.fetch(FetchDescriptor<Track>())
        let scores = Dictionary(try context.fetch(FetchDescriptor<SongScore>()).map { ($0.spotifyId, $0) },
                                uniquingKeysWith: { first, _ in first })
        var library: [QueueCandidate] = []
        var genres = Set<String>()
        for track in tracks {
            guard let score = scores[track.spotifyId] else { continue }
            library.append(QueueCandidate(spotifyId: track.spotifyId, title: track.title, artists: track.artists,
                                          energy: score.energy, positivity: score.positivity, origin: score.origin))
            if score.origin == .muse,
               let genre = catalog?.genre(spotifyId: track.spotifyId, title: track.title, artists: track.artists) {
                genres.insert(genre)
            }
        }
        let suggestions = catalog.map {
            MuseSuggestions(catalog: $0, artistKeys: Set(tracks.map { SongKey.artist($0.artists.first ?? "") }), genres: genres)
        }
        return try await prepare(situation, state: state, library: library, suggestions: suggestions,
                                 maxSuggestions: QueueBuilder.maxSuggestions, tracks: tracks)
    }

    /// "Use suggested tracks" on the empty Home: MuSe songs only, each one checked, when the
    /// library has no score yet.
    func prepareMuseOnly(_ situation: Situation, state: CurrentState) async throws -> PreparedQueue {
        let suggestions = catalog.map { MuseSuggestions(catalog: $0, artistKeys: [], genres: [], anySong: true) }
        return try await prepare(situation, state: state, library: [], suggestions: suggestions,
                                 maxSuggestions: .max, tracks: [])
    }

    /// Stores the queue once it plays (`QueueRecord`, TODO 1.11), with the estimate it really
    /// used (TODO 4.4) and the design v2 log (TODO 6.12).
    @discardableResult
    func record(_ queue: PreparedQueue, id: UUID = UUID(), at date: Date = .now) throws -> QueueRecord {
        let items = queue.entries.enumerated().map { position, entry in
            QueueItem(position: position, spotifyId: entry.song.spotifyId, targetEnergy: entry.target,
                      isSuggestion: entry.song.isSuggestion)
        }
        let record = QueueRecord(id: id, createdAt: date, situation: queue.situation, startEnergy: queue.e0,
                                 stateMode: queue.stateMode, strategy: queue.strategy,
                                 strategyProbability: queue.strategyProbability, e0Source: queue.start?.e0Source,
                                 pCommon: queue.start?.pCommon, pPersonal: queue.start?.pPersonal, v0: queue.start?.v0,
                                 reason: queue.reason, items: items)
        context.insert(record)
        try context.save()
        return record
    }

    private func prepare(_ situation: Situation, state: CurrentState, library: [QueueCandidate],
                         suggestions: SuggestionSource?, maxSuggestions: Int, tracks: [Track]) async throws -> PreparedQueue {
        let start = try QueueStart.make(state: state, context: context, mode: mode)
        let e0 = start.e0
        let exclusions = try QueueHistory.exclusions(for: situation, now: state.date, in: context)
        let music = music
        let entries = await QueueBuilder.build(situation: situation, e0: e0, v0: start.v0, library: library, exclusions: exclusions,
                                               suggestions: suggestions, maxSuggestions: maxSuggestions) {
            await SuggestionCheck.verify($0, using: music)
        }
        let context = Explainer.Context(date: state.date, mode: state.estimate.mode,
                                        zSleep: state.features["z_sleep_min"] ?? nil,
                                        zHeartRate: state.features["z_hr_30"] ?? nil,
                                        zHRV: try hrvZ(now: state.date), energyOffset: start.energyOffset)
        let byId = Dictionary(tracks.map { ($0.spotifyId, $0) }, uniquingKeysWith: { first, _ in first })
        let songs = entries.map { entry in
            entry.info ?? byId[entry.song.spotifyId].map {
                TrackInfo(spotifyId: $0.spotifyId, title: $0.title, artists: $0.artists, coverURL: $0.coverURL)
            } ?? TrackInfo(spotifyId: entry.song.spotifyId, title: entry.song.title, artists: entry.song.artists, coverURL: nil)
        }
        return PreparedQueue(situation: situation, e0: e0,
                             reason: Explainer.reason(situation: situation, e0: e0, context: context, calendar: calendar),
                             entries: entries, songs: songs, stateMode: state.estimate.mode, start: start)
    }

    /// The HRV of the last hours against the person's usual (`Explainer.hrvZ`).
    private func hrvZ(now: Date) throws -> Double? {
        let since = now - Double(BaselineCalculator.referenceDays + 1) * 86400
        let hours = try context.fetch(FetchDescriptor<HourSummary>(predicate: #Predicate { $0.hourStart >= since }))
        return Explainer.hrvZ(hours: hours.compactMap { hour in hour.sdnnHRV.map { (hour.hourStart, $0) } },
                              now: now, calendar: calendar)
    }
}
