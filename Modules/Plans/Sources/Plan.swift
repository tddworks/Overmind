import Foundation
import Measures

/// The plan an account is on: a definition, and the day its billing month renews.
public struct Plan: Sendable, Equatable {
    public let definition: PlanDefinition
    /// From the subscription's `current_period_end`; nil on Free.
    public let renewsOn: Date?

    public init(_ definition: PlanDefinition, renewsOn: Date?) {
        self.definition = definition
        self.renewsOn = renewsOn
    }

    public func allowance(for limit: LimitID) -> Allowance? { definition.allowance(for: limit) }

    /// The period a limit's reading covers at `now` (CANONICAL law 5); nil for what never resets
    /// and for a limit the plan doesn't count.
    public func period(for limit: LimitID, at now: Date) -> Period? {
        allowance(for: limit)?.period(at: now, renewsOn: renewsOn)
    }

    /// The subscription, plus for each limit the price of what went past its allowance
    /// (CANONICAL laws 13–14). `used` is each limit's use over the billing month.
    public func cost(of used: [LimitID: Quantity]) -> Money {
        used.reduce(definition.subscription) { total, entry in
            guard let price = definition.price(for: entry.key), let allowance = allowance(for: entry.key) else { return total }
            return total + price.cost(of: entry.value, allowance: allowance.amount)
        }
    }
}
