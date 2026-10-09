import Foundation

/// An amount of money in one currency. Decimal, so a price of $0.001 per million rows adds up
/// without drift.
public struct Money: Sendable, Equatable, Hashable, Codable {
    public let amount: Decimal
    public let currency: String

    public init(_ amount: Decimal, _ currency: String) {
        self.amount = amount
        self.currency = currency
    }

    /// Reads `"0.001 USD"`, the way a plan file writes a price.
    public init(parsing text: String) throws(MeasureError) {
        let parts = text.split(separator: " ").map(String.init)
        guard parts.count == 2, let amount = Decimal(string: parts[0], locale: Locale(identifier: "en_US_POSIX")) else {
            throw .notMoney(text)
        }
        self.init(amount, parts[1])
    }

    public static func zero(_ currency: String) -> Money { Money(0, currency) }

    /// Only amounts in one currency add up; a plan file holds one.
    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "a plan prices in one currency")
        return Money(lhs.amount + rhs.amount, lhs.currency)
    }

    public static func * (lhs: Money, rhs: Double) -> Money {
        Money(lhs.amount * Decimal(rhs), lhs.currency)
    }
}
