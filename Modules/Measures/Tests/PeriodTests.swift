import Foundation
import Testing
@testable import Measures

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

@Suite
struct PeriodTests {
    @Test func `should start a Free day at 00:00 UTC whatever the Mac's time zone`() {
        let day = Period.day(containing: .utc("2026-10-09T14:20:00"))
        #expect(day.start == .utc("2026-10-09T00:00:00"))
        #expect(day.end == .utc("2026-10-10T00:00:00"))
    }

    @Test func `should say a day is just over half gone at 14:20 UTC`() {
        let day = Period.day(containing: .utc("2026-10-09T14:20:00"))
        #expect(abs(day.elapsedFraction(at: .utc("2026-10-09T14:20:00")) - 0.5972) < 0.0001)
    }

    @Test func `should start a billing month on the renewal day`() {
        let month = Period.month(containing: .utc("2026-10-09T12:00:00"), renewsOn: .utc("2026-11-03T00:00:00"))
        #expect(month.start == .utc("2026-10-03T00:00:00"))
        #expect(month.end == .utc("2026-11-03T00:00:00"))
    }

    @Test func `should roll the billing month over once the renewal day has passed`() {
        let month = Period.month(containing: .utc("2026-11-05T12:00:00"), renewsOn: .utc("2026-11-03T00:00:00"))
        #expect(month.start == .utc("2026-11-03T00:00:00"))
        #expect(month.end == .utc("2026-12-03T00:00:00"))
    }

    @Test func `should use the calendar month when there is no renewal day`() {
        let month = Period.month(containing: .utc("2026-10-09T12:00:00"), renewsOn: nil)
        #expect(month.start == .utc("2026-10-01T00:00:00"))
        #expect(month.end == .utc("2026-11-01T00:00:00"))
    }

    @Test func `should not count the next day's first moment as today`() {
        let day = Period.day(containing: .utc("2026-10-09T14:20:00"))
        #expect(!day.contains(.utc("2026-10-10T00:00:00")))
    }
}
