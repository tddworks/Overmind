import Foundation
import Measures
import Analytics
import Billing
import Alerts
@testable import Monitor

extension Date {
    static func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: text)!
    }
}

/// Cloudflare in memory: answers any query `ReadPlan` writes with the numbers set here, by the
/// field's last name (`rowsRead`, `cpuTimeP99`), and counts reads.
final class FakeCloudflare: AnalyticsAPI, BillingAPI, @unchecked Sendable {
    var numbers: [String: Double] = [:]
    var unreachable = false
    var refuses = false
    var forbidsAnalytics = false
    var forbidsAccounts = false
    /// The Keychain wouldn't give the token back to the adapters.
    var tokenUnavailable = false
    var accountList = [AccountSummary(id: "acc1", name: "Acme")]
    var ratePlans: [String]? = ["r2_paid"]
    var invoiceList: [Invoice]? = []
    var scriptList = ["api", "leaderboard"]
    var deploymentList = [Deployment(id: "d605dc93-1111", at: .utc("2026-10-08T09:30:00"))]
    private(set) var queries: [String] = []

    func read(_ query: AnalyticsQuery) async throws -> AnalyticsAnswer {
        if tokenUnavailable { throw TokenUnavailable() }
        if refuses { throw AnalyticsError.refused }
        if forbidsAnalytics { throw AnalyticsError.forbidden }
        if unreachable { throw AnalyticsError.unreachable("offline") }
        queries.append(query.text)
        var account: [String: Any] = [:]
        for line in query.text.split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":"), line.hasPrefix("l") || line.hasPrefix("b"),
                  let open = line.lastIndex(of: "{") else { continue }
            let alias = String(line[..<colon])
            // `) { sum { rowsRead } }` → ["sum", "rowsRead"]
            let selection = line[line.range(of: ") {")!.upperBound...].split(whereSeparator: { " {}".contains($0) }).map(String.init)
            _ = open
            guard let field = selection.last else { continue }
            // A failures alias is filtered to the stopped invocations: `numbers["stopped"]`.
            var node: Any = (alias.hasSuffix("_failures") ? numbers["stopped"] : numbers[field]) ?? 0
            for key in selection.reversed() where key != "dimensions" { node = [key: node] }
            account[alias] = [node]
        }
        let json: [String: Any] = ["data": ["viewer": ["accounts": [account]]]]
        return AnalyticsAnswer(try JSONSerialization.data(withJSONObject: json))
    }

    func accounts() async throws -> [AccountSummary] {
        if tokenUnavailable { throw TokenUnavailable() }
        if refuses { throw BillingError.refused }
        if forbidsAccounts { throw BillingError.forbidden }
        return accountList
    }

    func subscriptions(account: String) async throws -> [Subscription] {
        guard let ratePlans else { throw BillingError.forbidden }
        return ratePlans.map { Subscription(ratePlan: $0, renewsOn: nil) }
    }

    func invoices(account: String) async throws -> [Invoice] {
        guard let invoiceList else { throw BillingError.forbidden }
        return invoiceList
    }

    func scripts(account: String) async throws -> [String] { scriptList }
    func deployments(account: String, script: String) async throws -> [Deployment] { deploymentList }
}

final class FakeVault: TokenVault, @unchecked Sendable {
    var token: String?
    func save(_ token: String) throws { self.token = token }
    func load() -> String? { token }
    func delete() { token = nil }
}

final class FakeSettings: SettingsStore, @unchecked Sendable {
    var settings = Settings()
    func load() -> Settings { settings }
    func save(_ settings: Settings) { self.settings = settings }
}

final class FakeNotifier: Notifier, @unchecked Sendable {
    private(set) var posted: [Warning] = []
    func post(_ warning: Warning) async { posted.append(warning) }
}

@MainActor
struct World {
    let cloudflare = FakeCloudflare()
    let vault = FakeVault()
    let settings = FakeSettings()
    let notifier = FakeNotifier()

    func account() throws -> Account {
        try Account(services: .builtIns(), plans: .builtIns(), analytics: cloudflare, billing: cloudflare,
                    vault: vault, settings: settings, notifier: notifier)
    }
}
