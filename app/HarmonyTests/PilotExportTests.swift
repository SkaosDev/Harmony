import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 4.5: the anonymous pilot export, checked against `ml/fixtures/pilot_export_example.json`,
/// which `ml/tests/test_pilot_analysis.py` reads too.
@MainActor
struct PilotExportTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let calendar = StateFixtures.calendar
    private let schedule: PilotSchedule

    init() throws {
        container = try HarmonyStore.container(inMemory: true)
        context = container.mainContext
        let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 7))!
        schedule = PilotSchedule(startDay: start, calendar: calendar)
    }

    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(day: day - 1, hour: hour, minute: minute), to: schedule.startDay)!
    }

    /// One recorded queue: its songs (score origin, MuSe suggestion), its events in order
    /// (position, event, seconds) one minute apart, then the "Did it fit?" answer.
    private func addQueue(at date: Date, _ situation: Situation, stateMode: EstimateMode?,
                                   strategy: QueueStrategy? = .s1,
                                   songs: [(ScoreOrigin, Bool)], events: [(Int, FeedbackType, Double?)],
                                   fit: FeedbackType?) {
        let id = UUID()
        // Song IDs all start with "SPID", so the export can be searched for them.
        let ids = songs.indices.map { "SPID\(Int(date.timeIntervalSince1970))-\($0)" }
        for (index, song) in songs.enumerated() where !song.1 {
            context.insert(SongScore(spotifyId: ids[index], energy: 0.5, positivity: 0.5, origin: song.0))
        }
        let items = songs.enumerated().map { index, song in
            QueueItem(position: index, spotifyId: ids[index], targetEnergy: 0.42, isSuggestion: song.1)
        }
        context.insert(QueueRecord(id: id, createdAt: date, situation: situation, startEnergy: 0.42,
                                   stateMode: stateMode, strategy: strategy, strategyProbability: strategy == nil ? nil : 1,
                                   e0Source: .rank, pCommon: 0.42, pPersonal: 0.42,
                                   reason: "Short night, morning: calm songs first.", items: items))
        for (offset, event) in events.enumerated() {
            context.insert(FeedbackEvent(queueId: id, spotifyId: ids[event.0], event: event.1, seconds: event.2,
                                         time: date + Double(offset + 1) * 60))
        }
        if let fit {
            context.insert(FeedbackEvent(queueId: id, spotifyId: nil, event: fit, seconds: nil, time: date + 3600))
        }
    }

    /// The scenario of the fixture: 4 pilot days, 5 queues, a queue before day 1 left out.
    private func fill() throws {
        addQueue(at: at(day: 0, hour: 20), .wakeUp, stateMode: .body,
                 songs: [(.muse, false)], events: [(0, .skip, 4)], fit: .fitYes)
        addQueue(at: at(day: 1, hour: 8, minute: 10), .wakeUp, stateMode: .body,
                 songs: [(.muse, false), (.llm, false), (.muse, false)],
                 events: [(0, .finish, 200), (1, .skip, 12), (2, .like, nil), (2, .finish, 180)], fit: .fitYes)
        addQueue(at: at(day: 1, hour: 22, minute: 30), .windDown, stateMode: .body,
                 songs: [(.muse, false), (.muse, true), (.llm, false)],
                 events: [(0, .finish, 210), (1, .skip, 8), (2, .skip, 20)], fit: .fitNo)
        addQueue(at: at(day: 2, hour: 14), .lowEnergy, stateMode: .timeOnly, strategy: nil,
                 songs: [(.llm, false), (.neutral, false), (.muse, false)],
                 events: [(0, .skip, 5), (1, .finish, 190), (2, .finish, 230)], fit: nil)
        addQueue(at: at(day: 3, hour: 9), .wakeUp, stateMode: .timeOnly,
                 songs: [(.muse, false), (.muse, false), (.muse, true)],
                 events: [(0, .finish, 200), (1, .finish, 150), (2, .finish, 170)], fit: .fitYes)
        addQueue(at: at(day: 4, hour: 7, minute: 45), .stress, stateMode: .timeOnly,
                 songs: [(.llm, false), (.muse, false), (.muse, false)],
                 events: [(0, .skip, 3), (1, .finish, 200)], fit: .fitNo)

        // Nights: known on days 1 and 3, unknown on day 2, no row on day 4; day 0 is before.
        for (day, minutes) in [(0, 400.0), (1, 420), (2, nil), (3, 400)] as [(Int, Double?)] {
            context.insert(NightSummary(date: at(day: day, hour: 0), sleepMinutes: minutes, sleepEnd: nil,
                                        wornFraction: minutes == nil ? 0.2 : 0.9))
        }
        // Hours: 60 with heart rate, 5 without, 3 before day 1.
        for hour in -3..<65 {
            context.insert(HourSummary(hourStart: at(day: 1, hour: 0) + Double(hour) * 3600, meanHR: 70,
                                       hrCount: (0..<60).contains(hour) || hour < 0 ? 10 : 0, sdnnHRV: 40, steps: 300))
        }

        // Check-ins (TODO 6.14): one before day 1 left out, then two a day. No label before 5
        // earlier answers; the last one is still waiting for its state (phone locked).
        let answers: [(day: Int, hour: Int, label: Bool?, common: Double?, personal: Double?)] = [
            (0, 11, nil, 0.5, 0.5),
            (1, 11, nil, 0.48, 0.48), (1, 16, nil, 0.51, 0.51),
            (2, 12, nil, 0.47, 0.47), (2, 17, nil, 0.55, 0.55),
            (3, 10, nil, 0.5, 0.5), (3, 15, true, 0.53, 0.53),
            (4, 11, false, 0.52, 0.5), (4, 16, true, 0.49, 0.61), (4, 18, false, nil, nil),
        ]
        for answer in answers {
            context.insert(CheckIn(answeredAt: at(day: answer.day, hour: answer.hour, minute: 7), channel: .notification,
                                   promptedAt: at(day: answer.day, hour: answer.hour), energy: 2,
                                   zEnergy: answer.common.map(PersonalLayer.logit), estimateMode: .body,
                                   labelEnergy: answer.label, usableForLearning: true,
                                   pCommonBefore: answer.common, pPersonalBefore: answer.personal,
                                   dayOfUse: max(1, answer.day)))
        }
        // Questions: one before day 1, 9 answered, 1 "Not now", 2 ignored, 1 waiting, 2 planned
        // after the export.
        let prompts: [(day: Int, hour: Int, outcome: PromptOutcome?)] =
            [(0, 11, .answered)] + (1...4).flatMap { [($0, 11, .answered), ($0, 16, .answered)] }
            + [(4, 18, .answered), (2, 9, .notNow), (3, 9, .ignored), (3, 20, .ignored), (4, 19, nil),
               (5, 11, nil), (5, 16, nil)]
        for prompt in prompts {
            context.insert(PromptLog(scheduledAt: at(day: prompt.day, hour: prompt.hour), outcome: prompt.outcome))
        }
        try context.save()
    }

    private var exportTime: Date { at(day: 4, hour: 20) }

    private func fixture() throws -> Data {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "pilot_export_example", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func exportMatchesTheSharedFixture() throws {
        try fill()
        let expected = try JSONDecoder().decode(PilotExport.File.self, from: fixture())

        #expect(try PilotExport.file(from: context, schedule: schedule, now: exportTime) == expected)
        // Same keys and values once encoded, as `ml/pilot_analysis.py` reads them.
        let encoded = try JSONSerialization.jsonObject(with: PilotExport.json(from: context, schedule: schedule, now: exportTime))
        let wanted = try JSONSerialization.jsonObject(with: fixture())
        #expect((encoded as? NSDictionary)?.isEqual(to: wanted as? [String: Any] ?? [:]) == true)
    }

    /// `docs/pilot-protocol.md` §7.2: no song, no reason, no state of a queue, no health value, no
    /// check-in answer or logit, no date.
    @Test func exportHoldsNothingIdentifying() throws {
        try fill()
        let text = try #require(String(data: PilotExport.json(from: context, schedule: schedule, now: exportTime), encoding: .utf8))

        for word in ["SPID", "spotifyId", "reason", "Short night", "startEnergy", "targetEnergy", "0.42", "meanHR",
                     "sleepMinutes", "2026", "createdAt", "\"time\"", "pCommon\"", "pPersonal\"", "e0Source",
                     "\"energy\"", "zEnergy", "answeredAt", "promptedAt", "scheduledAt", "deliveredAt"] {
            #expect(!text.contains(word), "\(word)")
        }
    }
}

private final class BundleToken {}
