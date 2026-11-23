import Foundation
import SwiftData
import Testing
@testable import Harmony

/// A playback that only records the commands; the test sends the states.
final class FakePlayback: Playback {
    var onChange: ((PlaybackState) -> Void)?
    var fails = false
    private(set) var commands: [String] = []

    func start(spotifyIds: [String]) async throws {
        if fails { throw SpotifyRemote.Failure.connection("test") }
        commands.append("start " + spotifyIds.joined(separator: ","))
    }
    func pause() async throws { commands.append("pause") }
    func resume() async throws { commands.append("resume") }
    func skipToNext() async throws { commands.append("next") }
    func remove(spotifyId: String) async throws { commands.append("remove " + spotifyId) }
    func reconnect() async { commands.append("reconnect") }
    func disconnect() { commands.append("disconnect") }

    func send(_ id: String?, _ position: TimeInterval = 0, paused: Bool = false) {
        onChange?(PlaybackState(spotifyId: id, position: position, duration: 200, isPaused: paused))
    }
}

/// A music provider that keeps the songs it was asked to save.
final class SavingProvider: MusicProvider {
    private(set) var saved: [String] = []
    func signIn() async throws {}
    func importLibrary() async throws -> [Track] { [] }
    func lookUp(spotifyId: String) async throws -> TrackInfo? { nil }
    func play(spotifyIds: [String]) async throws {}
    func save(spotifyId: String) async throws { saved.append(spotifyId) }
}

/// TODO 3.11–3.15: the controller between the player screen, the music app and the store.
@MainActor
struct PlayerControllerTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let playback = FakePlayback()
    private let music = SavingProvider()
    private let controller = PlayerController()
    private let start = Date(timeIntervalSince1970: 1_790_050_000)

    init() throws {
        container = try HarmonyStore.container(inMemory: true)
        context = container.mainContext
    }

    private func queue(_ ids: [String]) -> PreparedQueue {
        let entries = ids.map { id in
            QueueEntry(song: QueueCandidate(spotifyId: id, title: id, artists: ["A"], energy: 0.5, positivity: 0.5, origin: .muse),
                       target: 0.5, info: nil)
        }
        return PreparedQueue(situation: .wakeUp, e0: 0.4, reason: "Morning: calm songs first, then more energy.",
                             entries: entries, songs: entries.map { TrackInfo(spotifyId: $0.song.spotifyId, title: "", artists: [], coverURL: nil) })
    }

    /// Starts `ids` with the clock at `seconds` after `start`.
    private func play(_ ids: [String]) async {
        await controller.play(queue(ids), playback: playback, music: music, context: context)
    }

    private func setClock(_ seconds: TimeInterval) {
        let time = start + seconds
        controller.now = { time }
    }

    private func events() throws -> [FeedbackEvent] {
        try context.fetch(FetchDescriptor<FeedbackEvent>(sortBy: [SortDescriptor(\.time)]))
    }

    @Test func startingPlaysTheQueueAndRecordsItOnce() async throws {
        setClock(0)
        await play(["a", "b", "c"])

        #expect(controller.phase == .playing)
        #expect(playback.commands == ["start a,b,c"])
        let records = try context.fetch(FetchDescriptor<QueueRecord>())
        #expect(records.count == 1)
        #expect(records.first?.id == controller.queueId)
        #expect(records.first?.items.count == 3)
    }

    /// TODO 3.18: starting a queue opens the player; Back keeps the queue; the answer closes it.
    @Test func playerOpensWithTheQueueAndClosesAfterTheAnswer() async throws {
        setClock(0)
        #expect(!controller.isPresented)
        await play(["a", "b"])
        #expect(controller.isPresented)

        controller.isPresented = false
        #expect(controller.phase == .playing && controller.queue != nil)

        controller.isPresented = true
        controller.answer(fits: nil)
        #expect(!controller.isPresented && controller.phase == .idle)
    }

    @Test func failedStartShowsCannotPlayAndRecordsNothing() async throws {
        playback.fails = true
        await play(["a"])

        #expect(controller.phase == .cannotPlay)
        #expect(try context.fetch(FetchDescriptor<QueueRecord>()).isEmpty)

        playback.fails = false
        await controller.retry()
        #expect(controller.phase == .playing)
    }

    @Test func skipUnderThirtySecondsIsRecorded() async throws {
        setClock(0)
        await play(["a", "b"])
        playback.send("a")
        setClock(10)
        playback.send("b")

        let recorded = try events()
        #expect(recorded.map(\.event) == [.skip])
        #expect(recorded.first?.spotifyId == "a" && recorded.first?.seconds == 10)
        #expect(recorded.first?.queueId == controller.queueId)
        #expect(controller.currentIndex == 1)
    }

    @Test func likeSavesInSpotifyAndIsRecordedOnce() async throws {
        setClock(0)
        await play(["a", "b"])
        playback.send("a")

        await controller.like()
        await controller.like()

        #expect(music.saved == ["a"])
        #expect(controller.liked == ["a"])
        #expect(try events().map(\.event) == [.like])
    }

    @Test func nextOnTheLastSongEndsTheQueueAndPauses() async throws {
        setClock(0)
        await play(["a"])
        playback.send("a")
        setClock(100)

        await controller.next()

        #expect(controller.phase == .ended)
        #expect(playback.commands.last == "pause")
        // Left between 30 s and the end: nothing recorded.
        #expect(try events().isEmpty)
    }

    @Test func didItFitRecordsYesOrNopeAndSkipRecordsNothing() async throws {
        setClock(0)
        await play(["a"])
        playback.send("a")
        setClock(200)
        playback.send("a", 0, paused: true)
        #expect(controller.phase == .ended)

        controller.answer(fits: false)
        #expect(try events().map(\.event) == [.finish, .fitNo])
        #expect(controller.phase == .idle)

        await play(["b"])
        playback.send("b")
        await controller.next()
        controller.answer(fits: nil)
        #expect(try events().map(\.event) == [.finish, .fitNo, .skip])
    }

    @Test func removedSongIsPassedWithoutRecord() async throws {
        setClock(0)
        await play(["a", "b", "c"])
        playback.send("a")
        controller.remove("b")
        #expect(controller.activeIds == ["a", "c"])
        for _ in 0..<10 where !playback.commands.contains("remove b") { await Task.yield() }
        #expect(playback.commands.contains("remove b"))

        // Should the music app still play it, it is passed.
        setClock(200)
        playback.send("b")
        // The skip runs in a task.
        for _ in 0..<10 where playback.commands.last != "next" { await Task.yield() }

        #expect(playback.commands.last == "next")
        #expect(try events().map(\.event) == [.finish])
    }

    @Test func playingSongCannotBeRemoved() async {
        await play(["a", "b"])
        playback.send("a")
        controller.remove("a")
        #expect(controller.activeIds == ["a", "b"])
    }

    @Test func openInSpotifyKeepsThePlayingSong() async {
        var opened: [URL] = []
        controller.openURL = { opened.append($0) }
        await play(["a", "b"])
        playback.send("b")

        controller.spotifyIsInstalled = { true }
        controller.openInSpotify()
        controller.spotifyIsInstalled = { false }
        controller.openInSpotify()

        #expect(opened.map(\.absoluteString) == ["spotify:", "https://open.spotify.com/track/b"])
    }

    @Test func openInSpotifyStartsTheFirstSongWhenPlaybackFailed() async {
        var opened: [URL] = []
        controller.openURL = { opened.append($0) }
        controller.spotifyIsInstalled = { true }
        playback.fails = true
        await play(["a", "b"])

        controller.openInSpotify()

        #expect(opened.map(\.absoluteString) == ["spotify:track:a"])
    }

    @Test func reconnectsOnlyWhilePlaying() async {
        await play(["a"])
        controller.enterBackground()
        await controller.enterForeground()
        #expect(playback.commands.suffix(2) == ["disconnect", "reconnect"])

        controller.answer(fits: nil)
        await controller.enterForeground()
        #expect(playback.commands.last == "reconnect" && playback.commands.count == 3)
    }
}
