import Foundation
import Measures

/// The plan an account is on: a definition, the day its billing month renews, and the add-ons
/// beside it (*R2*, CANONICAL law 23).
public struct Plan: Sendable, Equatable {
    public let definition: PlanDefinition
    /// From the subscription's `current_period_end`; nil on Free.
    public let renewsOn: Date?
    public let addOns: [Plan]

    public init(_ definition: PlanDefinition, renewsOn: Date?, addOns: [Plan] = []) {
        self.definition = definition
        self.renewsOn = renewsOn
        self.addOns = addOns
    }

    /// Whichever of this plan and its add-ons names the limit (law 23).
    func owner(of limit: LimitID) -> Plan? {
        definition.allowance(for: limit) != nil ? self : addOns.first { $0.definition.allowance(for: limit) != nil }
    }

    public func allowance(for limit: LimitID) -> Allowance? { owner(of: limit)?.definition.allowance(for: limit) }

    func price(for limit: LimitID) -> Price? { owner(of: limit)?.definition.price(for: limit) }

    /// Whether use past the allowance fails instead of being charged: Free stops, Workers Paid
    /// charges, even for a daily allowance like Workers AI's (laws 19, 24).
    public func stops(at limit: LimitID) -> Bool { price(for: limit) == nil }

    /// The period a limit's reading covers at `now` (CANONICAL law 5), on the renewal of the
    /// subscription that names it; nil for what never resets and for a limit no plan counts.
    public func period(for limit: LimitID, at now: Date) -> Period? {
        guard let owner = owner(of: limit) else { return nil }
        return owner.definition.allowance(for: limit)?.period(at: now, renewsOn: owner.renewsOn)
    }

    /// One line per priced limit: its use, what the plan includes, and the price of the rest
    /// (law 20). The subscription is not a line; the lines and it add up to `cost(of:)`.
    /// `days` is each daily limit's use per UTC day this month; `stretch` scales a daily limit's
    /// overage to the month's end for a forecast or a quote (law 24).
    public func lines(of used: [LimitID: Quantity], days: [LimitID: [Date: Quantity]] = [:], stretch: Double = 1) -> [CostLine] {
        used.compactMap { limit, quantity -> CostLine? in
            guard let cost = cost(of: limit, used: quantity, days: days[limit], stretch: stretch),
                  let allowance = allowance(for: limit) else { return nil }
            return CostLine(limit: limit, used: quantity, included: allowance.amount, cost: cost)
        }
        .sorted { $0.limit.rawValue < $1.limit.rawValue }
    }

    /// The subscriptions (this plan's and its add-ons'), plus for each limit the price of what
    /// went past its allowance (CANONICAL laws 13–14, 23). `used` is each limit's use over the
    /// billing month.
    public func cost(of used: [LimitID: Quantity], days: [LimitID: [Date: Quantity]] = [:], stretch: Double = 1) -> Money {
        let subscriptions = addOns.reduce(definition.subscription) { $0 + $1.definition.subscription }
        return used.reduce(subscriptions) { total, entry in
            guard let cost = cost(of: entry.key, used: entry.value, days: days[entry.key], stretch: stretch) else { return total }
            return total + cost
        }
    }

    /// One limit's price past its allowance; nil when no plan prices it. A daily allowance with
    /// a price is billed day by day: each UTC day's use past it, added up (law 24).
    func cost(of limit: LimitID, used: Quantity, days: [Date: Quantity]?, stretch: Double) -> Money? {
        guard let price = price(for: limit), let allowance = allowance(for: limit) else { return nil }
        guard case .perDay(let daily) = allowance, let days, !days.isEmpty else {
            return price.cost(of: used, allowance: allowance.amount)
        }
        let over = days.values.reduce(0) { $0 + max($1.value - daily.value, 0) } * stretch
        return price.cost(of: Quantity(over, daily.unit), allowance: Quantity(0, daily.unit))
    }
}

/// *D1 rows read · ~26.2B of 25B included · $1.20*.
public struct CostLine: Sendable, Equatable {
    public let limit: LimitID
    public let used: Quantity
    public let included: Quantity
    public let cost: Money

    public init(limit: LimitID, used: Quantity, included: Quantity, cost: Money) {
        self.limit = limit
        self.used = used
        self.included = included
        self.cost = cost
    }
}
