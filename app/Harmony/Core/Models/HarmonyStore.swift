import SwiftData

/// The app's local SwiftData store (report, Requirement 8). Everything stays on the phone.
enum HarmonyStore {
    /// Every table of the app. A new `@Model` must be added here.
    static var schema: Schema {
        Schema([
            Track.self,
            SongScore.self,
        ])
    }

    /// `inMemory: true` is for tests: nothing is written to disk.
    static func container(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
