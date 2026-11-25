import Foundation
import SwiftData

/// "My data" (TODO 3.19, FR13, `docs/design/V2-MesDonnees.dc.html`): what is stored on the phone,
/// its export as JSON, and its deletion.
enum DataControl {
    /// The numbers of `V2-MesDonnees`.
    struct Counts: Equatable {
        var songs = 0
        var scores = 0
        /// Hours and nights.
        var healthSummaries = 0
        var queues = 0
        var feedback = 0
        var checkIns = 0
    }

    /// `UserDefaults` keys the app writes; deleting everything removes them.
    static var storedKeys: [String] {
        [LibrarySync.importDateKey, RootView.onboardedKey, SpotifyPlaylist.idKey]
            + HealthSignal.allCases.map(HealthKitProvider.anchorKey) + PilotSchedule.keys + CheckInRecorder.keys
            + QuestionSettings.keys
    }

    static func counts(in context: ModelContext) throws -> Counts {
        Counts(songs: try context.fetchCount(FetchDescriptor<Track>()),
               scores: try context.fetchCount(FetchDescriptor<SongScore>()),
               healthSummaries: try context.fetchCount(FetchDescriptor<HourSummary>())
                   + context.fetchCount(FetchDescriptor<NightSummary>()),
               queues: try context.fetchCount(FetchDescriptor<QueueRecord>()),
               feedback: try context.fetchCount(FetchDescriptor<FeedbackEvent>()),
               checkIns: try context.fetchCount(FetchDescriptor<CheckIn>()))
    }

    /// Every table, as JSON (dates in ISO 8601).
    static func exportJSON(from context: ModelContext, at date: Date = .now) throws -> Data {
        let export = Export(
            exportedAt: date,
            tracks: try context.fetch(FetchDescriptor<Track>()).map {
                .init(spotifyId: $0.spotifyId, title: $0.title, artists: $0.artists, coverURL: $0.coverURL,
                      source: $0.source.rawValue, addedAt: $0.addedAt)
            },
            songScores: try context.fetch(FetchDescriptor<SongScore>()).map {
                .init(spotifyId: $0.spotifyId, energy: $0.energy, positivity: $0.positivity, origin: $0.origin.rawValue)
            },
            hourSummaries: try context.fetch(FetchDescriptor<HourSummary>(sortBy: [SortDescriptor(\.hourStart)])).map {
                .init(hourStart: $0.hourStart, meanHR: $0.meanHR, hrCount: $0.hrCount, sdnnHRV: $0.sdnnHRV, steps: $0.steps)
            },
            nightSummaries: try context.fetch(FetchDescriptor<NightSummary>(sortBy: [SortDescriptor(\.date)])).map {
                .init(date: $0.date, sleepMinutes: $0.sleepMinutes, sleepEnd: $0.sleepEnd, wornFraction: $0.wornFraction)
            },
            queues: try context.fetch(FetchDescriptor<QueueRecord>(sortBy: [SortDescriptor(\.createdAt)])).map { queue in
                .init(id: queue.id, createdAt: queue.createdAt, situation: queue.situation.rawValue,
                      startEnergy: queue.startEnergy, stateMode: queue.stateMode?.rawValue,
                      strategy: queue.strategy?.rawValue, strategyProbability: queue.strategyProbability,
                      e0Source: queue.e0Source?.rawValue, pCommon: queue.pCommon, pPersonal: queue.pPersonal,
                      v0: queue.v0, reason: queue.reason,
                      items: queue.items.sorted { $0.position < $1.position }.map {
                          .init(position: $0.position, spotifyId: $0.spotifyId, targetEnergy: $0.targetEnergy,
                                isSuggestion: $0.isSuggestion)
                      })
            },
            feedback: try context.fetch(FetchDescriptor<FeedbackEvent>(sortBy: [SortDescriptor(\.time)])).map {
                .init(queueId: $0.queueId, spotifyId: $0.spotifyId, event: $0.event.rawValue, seconds: $0.seconds, time: $0.time)
            },
            consents: try context.fetch(FetchDescriptor<Consent>(sortBy: [SortDescriptor(\.time)])).map {
                .init(source: $0.source.rawValue, granted: $0.granted, time: $0.time)
            },
            checkIns: try context.fetch(FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.answeredAt)])).map {
                .init(id: $0.id, answeredAt: $0.answeredAt, channel: $0.channel.rawValue, promptedAt: $0.promptedAt,
                      energy: $0.energy, pleasantness: $0.pleasantness, zEnergy: $0.zEnergy, zPleasantness: $0.zPleasantness,
                      estimateMode: $0.estimateMode?.rawValue, labelEnergy: $0.labelEnergy,
                      labelPleasantness: $0.labelPleasantness, usableForLearning: $0.usableForLearning,
                      pCommonBefore: $0.pCommonBefore, pPersonalBefore: $0.pPersonalBefore, dayOfUse: $0.dayOfUse)
            },
            prompts: try context.fetch(FetchDescriptor<PromptLog>(sortBy: [SortDescriptor(\.scheduledAt)])).map {
                .init(id: $0.id, scheduledAt: $0.scheduledAt, deliveredAt: $0.deliveredAt, outcome: $0.outcome?.rawValue,
                      checkInId: $0.checkInId)
            })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    /// Deletes everything (FR13): the 10 tables, the Spotify tokens (`signOut`), the HealthKit
    /// anchors, the import date, the onboarding flag and the pilot start day. The app then starts again at the
    /// onboarding.
    static func deleteAll(in context: ModelContext, defaults: UserDefaults = .standard,
                          signOut: () throws -> Void) throws {
        // Queues one by one: a batch delete refuses the link between a queue and its items; the
        // cascade takes the items.
        try context.fetch(FetchDescriptor<QueueRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<QueueItem>()).forEach(context.delete)
        try context.delete(model: FeedbackEvent.self)
        try context.delete(model: SongScore.self)
        try context.delete(model: Track.self)
        try context.delete(model: HourSummary.self)
        try context.delete(model: NightSummary.self)
        try context.delete(model: Consent.self)
        try context.delete(model: CheckIn.self)
        try context.delete(model: PromptLog.self)
        try context.save()
        try signOut()
        storedKeys.forEach(defaults.removeObject(forKey:))
    }

    private struct Export: Encodable {
        struct TrackRow: Encodable {
            let spotifyId: String, title: String, artists: [String], coverURL: URL?, source: String, addedAt: Date
        }
        struct ScoreRow: Encodable {
            let spotifyId: String, energy: Double, positivity: Double, origin: String
        }
        struct HourRow: Encodable {
            let hourStart: Date, meanHR: Double?, hrCount: Int, sdnnHRV: Double?, steps: Int?
        }
        struct NightRow: Encodable {
            let date: Date, sleepMinutes: Double?, sleepEnd: Date?, wornFraction: Double
        }
        struct ItemRow: Encodable {
            let position: Int, spotifyId: String, targetEnergy: Double, isSuggestion: Bool
        }
        struct QueueRow: Encodable {
            let id: UUID, createdAt: Date, situation: String, startEnergy: Double, stateMode: String?
            let strategy: String?, strategyProbability: Double?, e0Source: String?
            let pCommon: Double?, pPersonal: Double?, v0: Double?
            let reason: String
            let items: [ItemRow]
        }
        struct FeedbackRow: Encodable {
            let queueId: UUID, spotifyId: String?, event: String, seconds: Double?, time: Date
        }
        struct ConsentRow: Encodable {
            let source: String, granted: Bool, time: Date
        }
        struct CheckInRow: Encodable {
            let id: UUID, answeredAt: Date, channel: String, promptedAt: Date?
            let energy: Int, pleasantness: Int?, zEnergy: Double?, zPleasantness: Double?, estimateMode: String?
            let labelEnergy: Bool?, labelPleasantness: Bool?, usableForLearning: Bool
            let pCommonBefore: Double?, pPersonalBefore: Double?, dayOfUse: Int
        }
        struct PromptRow: Encodable {
            let id: UUID, scheduledAt: Date, deliveredAt: Date?, outcome: String?, checkInId: UUID?
        }

        let exportedAt: Date
        let tracks: [TrackRow]
        let songScores: [ScoreRow]
        let hourSummaries: [HourRow]
        let nightSummaries: [NightRow]
        let queues: [QueueRow]
        let feedback: [FeedbackRow]
        let consents: [ConsentRow]
        let checkIns: [CheckInRow]
        let prompts: [PromptRow]
    }
}
