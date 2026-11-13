//
//  MockHistoryTests.swift
//  Websight-2Tests
//
//  Tests for the DEBUG-only mock history seeding.
//

#if DEBUG
import Testing
import SwiftData
import Foundation
@testable import websight

// Websight_2Tests.swift declares its own `History` model, so qualify the app's
// model with the module name (the app module is `websight`) to avoid picking up the test-local copy.
private typealias AppHistory = websight.History

@Suite("Mock History Seeding Tests")
@MainActor
struct MockHistoryTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppHistory.self, configurations: config)
    }

    private func allItems(in container: ModelContainer) throws -> [AppHistory] {
        try container.mainContext.fetch(
            FetchDescriptor<AppHistory>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        )
    }

    @Test("Seeds items into an empty store")
    func seedsWhenEmpty() throws {
        let container = try makeContainer()
        MockHistory.seedIfEmpty(container)

        #expect(try allItems(in: container).count == 18)
    }

    @Test("Does not seed when the store already has items")
    func doesNotSeedWhenNotEmpty() throws {
        let container = try makeContainer()
        container.mainContext.insert(AppHistory(text: "real item", type: "text"))
        try container.mainContext.save()

        MockHistory.seedIfEmpty(container)

        let items = try allItems(in: container)
        #expect(items.count == 1)
        #expect(items.first?.text == "real item")
    }

    @Test("Seeding twice does not duplicate items")
    func seedingIsIdempotent() throws {
        let container = try makeContainer()
        MockHistory.seedIfEmpty(container)
        MockHistory.seedIfEmpty(container)

        #expect(try allItems(in: container).count == 18)
    }

    @Test("Seed data covers every supported type")
    func coversAllTypes() throws {
        let container = try makeContainer()
        MockHistory.seedIfEmpty(container)

        let types = Set(try allItems(in: container).map(\.type))
        #expect(types == ["website", "email", "phone", "address", "amount", "date", "text"])
    }

    @Test("Seed items have non-empty text")
    func itemsHaveText() throws {
        let container = try makeContainer()
        MockHistory.seedIfEmpty(container)

        for item in try allItems(in: container) {
            #expect(!item.text.isEmpty)
        }
    }

    @Test("Timestamps are in the past and spread out")
    func timestampsInPastAndSpread() throws {
        let container = try makeContainer()
        MockHistory.seedIfEmpty(container)

        let items = try allItems(in: container)
        let now = Date()
        #expect(items.allSatisfy { $0.timestamp < now })

        let timestamps = Set(items.map(\.timestamp))
        #expect(timestamps.count == items.count, "Each item should have a distinct timestamp")

        let newest = try #require(items.first)
        let oldest = try #require(items.last)
        #expect(newest.timestamp > oldest.timestamp)
        #expect(now.timeIntervalSince(oldest.timestamp) > 7 * 86400, "Should span more than a week")
    }
}
#endif
