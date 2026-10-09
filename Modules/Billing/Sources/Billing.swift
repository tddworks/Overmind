import Foundation
import Mockable
import Measures

/// Billing — the account's plan, invoices, deployments and Workers over Cloudflare's REST API,
/// and the `Bill` (TARGET_ARCHITECTURE §3.1, §3.4). Every call is a GET (law 16).
public enum Billing {
    public static func make(bearer: @escaping @Sendable () async throws -> String) -> any BillingAPI {
        CloudflareREST(bearer: bearer)
    }
}

@Mockable
public protocol BillingAPI: Sendable {
    /// The accounts the token can read; also how a token is checked (`/user/tokens/verify`
    /// refuses some kinds of token).
    func accounts() async throws -> [AccountSummary]
    func subscriptions(account: String) async throws -> [Subscription]
    func invoices(account: String) async throws -> [Invoice]
    func scripts(account: String) async throws -> [String]
    func deployments(account: String, script: String) async throws -> [Deployment]
}

public struct AccountSummary: Sendable, Equatable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Subscription: Sendable, Equatable {
    public let ratePlan: String
    public let renewsOn: Date?

    public init(ratePlan: String, renewsOn: Date?) {
        self.ratePlan = ratePlan
        self.renewsOn = renewsOn
    }
}

public struct Invoice: Sendable, Equatable, Identifiable {
    public let id: String
    public let amount: Money
    public let at: Date
    public let status: String

    public init(id: String, amount: Money, at: Date, status: String) {
        self.id = id
        self.amount = amount
        self.at = at
        self.status = status
    }
}

/// A Worker version going live: a pin on the charts.
public struct Deployment: Sendable, Equatable, Identifiable {
    public let id: String
    public let at: Date

    public init(id: String, at: Date) {
        self.id = id
        self.at = at
    }

    /// The first eight characters, as the dashboard prints it: *d605dc93*.
    public var short: String { String(id.prefix(8)) }
}

public enum BillingError: Error, Equatable, Sendable {
    /// Cloudflare refused the token itself (401).
    case refused
    /// The token can't read this (403): a reason on the part that needs it (law 12).
    case forbidden
    case unreachable(String)
    case unreadable(String)
}
