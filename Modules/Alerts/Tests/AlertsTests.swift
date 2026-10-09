import Foundation
import Testing
import Measures
import Plans
import Services
import Limits
@testable import Alerts

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

/// D1 rows read against Free's 5M a day, read at `at` with `used` rows.
func rowsRead(_ used: Double, at: String) -> Limit {
    let definition = LimitDefinition(id: "d1.rowsRead", name: "D1 rows read", short: "D1", unit: .rows,
                                     read: .sum(Read.Source(dataset: "d1", field: "sum.rowsRead", time: .date)))
    var limit = Limit(definition, allowance: .perDay(Quantity(5_000_000, .rows)))
    let readAt = Date.utc(at)
    limit.record(Usage(used: Quantity(used, .rows), period: .day(containing: readAt), readAt: readAt))
    return limit
}

func cpu(p99: Double, failures: Int, at: String) -> Limit {
    let definition = LimitDefinition(id: "workers.cpu", name: "CPU", short: "CPU", unit: .milliseconds,
                                     read: .quantile(Read.Source(dataset: "w", field: "quantiles.cpuTimeP99", time: .datetime)))
    var limit = Limit(definition, allowance: .perInvocation(Quantity(10, .milliseconds)))
    let readAt = Date.utc(at)
    limit.record(Usage(used: Quantity(p99, .milliseconds), period: .day(containing: readAt), readAt: readAt, failures: failures))
    return limit
}

@Suite
struct AlertsTests {
    @Test func `should warn when D1 rows read crosses 75%`() {
        var alerts = Alerts(settings: .init(levels: [50, 75, 90], pace: false, isOn: true))

        let warnings = alerts.check([rowsRead(3_750_000, at: "2026-10-09T21:14:00")], at: .utc("2026-10-09T21:15:00"))

        #expect(warnings.map(\.title) == ["D1 rows read at 75%"])
        #expect(warnings.first?.body.hasPrefix("3.75M of 5M") == true)
    }

    @Test func `should send one warning, for the highest level, when a refresh jumps past two`() {
        var alerts = Alerts(settings: .init(levels: [50, 75, 90], pace: false, isOn: true))
        let warnings = alerts.check([rowsRead(4_000_000, at: "2026-10-09T21:14:00")], at: .utc("2026-10-09T21:15:00"))
        #expect(warnings.map(\.title) == ["D1 rows read at 80%"])
    }

    @Test func `should not warn twice when reads cross 75% again the same day`() {
        var alerts = Alerts(settings: .init(levels: [75], pace: false, isOn: true))
        _ = alerts.check([rowsRead(3_800_000, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00"))

        let again = alerts.check([rowsRead(3_900_000, at: "2026-10-09T13:00:00")], at: .utc("2026-10-09T13:01:00"))

        #expect(again.isEmpty)
    }

    @Test func `should warn again the next day, when the allowance has reset`() {
        var alerts = Alerts(settings: .init(levels: [75], pace: false, isOn: true))
        _ = alerts.check([rowsRead(3_800_000, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00"))

        let tomorrow = alerts.check([rowsRead(3_800_000, at: "2026-10-10T12:00:00")], at: .utc("2026-10-10T12:01:00"))

        #expect(tomorrow.count == 1)
    }

    @Test func `should not warn at a level the person turned off`() {
        var alerts = Alerts(settings: .init(levels: [90], pace: false, isOn: true))
        #expect(alerts.check([rowsRead(3_800_000, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00")).isEmpty)
    }

    @Test func `should send nothing while Notify is off`() {
        var alerts = Alerts(settings: .init(levels: [50, 75, 90], pace: true, isOn: false))
        #expect(alerts.check([rowsRead(4_800_000, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00")).isEmpty)
    }

    @Test func `should warn early when today's pace would cross 90% before midnight`() {
        var alerts = Alerts(settings: .init(levels: [], pace: true, isOn: true))

        // 2.4M by noon: 4.8M a day is 96%; 90% (4.5M) at 22:30.
        let warnings = alerts.check([rowsRead(2_400_000, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00"))

        #expect(warnings.map(\.title) == ["Pace: D1 rows read would cross 90% at 22:30 UTC"])
    }

    @Test func `should not warn about pace once the limit is past 90% already`() {
        var alerts = Alerts(settings: .init(levels: [], pace: true, isOn: true))
        #expect(alerts.check([rowsRead(4_600_000, at: "2026-10-09T20:00:00")], at: .utc("2026-10-09T20:01:00")).isEmpty)
    }

    @Test func `should warn once a day when Cloudflare stopped Worker invocations for CPU`() {
        var alerts = Alerts(settings: .init(levels: [50, 75, 90], pace: true, isOn: true))

        let first = alerts.check([cpu(p99: 9, failures: 3, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00"))
        let again = alerts.check([cpu(p99: 9, failures: 5, at: "2026-10-09T13:00:00")], at: .utc("2026-10-09T13:01:00"))

        #expect(first.map(\.title) == ["CPU: 3 invocations stopped"])
        #expect(again.isEmpty)
    }

    @Test func `should not warn about CPU running past 10 ms when nothing was stopped`() {
        var alerts = Alerts(settings: .init(levels: [50, 75, 90], pace: true, isOn: true))
        #expect(alerts.check([cpu(p99: 17, failures: 0, at: "2026-10-09T12:00:00")], at: .utc("2026-10-09T12:01:00")).isEmpty)
    }

    @Test func `should forget warnings from long-gone periods`() {
        var alerts = Alerts(settings: .init(levels: [75], pace: false, isOn: true))
        _ = alerts.check([rowsRead(3_800_000, at: "2026-08-01T12:00:00")], at: .utc("2026-08-01T12:01:00"))
        _ = alerts.check([], at: .utc("2026-10-09T12:00:00"))
        #expect(alerts.sent.isEmpty)
    }
}
