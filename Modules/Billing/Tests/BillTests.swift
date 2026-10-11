import Foundation
import Testing
import Measures
import Plans
@testable import Billing

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

@Suite
struct BillTests {
    let free = Plan(try! PlanCatalog.builtIn("free"), renewsOn: nil)
    let paid = Plan(try! PlanCatalog.builtIn("workers-paid"), renewsOn: nil)
    /// A third of October gone (the 11th at 08:00 UTC is 10⅓ of 31 days).
    let now = Date.utc("2026-10-11T08:00:00")

    @Test func `should cost nothing this month on the Free plan`() {
        let bill = Bill(plan: free, monthToDate: ["d1.rowsRead": Quantity(40e9, .rows)], kept: [:], invoices: [], at: now)
        #expect(bill.estimate == Money(0, "USD"))
        #expect(bill.forecast == Money(0, "USD"))
    }

    @Test func `should quote Workers Paid at its subscription when this month's pace stays inside it`() {
        let bill = Bill(plan: free, monthToDate: ["d1.rowsRead": Quantity(1.6e6 * 10, .rows)], kept: [:], invoices: [], at: now)
        #expect(bill.quote(on: paid) == Money(5, "USD"))
    }

    @Test func `should forecast the month from its pace, not from what has been used so far`() {
        // 10B rows read in the first third of the month: on pace for 30B, 5B past the 25B included.
        let bill = Bill(plan: paid, monthToDate: ["d1.rowsRead": Quantity(10e9 * (10 + 1.0 / 3) / 31 * 3, .rows)],
                        kept: [:], invoices: [], at: now)
        #expect(bill.estimate == Money(5, "USD"))
        #expect(abs(NSDecimalNumber(decimal: bill.forecast.amount).doubleValue - 10) < 0.001)
    }

    @Test func `should bill Workers AI day by day, and forecast by stretching the overage, not the total`() {
        let days: [LimitID: [Date: Quantity]] = ["ai.neurons": [.utc("2026-10-01T00:00:00"): Quantity(25_000, .neurons),
                                                               .utc("2026-10-02T00:00:00"): Quantity(5_000, .neurons)]]
        let bill = Bill(plan: paid, monthToDate: ["ai.neurons": Quantity(30_000, .neurons)], kept: [:], invoices: [], daily: days, at: now)

        #expect(bill.estimate == Money(Decimal(string: "5.165")!, "USD"))
        // $0.165 so far, a third of the month gone: on pace for $0.495.
        #expect(abs(NSDecimalNumber(decimal: bill.forecast.amount).doubleValue - 5.495) < 0.001)
    }

    @Test func `should never say Workers Paid stopped Workers AI on a busy day, since it charges instead`() {
        let days: [LimitID: [Date: Quantity]] = ["ai.neurons": [.utc("2026-10-01T00:00:00"): Quantity(25_000, .neurons)]]

        let onPaid = Bill(plan: paid, monthToDate: ["ai.neurons": Quantity(25_000, .neurons)], kept: [:], invoices: [], daily: days, at: now)
        let onFree = Bill(plan: free, monthToDate: ["ai.neurons": Quantity(25_000, .neurons)], kept: [:], invoices: [], daily: days, at: now)

        #expect(onPaid.verdict == .enough)
        #expect(onFree.verdict == .stopped(days: [.utc("2026-10-01T00:00:00")], limits: ["ai.neurons"]))
    }

    @Test func `should not stretch storage by the month's pace, since it is kept, not used up`() {
        let bill = Bill(plan: paid, monthToDate: [:], kept: ["d1.storage": Quantity(6e9, .bytes)], invoices: [], at: now)
        #expect(bill.forecast == Money(Decimal(string: "5.75")!, "USD"))
    }

    @Test func `should show Cloudflare's invoice instead of the estimate once it is issued for the month`() {
        let invoice = Invoice(id: "in_1", amount: Money(Decimal(string: "5.12")!, "USD"), at: .utc("2026-10-02T00:00:00"), status: "paid")
        let bill = Bill(plan: paid, monthToDate: [:], kept: [:], invoices: [invoice], at: now)
        #expect(bill.issued == invoice)
    }

    @Test func `should start the month on the renewal day for a paid plan`() {
        let renewing = Plan(try! PlanCatalog.builtIn("workers-paid"), renewsOn: .utc("2026-11-03T00:00:00"))
        let bill = Bill(plan: renewing, monthToDate: [:], kept: [:], invoices: [], at: now)
        #expect(bill.period.start == .utc("2026-10-03T00:00:00"))
    }
}

@Suite
struct StoppedDaysTests {
    let free = Plan(try! PlanCatalog.builtIn("free"), renewsOn: nil)
    let paid = Plan(try! PlanCatalog.builtIn("workers-paid"), renewsOn: nil)
    let now = Date.utc("2026-10-09T14:20:00")

    func rowsRead(_ days: [(String, Double)]) -> [LimitID: [Date: Quantity]] {
        ["d1.rowsRead": Dictionary(uniqueKeysWithValues: days.map { (Date.utc("\($0.0)T00:00:00"), Quantity($0.1, .rows)) })]
    }

    @Test func `should say Free is enough when no day reached a daily allowance`() {
        let bill = Bill(plan: free, monthToDate: [:], kept: [:], invoices: [], daily: rowsRead([("2026-10-07", 3.75e6)]), at: now)
        #expect(bill.verdict == .enough)
    }

    @Test func `should count the days Free stopped D1 reads`() {
        let bill = Bill(plan: free, monthToDate: [:], kept: [:], invoices: [],
                        daily: rowsRead([("2026-10-06", 2e6), ("2026-10-07", 5e6), ("2026-10-08", 5.2e6)]), at: now)

        #expect(bill.verdict == .stopped(days: [Date.utc("2026-10-07T00:00:00"), Date.utc("2026-10-08T00:00:00")], limits: ["d1.rowsRead"]))
    }

    @Test func `should name each daily limit's busiest day of the month`() {
        let bill = Bill(plan: free, monthToDate: [:], kept: [:], invoices: [],
                        daily: rowsRead([("2026-10-06", 2e6), ("2026-10-07", 3.75e6)]), at: now)

        let days = bill.days(on: free)["d1.rowsRead"]
        #expect(days?.busiest == DayUse(day: .utc("2026-10-07T00:00:00"), used: Quantity(3.75e6, .rows)))
        #expect(days?.allowance == Quantity(5e6, .rows))
        #expect(days?.stopped == [])
    }

    @Test func `should say on which days Free would have stopped an account that is on Workers Paid`() {
        let bill = Bill(plan: paid, monthToDate: [:], kept: [:], invoices: [], daily: rowsRead([("2026-10-07", 6e6)]), at: now)

        #expect(bill.verdict == .enough)
        #expect(bill.days(on: free)["d1.rowsRead"]?.stopped == [Date.utc("2026-10-07T00:00:00")])
        #expect(bill.days(on: paid).isEmpty)
    }

    @Test func `should show each priced limit's line on another plan at this month's pace`() {
        let october11 = Date.utc("2026-10-11T08:00:00")
        let bill = Bill(plan: free, monthToDate: ["d1.rowsRead": Quantity(10e9 * (10 + 1.0 / 3) / 31 * 3, .rows)],
                        kept: [:], invoices: [], at: october11)

        let line = bill.lines(on: paid).first { $0.limit == "d1.rowsRead" }
        #expect(abs((line?.used.value ?? 0) - 30e9) < 1)
        #expect(line?.included == Quantity(25e9, .rows))
    }
}
