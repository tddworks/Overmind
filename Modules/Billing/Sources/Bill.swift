import Foundation
import Measures
import Plans

/// *This month · est.* · *Forecast* · *Invoices* (CANONICAL laws 13–14).
public struct Bill: Sendable, Equatable {
    public let plan: Plan
    /// The billing month: the renewal day's month on a paid plan, the calendar month on Free.
    public let period: Period
    /// What the month has cost so far, by the plan's prices.
    public let estimate: Money
    /// What the month will cost at its pace.
    public let forecast: Money
    public let invoices: [Invoice]
    /// Cloudflare's invoice for this month, once issued; shown instead of the estimate.
    public let issued: Invoice?
    let projected: [LimitID: Quantity]

    /// `monthToDate` is what was used up this billing month; `kept` is what is stored, which a
    /// pace doesn't stretch.
    public init(plan: Plan, monthToDate: [LimitID: Quantity], kept: [LimitID: Quantity], invoices: [Invoice], at now: Date) {
        self.plan = plan
        let period = Period.month(containing: now, renewsOn: plan.renewsOn)
        self.period = period
        let elapsed = max(period.elapsedFraction(at: now), 1.0 / 31)
        projected = monthToDate.mapValues { Quantity($0.value / elapsed, $0.unit) }.merging(kept) { $1 }
        estimate = plan.cost(of: monthToDate.merging(kept) { $1 })
        forecast = plan.cost(of: projected)
        self.invoices = invoices.sorted { $0.at > $1.at }
        issued = invoices.first { period.contains($0.at) }
    }

    /// The same month's pace, priced by another plan: *On Workers Paid $5.00* (law 14).
    public func quote(on other: Plan) -> Money {
        other.cost(of: projected)
    }

    /// How much of the billing month has gone by: the bar under the total.
    public func elapsed(at now: Date) -> Double { period.elapsedFraction(at: now) }
}
