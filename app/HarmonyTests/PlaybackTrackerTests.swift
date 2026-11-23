import Foundation
import Testing
@testable import Harmony

/// TODO 3.14
@MainActor
struct PlaybackTrackerTests {
    private let start = Date(timeIntervalSince1970: 1_790_050_000)

    private func at(_ seconds: TimeInterval) -> Date { start + seconds }

    private func playing(_ id: String?, _ position: TimeInterval = 0, paused: Bool = false) -> PlaybackState {
        PlaybackState(spotifyId: id, position: position, duration: 200, isPaused: paused)
    }

    @Test func songLeftBeforeThirtySecondsIsASkip() {
        var tracker = PlaybackTracker(queue: ["a", "b", "c"])
        #expect(tracker.update(playing("a"), at: at(0)).isEmpty)
        #expect(tracker.update(playing("b"), at: at(12)) == [.skip("a", seconds: 12)])
    }

    @Test func pausedTimeDoesNotCount() {
        var tracker = PlaybackTracker(queue: ["a", "b"])
        _ = tracker.update(playing("a"), at: at(0))
        _ = tracker.update(playing("a", 10, paused: true), at: at(10))
        _ = tracker.update(playing("a", 10), at: at(100))
        #expect(tracker.update(playing("b"), at: at(115)) == [.skip("a", seconds: 25)])
    }

    @Test func songPlayedToTheEndIsFinished() {
        var tracker = PlaybackTracker(queue: ["a", "b"])
        _ = tracker.update(playing("a"), at: at(0))
        #expect(tracker.update(playing("b"), at: at(200)) == [.finish("a", seconds: 200)])
    }

    @Test func songLeftInTheMiddleGivesNothing() {
        var tracker = PlaybackTracker(queue: ["a", "b"])
        _ = tracker.update(playing("a"), at: at(0))
        #expect(tracker.update(playing("b"), at: at(90)).isEmpty)
    }

    @Test func lastSongOverEndsTheQueue() {
        var tracker = PlaybackTracker(queue: ["a", "b"])
        _ = tracker.update(playing("a"), at: at(0))
        _ = tracker.update(playing("b"), at: at(200))
        // Spotify goes on with a song outside the queue.
        #expect(tracker.update(playing("other"), at: at(400)) == [.finish("b", seconds: 200), .end])
        #expect(tracker.hasEnded)
        #expect(tracker.update(playing("more"), at: at(600)).isEmpty)
    }

    @Test func lastSongBackAtItsStartIsFinished() {
        // Spotify stops after the last song and goes back to its start, paused.
        var tracker = PlaybackTracker(queue: ["a"])
        _ = tracker.update(playing("a"), at: at(0))
        #expect(tracker.update(playing("a", 0, paused: true), at: at(201)) == [.finish("a", seconds: 200), .end])
    }

    @Test func removedSongIsPassedWithoutAnyRecord() {
        var tracker = PlaybackTracker(queue: ["a", "b", "c"])
        tracker.removed = ["b"]
        _ = tracker.update(playing("a"), at: at(0))
        #expect(tracker.update(playing("b"), at: at(200)) == [.finish("a", seconds: 200), .passRemoved("b")])
        #expect(tracker.update(playing("c"), at: at(201)).isEmpty)
    }

    @Test func removedLastSongEndsTheQueueAfterThePreviousOne() {
        var tracker = PlaybackTracker(queue: ["a", "b"])
        tracker.removed = ["b"]
        _ = tracker.update(playing("a"), at: at(0))
        #expect(tracker.update(playing("b"), at: at(200)) == [.finish("a", seconds: 200), .passRemoved("b"), .end])
    }

    @Test func nextOnTheLastSongEndsNow() {
        var tracker = PlaybackTracker(queue: ["a"])
        _ = tracker.update(playing("a"), at: at(0))
        #expect(tracker.isAtOrAfterLastSong("a"))
        #expect(tracker.endNow(at: at(5)) == [.skip("a", seconds: 5), .end])
        #expect(tracker.endNow(at: at(6)).isEmpty)
    }

    @Test func songsOutsideTheQueueAreIgnored() {
        var tracker = PlaybackTracker(queue: ["a", "b"])
        _ = tracker.update(playing("other"), at: at(0))
        #expect(tracker.update(playing("a"), at: at(3)).isEmpty)
    }
}
