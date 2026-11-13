//
//  MockHistory.swift
//  Websight-2
//
//  Debug-only sample data so the History screen isn't empty during development.
//

#if DEBUG
import SwiftData
import Foundation

enum MockHistory {
    /// Inserts sample history items if the store is currently empty.
    @MainActor
    static func seedIfEmpty(_ container: ModelContainer) {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<History>())) ?? 0
        guard count == 0 else { return }

        let now = Date()
        let minute: TimeInterval = 60
        let hour: TimeInterval = 3600
        let day: TimeInterval = 86400

        let samples: [(String, String, TimeInterval)] = [
            ("https://www.apple.com/iphone", "website", 3 * minute),
            ("hello@coffeeroasters.com", "email", 25 * minute),
            ("(415) 555-0132", "phone", 1 * hour),
            ("1 Apple Park Way, Cupertino, CA 95014", "address", 2 * hour),
            ("$84.50", "amount", 3 * hour),
            ("March 14, 2026", "date", 5 * hour),
            ("Meeting notes: follow up with design team about the new onboarding flow.", "text", 1 * day),
            ("github.com/enemetz", "website", 1 * day + 2 * hour),
            ("support@websight.app", "email", 2 * day),
            ("+1 212-555-0187", "phone", 2 * day + 4 * hour),
            ("350 5th Ave, New York, NY 10118", "address", 3 * day),
            ("$132.00", "amount", 4 * day),
            ("12/25/2026", "date", 5 * day),
            ("https://developer.apple.com/documentation/swiftdata", "website", 6 * day),
            ("Wi-Fi password: sunnyday-2026", "text", 7 * day),
            ("1600 Amphitheatre Parkway, Mountain View, CA 94043", "address", 9 * day),
            ("$27.35", "amount", 10 * day),
            ("jane.doe@example.com", "email", 12 * day),
        ]

        for (text, type, offset) in samples {
            context.insert(History(text: text, type: type, timestamp: now.addingTimeInterval(-offset)))
        }
        try? context.save()
    }
}
#endif
