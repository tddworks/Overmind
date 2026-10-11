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

    /// The period a limit's reading covers at `now` (CANONICAL law 5), on the renewal of the
    /// subscription that names it; nil for what never resets and for a limit no plan counts.
    public func period(for limit: LimitID, at now: Date) -> Period? {
        guard let owner = owner(of: limit) else { return nil }
        return owner.definition.allowance(for: limit)?.period(at: now, renewsOn: owner.renewsOn)
    }

    /// One line per priced limit: its use, what the plan includes, and the price of the rest
    /// (law 20). The subscription is not a line; the lines and it add up to `cost(of:)`.
    public func lines(of used: [LimitID: Quantity]) -> [CostLine] {
        used.compactMap { limit, quantity -> CostLine? in
            guard let price = price(for: limit), let allowance = allowance(for: limit) else { return nil }
            return CostLine(limit: limit, used: quantity, included: allowance.amount,
                            cost: price.cost(of: quantity, allowance: allowance.amount))
        }
        .sorted { $0.limit.rawValue < $1.limit.rawValue }
    }

    /// The subscriptions (this plan's and its add-ons'), plus for each limit the price of what
    /// went past its allowance (CANONICAL laws 13–14, 23). `used` is each limit's use over the
    /// billing month.
    public func cost(of used: [LimitID: Quantity]) -> Money {
        let subscriptions = addOns.reduce(definition.subscription) { $0 + $1.definition.subscription }
        return used.reduce(subscriptions) { total, entry in
            guard let price = price(for: entry.key), let allowance = allowance(for: entry.key) else { return total }
            return total + price.cost(of: entry.value, allowance: allowance.amount)
        }
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
