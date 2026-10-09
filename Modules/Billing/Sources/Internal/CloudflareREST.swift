import Foundation
import Measures

/// The `BillingAPI` port over `https://api.cloudflare.com/client/v4`. Only GETs. Never logs the
/// token or an answer.
struct CloudflareREST: BillingAPI {
    let bearer: @Sendable () async throws -> String
    var base = URL(string: "https://api.cloudflare.com/client/v4/")!
    var session: URLSession = .shared

    func accounts() async throws -> [AccountSummary] {
        try Self.accounts(from: await get("accounts?per_page=50"))
    }

    func subscriptions(account: String) async throws -> [Subscription] {
        try Self.subscriptions(from: await get("accounts/\(account)/subscriptions"))
    }

    func invoices(account: String) async throws -> [Invoice] {
        try Self.invoices(from: await get("accounts/\(account)/billing/history?per_page=12"))
    }

    func scripts(account: String) async throws -> [String] {
        try Self.scripts(from: await get("accounts/\(account)/workers/scripts"))
    }

    func deployments(account: String, script: String) async throws -> [Deployment] {
        let name = script.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? script
        return try Self.deployments(from: await get("accounts/\(account)/workers/scripts/\(name)/deployments"))
    }

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: URL(string: path, relativeTo: base)!)
        request.setValue("Bearer \(try await bearer())", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BillingError.unreachable(error.localizedDescription)
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: return data
        case 401: throw BillingError.refused
        case 403: throw BillingError.forbidden
        case let status: throw BillingError.unreachable("HTTP \(status)")
        }
    }

    // MARK: Reading Cloudflare's envelope `{ success, errors, result }`

    private struct Envelope<Result: Decodable>: Decodable { let result: Result }

    private static func result<Result: Decodable>(_ type: Result.Type, from data: Data) throws -> Result {
        do {
            return try JSONDecoder().decode(Envelope<Result>.self, from: data).result
        } catch {
            throw BillingError.unreadable("\(error)")
        }
    }

    static func accounts(from data: Data) throws -> [AccountSummary] {
        struct Account: Decodable { let id: String; let name: String }
        return try result([Account].self, from: data).map { AccountSummary(id: $0.id, name: $0.name) }
    }

    static func subscriptions(from data: Data) throws -> [Subscription] {
        struct RatePlan: Decodable { let id: String }
        struct Entry: Decodable {
            let rate_plan: RatePlan?
            let current_period_end: String?
        }
        return try result([Entry].self, from: data).compactMap { entry in
            entry.rate_plan.map { Subscription(ratePlan: $0.id, renewsOn: entry.current_period_end.flatMap(date)) }
        }
    }

    static func invoices(from data: Data) throws -> [Invoice] {
        struct Entry: Decodable {
            let id: String
            let amount: Decimal
            let currency: String?
            let occurred_at: String
            let status: String?
        }
        return try result([Entry].self, from: data).compactMap { entry in
            date(entry.occurred_at).map {
                Invoice(id: entry.id, amount: Money(entry.amount, entry.currency ?? "USD"), at: $0, status: entry.status ?? "")
            }
        }
    }

    static func scripts(from data: Data) throws -> [String] {
        struct Script: Decodable { let id: String }
        return try result([Script].self, from: data).map(\.id).sorted()
    }

    static func deployments(from data: Data) throws -> [Deployment] {
        struct Entry: Decodable { let id: String; let created_on: String }
        struct List: Decodable { let deployments: [Entry] }
        return try result(List.self, from: data).deployments
            .compactMap { entry in date(entry.created_on).map { Deployment(id: entry.id, at: $0) } }
            .sorted { $0.at > $1.at }
    }

    /// Cloudflare writes times with and without fractions of a second.
    static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
}
