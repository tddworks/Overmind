import Foundation
import Testing
import Measures
@testable import Plans

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

/// A neutral plan: Acme Free allows 100 widgets a day and stops; Acme Pro includes 1,000 a
/// month for $5 and charges $1 per 100 beyond.
@Suite
struct PlanTests {
    static let free = """
    { "id": "acme-free", "name": "Acme Free", "subscription": "0 USD", "matches": [],
      "allowances": { "acme.widgets": { "perDay": "100 count" }, "acme.disk": { "total": "1 GB" },
                      "acme.latency": { "perInvocation": "10 ms" } } }
    """
    static let pro = """
    { "id": "acme-pro", "name": "Acme Pro", "subscription": "5 USD", "matches": ["acme_pro"],
      "allowances": { "acme.widgets": { "perMonth": "1k count" }, "acme.disk": { "total": "1 GB" } },
      "prices": { "acme.widgets": { "beyond": { "price": "1 USD", "per": "100 count" } },
                  "acme.disk": { "perMonthOver": { "price": "0.75 USD", "per": "1 GB" } } } }
    """

    @Test func `should know how much a plan includes of each limit`() throws {
        let free = try PlanDefinition(json: Data(Self.free.utf8))
        #expect(free.allowance(for: "acme.widgets") == .perDay(Quantity(100, .count)))
        #expect(free.allowance(for: "acme.gadgets") == nil)
    }

    @Test func `should reset a daily allowance at 00:00 UTC`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.free.utf8)), renewsOn: nil)
        let period = plan.period(for: "acme.widgets", at: .utc("2026-10-09T14:20:00"))
        #expect(period == Period.day(containing: .utc("2026-10-09T14:20:00")))
    }

    @Test func `should reset a monthly allowance on the subscription's renewal day`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.pro.utf8)), renewsOn: .utc("2026-11-03T00:00:00"))
        let period = plan.period(for: "acme.widgets", at: .utc("2026-10-09T14:20:00"))
        #expect(period?.start == .utc("2026-10-03T00:00:00"))
    }

    @Test func `should never reset an allowance for what is kept, like storage`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.free.utf8)), renewsOn: nil)
        #expect(plan.period(for: "acme.disk", at: .utc("2026-10-09T14:20:00")) == nil)
    }

    @Test func `should judge a per-invocation allowance over the UTC day`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.free.utf8)), renewsOn: nil)
        #expect(plan.period(for: "acme.latency", at: .utc("2026-10-09T14:20:00")) == Period.day(containing: .utc("2026-10-09T14:20:00")))
    }

    @Test func `should cost nothing on a plan that stops at the limit, however much was used`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.free.utf8)), renewsOn: nil)
        #expect(plan.cost(of: ["acme.widgets": Quantity(5_000, .count)]) == Money(0, "USD"))
    }

    @Test func `should cost only the subscription while use stays inside the allowance`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.pro.utf8)), renewsOn: nil)
        #expect(plan.cost(of: ["acme.widgets": Quantity(900, .count)]) == Money(5, "USD"))
    }

    @Test func `should charge for what went past the allowance`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.pro.utf8)), renewsOn: nil)
        // 1,250 made: 250 beyond the 1,000 included, at $1 per 100.
        #expect(plan.cost(of: ["acme.widgets": Quantity(1_250, .count)]) == Money(Decimal(string: "7.5")!, "USD"))
    }

    @Test func `should charge kept storage past its allowance by the month`() throws {
        let plan = Plan(try PlanDefinition(json: Data(Self.pro.utf8)), renewsOn: nil)
        #expect(plan.cost(of: ["acme.disk": Quantity(3e9, .bytes)]) == Money(Decimal(string: "6.5")!, "USD"))
    }
}

@Suite
struct BuiltInPlansTests {
    @Test func `should know the Free plan allows 5M D1 rows read a day`() throws {
        let free = try PlanCatalog.builtIn("free")
        #expect(free.allowance(for: "d1.rowsRead") == .perDay(Quantity(5_000_000, .rows)))
        #expect(free.allowance(for: "workers.cpu") == .perInvocation(Quantity(10, .milliseconds)))
    }

    @Test func `should not watch monthly CPU time on the Free plan, which caps each invocation instead`() throws {
        #expect(try PlanCatalog.builtIn("free").allowance(for: "workers.cpuTime") == nil)
    }

    @Test func `should know Workers Paid includes 25B rows read a month for $5`() throws {
        let paid = try PlanCatalog.builtIn("workers-paid")
        #expect(paid.allowance(for: "d1.rowsRead") == .perMonth(Quantity(25_000_000_000, .rows)))
        #expect(paid.subscription == Money(5, "USD"))
    }

    @Test func `should price 26B rows read on Workers Paid at the subscription plus one dollar`() throws {
        let paid = Plan(try PlanCatalog.builtIn("workers-paid"), renewsOn: nil)
        #expect(paid.cost(of: ["d1.rowsRead": Quantity(26_000_000_000, .rows)]) == Money(6, "USD"))
    }

    @Test func `should take an account with only R2 Paid to be on the Free Workers plan`() throws {
        #expect(try PlanCatalog.plan(forRatePlans: ["r2_paid"]).id == "free")
    }

    @Test func `should take an account with a Workers Paid subscription to be on Workers Paid`() throws {
        #expect(try PlanCatalog.plan(forRatePlans: ["r2_paid", "workers_paid"]).id == "workers-paid")
    }
}

@Suite
struct QuoteLineTests {
    @Test func `should show each limit's month with what the plan includes and the price of the rest`() throws {
        let plan = Plan(try PlanDefinition(json: Data(PlanTests.pro.utf8)), renewsOn: nil)

        let lines = plan.lines(of: ["acme.widgets": Quantity(1_250, .count)])

        #expect(lines == [CostLine(limit: "acme.widgets", used: Quantity(1_250, .count), included: Quantity(1_000, .count),
                                   cost: Money(Decimal(string: "2.5")!, "USD"))])
    }

    @Test func `should add the lines and the subscription up to the plan's cost`() throws {
        let plan = Plan(try PlanDefinition(json: Data(PlanTests.pro.utf8)), renewsOn: nil)
        let used: [LimitID: Quantity] = ["acme.widgets": Quantity(1_250, .count), "acme.disk": Quantity(3e9, .bytes)]

        let total = plan.lines(of: used).reduce(plan.definition.subscription) { $0 + $1.cost }

        #expect(total == plan.cost(of: used))
    }

    @Test func `should not list what a plan doesn't price`() throws {
        let free = Plan(try PlanDefinition(json: Data(PlanTests.free.utf8)), renewsOn: nil)
        #expect(free.lines(of: ["acme.widgets": Quantity(5_000, .count)]).isEmpty)
    }

    @Test func `should link to Workers Paid's page on Cloudflare for this account`() throws {
        let paid = try PlanCatalog.builtIn("workers-paid")
        #expect(paid.upgradeURL(account: "acc1")?.absoluteString == "https://dash.cloudflare.com/acc1/workers/plans")
    }

    @Test func `should say whether a plan stops at its limits or charges for the rest`() throws {
        #expect(try PlanCatalog.builtIn("free").stopsAtLimits)
        #expect(try !PlanCatalog.builtIn("workers-paid").stopsAtLimits)
    }
}
