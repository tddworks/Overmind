import Foundation
import Testing
import Measures
import Plans
import Services
@testable import Limits

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

extension LimitDefinition {
    /// A neutral limit: Acme counts widgets made.
    static let acmeWidgets = LimitDefinition(
        id: "acme.widgets", name: "Widgets made", short: "Widgets", unit: .count,
        read: .sum(Read.Source(dataset: "acmeGroups", field: "sum.widgets", time: .date))
    )
}

extension Usage {
    /// `used` widgets in the UTC day of `readAt`, read at `readAt`.
    static func widgets(_ used: Double, readAt: String) -> Usage {
        let at = Date.utc(readAt)
        return Usage(used: Quantity(used, .count), period: .day(containing: at), readAt: at)
    }
}

@Suite
struct LimitTests {
    @Test func `should show 18% when 18 of a 100-a-day allowance is used`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(18, readAt: "2026-10-09T14:20:00"))

        #expect(limit.percent(at: .utc("2026-10-09T14:21:00")) == Percent(18))
    }

    @Test func `should show nothing before the first read`() {
        let limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        #expect(limit.percent(at: .utc("2026-10-09T14:21:00")) == nil)
    }

    @Test func `should not show yesterday's reads as today's when the day has just turned`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(90, readAt: "2026-10-08T23:58:00"))

        #expect(limit.percent(at: .utc("2026-10-09T00:03:00")) == nil)
    }

    @Test func `should keep the newer reading when an older one arrives late`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(40, readAt: "2026-10-09T14:20:00"))
        limit.record(.widgets(30, readAt: "2026-10-09T14:15:00"))

        #expect(limit.percent(at: .utc("2026-10-09T14:21:00")) == Percent(40))
    }

    @Test func `should drop a late reading from yesterday once today has been read`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(5, readAt: "2026-10-09T00:10:00"))
        limit.record(Usage(used: Quantity(97, .count), period: .day(containing: .utc("2026-10-08T12:00:00")),
                           readAt: .utc("2026-10-09T00:11:00")))

        #expect(limit.percent(at: .utc("2026-10-09T00:12:00")) == Percent(5))
    }

    @Test func `should keep storage's reading across days, since it never resets`() {
        var limit = Limit(.acmeWidgets, allowance: .total(Quantity(100, .count)))
        limit.record(Usage(used: Quantity(41, .count), period: nil, readAt: .utc("2026-10-08T23:58:00")))

        #expect(limit.percent(at: .utc("2026-10-09T09:00:00")) == Percent(41))
    }
}

@Suite
struct LevelTests {
    @Test(arguments: [(49.9, Level.ok), (50, .watch), (89.9, .watch), (90, .actNow), (130, .actNow)])
    func `should colour a limit by how much of it is used`(percent: Double, level: Level) {
        #expect(Level(Percent(percent)) == level)
    }
}

@Suite
struct PaceTests {
    @Test func `should say the day ends at 48% when a fifth of the allowance went in the first ten hours`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(20, readAt: "2026-10-09T10:00:00"))

        #expect(limit.pace(at: .utc("2026-10-09T10:01:00"))?.atPeriodEnd == Percent(48))
    }

    @Test func `should say it's too early to tell in the first hour of the day`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(9, readAt: "2026-10-09T00:50:00"))

        #expect(limit.pace(at: .utc("2026-10-09T00:51:00")) == nil)
    }

    @Test func `should say when the day's allowance runs out at this rate`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(60, readAt: "2026-10-09T12:00:00"))

        // 60 in 12 hours is 5 an hour: 90 is reached at 18:00.
        #expect(limit.pace(at: .utc("2026-10-09T12:01:00"))?.reaches(Percent(90)) == .utc("2026-10-09T18:00:00"))
    }

    @Test func `should say the allowance won't run out today when the rate is low`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(Quantity(100, .count)))
        limit.record(.widgets(20, readAt: "2026-10-09T12:00:00"))

        #expect(limit.pace(at: .utc("2026-10-09T12:01:00"))?.reaches(Percent(90)) == nil)
    }

    @Test func `should not project what is kept, like storage`() {
        var limit = Limit(.acmeWidgets, allowance: .total(Quantity(100, .count)))
        limit.record(Usage(used: Quantity(41, .count), period: nil, readAt: .utc("2026-10-09T12:00:00")))

        #expect(limit.pace(at: .utc("2026-10-09T12:01:00")) == nil)
    }

    @Test func `should not project a per-invocation allowance, which each request meets or fails alone`() {
        var limit = Limit(.acmeWidgets, allowance: .perInvocation(Quantity(10, .count)))
        limit.record(.widgets(7.8, readAt: "2026-10-09T12:00:00"))

        #expect(limit.pace(at: .utc("2026-10-09T12:01:00")) == nil)
        #expect(limit.percent(at: .utc("2026-10-09T12:01:00")) == Percent(78))
    }
}

/// Cloudflare lets single invocations run past the Free CPU allowance; only the ones it stops
/// matter (law 3, checked against a real account on 2026-10-09: p99 17 ms, 0 failures).
@Suite
struct PerInvocationTests {
    func cpu(p99: Double, failures: Int) -> Limit {
        var limit = Limit(.acmeWidgets, allowance: .perInvocation(Quantity(10, .count)))
        let at = Date.utc("2026-10-09T12:00:00")
        limit.record(Usage(used: Quantity(p99, .count), period: .day(containing: at), readAt: at, failures: failures))
        return limit
    }

    @Test func `should only ask to watch when the p99 is past the allowance but nothing failed`() {
        #expect(cpu(p99: 17, failures: 0).level(at: .utc("2026-10-09T12:01:00")) == .watch)
    }

    @Test func `should ask to act when Cloudflare stopped invocations for going past the allowance`() {
        #expect(cpu(p99: 9, failures: 3).level(at: .utc("2026-10-09T12:01:00")) == .actNow)
    }

    @Test func `should say a per-invocation limit never runs out, so it is never the closest`() {
        #expect(!cpu(p99: 17, failures: 0).runsOut)
    }
}
