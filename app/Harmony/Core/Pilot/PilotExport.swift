import Foundation
import SwiftData

/// The anonymous pilot export (TODO 4.5, `docs/pilot-protocol.md` §7.2, format `harmony-pilot-2`):
/// for each queue started since pilot day 1, its pilot day and hour, situation,
/// estimate used, strategy, songs (position, score origin, MuSe suggestion or not), skip / like /
/// finish events and "Did it fit?" answer; watch coverage counts; for each check-in since day 1,
/// the chronological pair of design v2 §15 (day of use, label, common and personal probabilities
/// before the answer); counts of the questions sent. Never a Spotify ID, a song title, the queue
/// reason, the estimated state of a queue, a check-in answer or its time, a health value or an
/// absolute date. Read by `ml/pilot_analysis.py`; example in `ml/fixtures/pilot_export_example.json`.
enum PilotExport {
    static let format = "harmony-pilot-2"

    struct File: Codable, Equatable {
        let format: String
        /// Pilot days covered, the day of the export included.
        let days: Int
        let queues: [Queue]
        let watch: Watch
        /// In the order of the answers.
        let checkIns: [CheckInPair]
        let prompts: Prompts
    }

    /// One answer to the check-in question (decision D5): only what the chronological AUROC needs.
    struct CheckInPair: Codable, Equatable {
        let dayOfUse: Int
        /// "Above the usual"; nil with fewer than 5 earlier answers.
        let labelEnergy: Bool?
        /// σ(z) and σ(z + b) before the answer; nil while the answer waits for its state.
        let pCommonBefore: Double?
        let pPersonalBefore: Double?
    }

    /// Questions sent since day 1 (scheduled before the export), by outcome; `waiting` has none yet.
    struct Prompts: Codable, Equatable {
        let answered: Int
        let notNow: Int
        let ignored: Int
        let waiting: Int
    }

    struct Queue: Codable, Equatable {
        let day: Int
        /// Local hour of the start, 0…23.
        let hour: Int
        let situation: String
        /// Nil for a queue recorded before TODO 4.4.
        let stateMode: String?
        /// "s1" during the pilot (D4); nil for a queue recorded before TODO 6.12.
        let strategy: String?
        let items: [Item]
        let events: [Event]
        /// "yes", "no", or nil when "Did it fit?" was not answered.
        let fit: String?
    }

    struct Item: Codable, Equatable {
        let position: Int
        /// "muse", "llm", "neutral"; nil for a library song whose score is gone.
        let origin: String?
        let suggestion: Bool
    }

    struct Event: Codable, Equatable {
        let position: Int
        /// "skip" (< 30 s), "like" or "finish".
        let event: String
        let seconds: Double?
    }

    /// Counts only: nights with known sleep and hours with a heart rate, since pilot day 1.
    struct Watch: Codable, Equatable {
        let nightsKnown: Int
        /// Whole hours from the start of day 1 to the export.
        let hours: Int
        let hoursWithHR: Int
    }

    static func file(from context: ModelContext, schedule: PilotSchedule, now: Date = .now) throws -> File {
        let start = schedule.startDay
        let today = schedule.calendar.startOfDay(for: now)
        let scores = Dictionary(try context.fetch(FetchDescriptor<SongScore>()).map { ($0.spotifyId, $0.origin) },
                                uniquingKeysWith: { first, _ in first })
        let feedback = Dictionary(grouping: try context.fetch(FetchDescriptor<FeedbackEvent>(sortBy: [SortDescriptor(\.time)])),
                                  by: \.queueId)
        let queues = try context.fetch(FetchDescriptor<QueueRecord>(predicate: #Predicate { $0.createdAt >= start },
                                                                    sortBy: [SortDescriptor(\.createdAt)]))
        let nightsKnown = try context.fetch(FetchDescriptor<NightSummary>(predicate: #Predicate {
            $0.date >= start && $0.date <= today && $0.sleepMinutes != nil
        })).count
        let hoursWithHR = try context.fetchCount(FetchDescriptor<HourSummary>(predicate: #Predicate {
            $0.hourStart >= start && $0.hourStart < now && $0.hrCount > 0
        }))
        let checkIns = try context.fetch(FetchDescriptor<CheckIn>(predicate: #Predicate { $0.answeredAt >= start },
                                                                  sortBy: [SortDescriptor(\.answeredAt)]))
        let outcomes = try context.fetch(FetchDescriptor<PromptLog>(predicate: #Predicate {
            $0.scheduledAt >= start && $0.scheduledAt <= now
        })).map(\.outcome)
        return File(format: format, days: schedule.day(of: now) ?? 0,
                    queues: queues.map { queue($0, feedback: feedback[$0.id] ?? [], scores: scores, schedule: schedule) },
                    watch: Watch(nightsKnown: nightsKnown, hours: max(0, Int(now.timeIntervalSince(start) / 3600)),
                                 hoursWithHR: hoursWithHR),
                    checkIns: checkIns.map {
                        CheckInPair(dayOfUse: $0.dayOfUse, labelEnergy: $0.labelEnergy,
                                    pCommonBefore: $0.pCommonBefore, pPersonalBefore: $0.pPersonalBefore)
                    },
                    prompts: Prompts(answered: outcomes.filter { $0 == .answered }.count,
                                     notNow: outcomes.filter { $0 == .notNow }.count,
                                     ignored: outcomes.filter { $0 == .ignored }.count,
                                     waiting: outcomes.filter { $0 == nil }.count))
    }

    static func json(from context: ModelContext, schedule: PilotSchedule, now: Date = .now) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file(from: context, schedule: schedule, now: now))
    }

    private static func queue(_ record: QueueRecord, feedback: [FeedbackEvent], scores: [String: ScoreOrigin],
                              schedule: PilotSchedule) -> Queue {
        let items = record.items.sorted { $0.position < $1.position }
        let positions = Dictionary(items.map { ($0.spotifyId, $0.position) }, uniquingKeysWith: { first, _ in first })
        var events: [Event] = []
        var fit: String?
        for event in feedback {
            switch event.event {
            case .fitYes: fit = "yes"
            case .fitNo: fit = "no"
            case .skip, .like, .finish:
                guard let position = event.spotifyId.flatMap({ positions[$0] }) else { continue }
                events.append(Event(position: position, event: event.event.rawValue, seconds: event.seconds))
            }
        }
        return Queue(day: schedule.day(of: record.createdAt) ?? 0,
                     hour: schedule.calendar.component(.hour, from: record.createdAt),
                     situation: record.situation.rawValue,
                     stateMode: record.stateMode?.rawValue,
                     strategy: record.strategy?.rawValue,
                     items: items.map {
                         // A suggestion is a MuSe song outside the library: no `SongScore`.
                         Item(position: $0.position, origin: $0.isSuggestion ? ScoreOrigin.muse.rawValue : scores[$0.spotifyId]?.rawValue,
                              suggestion: $0.isSuggestion)
                     },
                     events: events, fit: fit)
    }
}
