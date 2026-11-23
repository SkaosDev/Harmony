import Foundation

/// Turns the music app's states into what the user did with the queue (TODO 3.14, FR10):
/// a song left before 30 s is a skip, a song played to its last 3 s is finished, a song left in
/// between gives nothing. The music app only sends a state at each change, so the position
/// between two states is estimated from the time (unless paused).
nonisolated struct PlaybackTracker {
    enum Event: Equatable {
        case skip(String, seconds: Double)
        case finish(String, seconds: Double)
        /// A song the user removed from the queue started: pass it (nothing is recorded).
        case passRemoved(String)
        /// The last song of the queue is over: ask "Did it fit?" (TODO 3.15).
        case end
    }

    static let skipBefore: TimeInterval = 30
    static let endMargin: TimeInterval = 3

    /// Spotify IDs of the queue, in order.
    let queue: [String]
    /// Songs removed from the queue by the user (design `V2-File`).
    var removed: Set<String> = []
    private(set) var current: String?
    private(set) var hasEnded = false
    private var position: TimeInterval = 0
    private var duration: TimeInterval = 0
    private var isPaused = true
    private var since = Date.distantPast

    init(queue: [String]) {
        self.queue = queue
    }

    /// Estimated position of the current song at `time`, in seconds.
    func position(at time: Date) -> TimeInterval {
        isPaused ? position : position + time.timeIntervalSince(since)
    }

    mutating func update(_ state: PlaybackState, at time: Date) -> [Event] {
        guard !hasEnded else { return [] }
        var events: [Event] = []
        if state.spotifyId != current {
            let previous = current
            if let previous { events += leave(previous, at: time) }
            current = state.spotifyId
            if let id = current, removed.contains(id), queue.contains(id) {
                events.append(.passRemoved(id))
            }
            if let previous, isAtOrAfterLastSong(previous), !isActive(current) {
                hasEnded = true
                events.append(.end)
            }
        } else if let id = current, isActive(id), state.position < position(at: time) - Self.endMargin,
                  position(at: time) >= duration - Self.endMargin {
            // Same song back at its start after reaching its end: it finished (the last song,
            // when Spotify stops instead of playing something else).
            events.append(.finish(id, seconds: duration))
            if isAtOrAfterLastSong(id) {
                hasEnded = true
                events.append(.end)
            }
        }
        position = state.position
        duration = state.duration
        isPaused = state.isPaused
        since = time
        return events
    }

    /// Next on the last song: the queue ends now.
    mutating func endNow(at time: Date) -> [Event] {
        guard !hasEnded else { return [] }
        hasEnded = true
        return (current.map { leave($0, at: time) } ?? []) + [.end]
    }

    /// Whether `id` is the last song still in the queue, or after it.
    func isAtOrAfterLastSong(_ id: String) -> Bool {
        guard let last = queue.lastIndex(where: { !removed.contains($0) }),
              let index = queue.firstIndex(of: id) else { return false }
        return index >= last
    }

    private func isActive(_ id: String?) -> Bool {
        guard let id else { return false }
        return queue.contains(id) && !removed.contains(id)
    }

    private func leave(_ id: String, at time: Date) -> [Event] {
        guard isActive(id) else { return [] }
        let listened = min(position(at: time), duration)
        if listened < Self.skipBefore { return [.skip(id, seconds: listened)] }
        if listened >= duration - Self.endMargin { return [.finish(id, seconds: listened)] }
        return []
    }
}
