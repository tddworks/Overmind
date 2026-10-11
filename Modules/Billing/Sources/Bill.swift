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
    /// Each limit's use per UTC day of the month.
    let daily: [LimitID: [Date: Quantity]]
    /// From the month so far to the whole month: a daily limit's overage is stretched by it (law 24).
    let stretch: Double

    /// `monthToDate` is what was used up this billing month; `kept` is what is stored, which a
    /// pace doesn't stretch.
    public init(plan: Plan, monthToDate: [LimitID: Quantity], kept: [LimitID: Quantity], invoices: [Invoice],
                daily: [LimitID: [Date: Quantity]] = [:], at now: Date) {
        self.daily = daily
        self.plan = plan
        let period = Period.month(containing: now, renewsOn: plan.renewsOn)
        self.period = period
        let elapsed = max(period.elapsedFraction(at: now), 1.0 / 31)
        projected = monthToDate.mapValues { Quantity($0.value / elapsed, $0.unit) }.merging(kept) { $1 }
        stretch = 1 / elapsed
        estimate = plan.cost(of: monthToDate.merging(kept) { $1 }, days: daily)
        forecast = plan.cost(of: projected, days: daily, stretch: stretch)
        self.invoices = invoices.sorted { $0.at > $1.at }
        issued = invoices.first { period.contains($0.at) }
    }

    /// The same month's pace, priced by another plan: *On Workers Paid $5.00* (law 14).
    public func quote(on other: Plan) -> Money {
        other.cost(of: projected, days: daily, stretch: stretch)
    }

    /// Where a plan's price for this month's pace comes from, one line per limit (law 20).
    public func lines(on other: Plan) -> [CostLine] {
        other.lines(of: projected, days: daily, stretch: stretch)
    }

    /// For each limit `plan` allows per day: the allowance, the month's busiest day, and the days
    /// its use reached the allowance, when that plan would have stopped it (law 19).
    public func days(on plan: Plan) -> [LimitID: LimitDays] {
        var result: [LimitID: LimitDays] = [:]
        for (limit, days) in daily {
            guard case .perDay(let allowance)? = plan.allowance(for: limit) else { continue }
            let busiest = days.max { $0.value.value < $1.value.value }.map { DayUse(day: $0.key, used: $0.value) }
            let stopped = plan.stops(at: limit) ? days.filter { $0.value.value >= allowance.value }.keys.sorted() : []
            result[limit] = LimitDays(allowance: allowance, busiest: busiest, stopped: stopped)
        }
        return result
    }

    /// *Free is enough* or *Free stopped you on 2 days*, on the account's own plan.
    public var verdict: Verdict {
        let days = self.days(on: plan).filter { !$0.value.stopped.isEmpty }
        guard !days.isEmpty else { return .enough }
        return .stopped(days: Array(Set(days.values.flatMap(\.stopped))).sorted(), limits: days.keys.sorted { $0.rawValue < $1.rawValue })
    }

    /// How much of the billing month has gone by: the bar under the total.
    public func elapsed(at now: Date) -> Double { period.elapsedFraction(at: now) }
}

public enum Verdict: Sendable, Equatable {
    /// No day reached a daily allowance this month.
    case enough
    /// The plan stopped these limits on these UTC days.
    case stopped(days: [Date], limits: [LimitID])
}

/// A limit's month against a daily allowance: *5M a day · busiest day 3.75M (Oct 7) · 0 days stopped*.
public struct LimitDays: Sendable, Equatable {
    public let allowance: Quantity
    public let busiest: DayUse?
    public let stopped: [Date]
}

public struct DayUse: Sendable, Equatable {
    public let day: Date
    public let used: Quantity

    public init(day: Date, used: Quantity) {
        self.day = day
        self.used = used
    }
}
