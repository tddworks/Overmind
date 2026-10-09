import Foundation
import Measures

/// A Cloudflare plan, as data: *Free*, *Workers Paid*.
public struct PlanDefinition: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let subscription: Money
    /// The `rate_plan` ids in the account's subscriptions that mean this plan.
    public let matches: [String]
    let allowances: [LimitID: Allowance]
    let prices: [LimitID: Price]
    /// Its page on Cloudflare's dashboard, `{account}` for the account ID. Edge Meter only
    /// links to it; plans change on Cloudflare.
    let upgradeTemplate: String?

    public init(json: Data) throws(PlanError) {
        do {
            let file = try JSONDecoder().decode(File.self, from: json)
            id = file.id
            name = file.name
            subscription = try Money(parsing: file.subscription)
            matches = file.matches
            allowances = Dictionary(uniqueKeysWithValues: file.allowances.map { (LimitID($0.key), $0.value) })
            prices = Dictionary(uniqueKeysWithValues: (file.prices ?? [:]).map { (LimitID($0.key), $0.value) })
            upgradeTemplate = file.upgradeURL
        } catch let error as PlanError {
            throw error
        } catch {
            throw .unreadable("\(error)")
        }
        for limit in prices.keys where allowances[limit] == nil { throw .priceWithoutAllowance(limit) }
    }

    /// What the plan includes of a limit; nil when the plan doesn't count it, and then the
    /// limit isn't shown.
    public func allowance(for limit: LimitID) -> Allowance? { allowances[limit] }

    /// What the use past the allowance costs; nil when the plan stops at the limit.
    public func price(for limit: LimitID) -> Price? { prices[limit] }

    /// Free stops at its limits; a plan with prices charges for the rest instead.
    public var stopsAtLimits: Bool { prices.isEmpty }

    /// *Upgrade on Cloudflare ↗* for `account`; nil when the plan has no page to send you to.
    public func upgradeURL(account: String) -> URL? {
        upgradeTemplate.flatMap { URL(string: $0.replacingOccurrences(of: "{account}", with: account)) }
    }

    private struct File: Decodable {
        let id, name, subscription: String
        let matches: [String]
        let allowances: [String: Allowance]
        let prices: [String: Price]?
        let upgradeURL: String?
    }
}

public enum PlanError: Error, Equatable, Sendable {
    case notFound(String)
    case unreadable(String)
    case unknownCase(String)
    case priceWithoutAllowance(LimitID)
}
