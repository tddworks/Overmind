import Foundation
import Measures
import Services

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

enum Fixture {
    static let account = "0123456789abcdef0123456789abcdef"
    static let now = Date.utc("2026-10-09T14:20:00")
    static let today = Period.day(containing: now)

    static func limit(_ service: String, _ id: LimitID) throws -> LimitDefinition {
        try require(try ServiceCatalog.builtIn(service).limits.first { $0.id == id })
    }

    /// Cloudflare's answer to a refresh of D1 rows read (l0), Workers CPU (l1) and D1 storage
    /// (l2), as recorded on 2026-10-09 with the account ID replaced.
    static let limitsAnswer = Data("""
    {"data":{"viewer":{"accounts":[{
      "l0":[{"sum":{"rowsRead":120000}},{"sum":{"rowsRead":57504}}],
      "l1":[{"quantiles":{"cpuTimeP99":16726}}],
      "l1_failures":[{"sum":{"requests":3}}],
      "l2":[{"dimensions":{"databaseId":"db1"},"max":{"databaseSizeBytes":512000}},
            {"dimensions":{"databaseId":"db2"},"max":{"databaseSizeBytes":40488000}}]
    }]}},"errors":null}
    """.utf8)
}

/// `#require` outside a test body.
func require<T>(_ value: T?) throws -> T {
    guard let value else { throw FixtureError.missing }
    return value
}
enum FixtureError: Error { case missing }
