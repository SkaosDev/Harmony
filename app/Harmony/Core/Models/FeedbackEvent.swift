import Foundation
import SwiftData

/// Something the user did with a queue (TODO 1.11, report Requirement 6).
@Model
final class FeedbackEvent {
    /// `QueueRecord.id` of the queue it belongs to.
    var queueId: UUID
    /// The song concerned; nil for the "Did it fit?" answer, which is about the whole queue.
    var spotifyId: String?
    var event: FeedbackType
    /// Seconds listened (skip, finish); nil when it does not apply.
    var seconds: Double?
    var time: Date

    init(queueId: UUID, spotifyId: String?, event: FeedbackType, seconds: Double?, time: Date) {
        self.queueId = queueId
        self.spotifyId = spotifyId
        self.event = event
        self.seconds = seconds
        self.time = time
    }
}

/// `skip` = passed before 30 s; `finish` = played to the end; `fitYes` / `fitNo` = answer to
/// "Did it fit?" (design `V2-Feedback`: Yes / Nope; its Skip button records nothing).
enum FeedbackType: String, Codable {
    case skip, like, finish, fitYes, fitNo
}
