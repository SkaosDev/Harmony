import Foundation
import SwiftData
import Testing
@testable import Harmony

/// TODO 1.12: each test gets its own in-memory store, so tests leave no data behind.
@MainActor
struct HarmonyStoreTests {
    @Test func testContainerIsInMemory() throws {
        let container = try HarmonyStore.container(inMemory: true)
        #expect(!container.configurations.isEmpty)
        let inMemory = container.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(inMemory)
    }
}
