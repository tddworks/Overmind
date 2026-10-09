import Foundation

/// The stretch of time an allowance covers: a UTC day for Free, the billing month for Paid
/// (CANONICAL law 5). Half-open: it contains its start, not its end.
public struct Period: Sendable, Equatable, Hashable, Codable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// The UTC day `date` falls in; Free allowances reset at 00:00 UTC.
    public static func day(containing date: Date) -> Period {
        let start = utc.startOfDay(for: date)
        return Period(start: start, end: utc.date(byAdding: .day, value: 1, to: start)!)
    }

    /// The billing month `date` falls in. Paid allowances reset on the subscription's renewal
    /// day; without one, the calendar month.
    public static func month(containing date: Date, renewsOn renewal: Date?) -> Period {
        guard let renewal else {
            let start = utc.date(from: utc.dateComponents([.year, .month], from: date))!
            return Period(start: start, end: utc.date(byAdding: .month, value: 1, to: start)!)
        }
        var end = renewal
        while end <= date { end = utc.date(byAdding: .month, value: 1, to: end)! }
        var start = utc.date(byAdding: .month, value: -1, to: end)!
        while start > date {
            end = start
            start = utc.date(byAdding: .month, value: -1, to: end)!
        }
        return Period(start: start, end: end)
    }

    public var length: TimeInterval { end.timeIntervalSince(start) }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }

    /// How much of the period has gone by at `now`, from 0 to 1.
    public func elapsedFraction(at now: Date) -> Double {
        min(max(now.timeIntervalSince(start) / length, 0), 1)
    }
}
