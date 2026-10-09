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
