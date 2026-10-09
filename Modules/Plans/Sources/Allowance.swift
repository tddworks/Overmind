import Foundation
import Measures

/// How much of a limit a plan includes (ENGINE_DESIGN §3). A closed sum.
public enum Allowance: Sendable, Equatable {
    /// Resets at 00:00 UTC: *5M rows a day*.
    case perDay(Quantity)
    /// Resets on the renewal day: *25B rows a month*.
    case perMonth(Quantity)
    /// Each invocation may use this much, judged over the UTC day: *10 ms CPU*.
    case perInvocation(Quantity)
    /// What is kept, never reset: *5 GB storage*.
    case total(Quantity)

    public var amount: Quantity {
        switch self {
        case .perDay(let amount), .perMonth(let amount), .perInvocation(let amount), .total(let amount): amount
        }
    }

    /// The period a reading of this allowance covers; nil for what never resets.
    public func period(at now: Date, renewsOn renewal: Date?) -> Period? {
        switch self {
        case .perDay, .perInvocation: .day(containing: now)
        case .perMonth: .month(containing: now, renewsOn: renewal)
        case .total: nil
        }
    }

    /// Whether today's rate can be projected to the period's end (CANONICAL law 6).
    public var hasPace: Bool {
        switch self {
        case .perDay, .perMonth: true
        case .perInvocation, .total: false
        }
    }
}

extension Allowance: Decodable {
    private enum Keys: String, CodingKey, CaseIterable { case perDay, perMonth, perInvocation, total }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw PlanError.unknownCase("an allowance must be one of \(Keys.allCases.map(\.rawValue))")
        }
        let amount = try Quantity(parsing: container.decode(String.self, forKey: key))
        switch key {
        case .perDay: self = .perDay(amount)
        case .perMonth: self = .perMonth(amount)
        case .perInvocation: self = .perInvocation(amount)
        case .total: self = .total(amount)
        }
    }
}

/// What the use past an allowance costs. A plan with no price for a limit stops at it instead.
public enum Price: Sendable, Equatable {
    /// Each `per` past the allowance costs `price`: *$0.001 per 1M rows*.
    case beyond(price: Money, per: Quantity)
    /// What is kept past the allowance, by the month: *$0.75 per GB-month*.
    case perMonthOver(price: Money, per: Quantity)

    /// The cost of `used` against `allowance`; zero inside it.
    func cost(of used: Quantity, allowance: Quantity) -> Money {
        switch self {
        case .beyond(let price, let per), .perMonthOver(let price, let per):
            guard let over = Quantity(max(used.value - allowance.value, 0), used.unit).fraction(of: per) else {
                return .zero(price.currency)
            }
            return price * over
        }
    }
}

extension Price: Decodable {
    private enum Keys: String, CodingKey { case beyond, perMonthOver }
    private struct Rate: Decodable { let price: String; let per: String }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        if let rate = try container.decodeIfPresent(Rate.self, forKey: .beyond) {
            self = .beyond(price: try Money(parsing: rate.price), per: try Quantity(parsing: rate.per))
        } else if let rate = try container.decodeIfPresent(Rate.self, forKey: .perMonthOver) {
            self = .perMonthOver(price: try Money(parsing: rate.price), per: try Quantity(parsing: rate.per))
        } else {
            throw PlanError.unknownCase("a price must be beyond or perMonthOver")
        }
    }
}
